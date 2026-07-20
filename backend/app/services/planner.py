import json
import logging
import os
from datetime import datetime
from sqlalchemy.orm import Session
from app.database import ActivityLog, ConfirmationGate, Email, CalendarEvent, ECommerceOrder

logger = logging.getLogger(__name__)

# Try to import Google API components
try:
    from googleapiclient.discovery import build
    from google.oauth2.credentials import Credentials
    from google.auth.transport.requests import Request
    from google_auth_oauthlib.flow import InstalledAppFlow
    GOOGLE_APIS_SUPPORTED = True
except ImportError:
    GOOGLE_APIS_SUPPORTED = False

class TaskChainingPlanner:
    def can_handle(self, message: str) -> bool:
        """Determines if a query requires multi-step planning or external tool APIs."""
        msg = message.lower()
        trigger_words = ["order", "flipkart", "amazon", "meeting", "calendar", "schedule", "email", "gmail", "inbox", "mail", "draft", "complaint"]
        return any(word in msg for word in trigger_words)

    def _get_google_credentials(self, user_id: int, db: Session):
        """Helper to load Google OAuth credentials from database for a user."""
        if not GOOGLE_APIS_SUPPORTED:
            return None
            
        from google.oauth2.credentials import Credentials
        from google.auth.transport.requests import Request
        from app.database import GoogleCredential
        
        db_cred = db.query(GoogleCredential).filter(GoogleCredential.user_id == user_id).first()
        if not db_cred:
            # Fallback to local token.json if exists for developer ease
            token_path = "token.json"
            if os.path.exists(token_path):
                try:
                    return Credentials.from_authorized_user_file(token_path)
                except Exception as e:
                    logger.warning(f"Failed to load fallback google token.json: {e}")
            return None
            
        try:
            creds = Credentials(
                token=db_cred.access_token,
                refresh_token=db_cred.refresh_token,
                token_uri=db_cred.token_uri,
                client_id=db_cred.client_id,
                client_secret=db_cred.client_secret,
                scopes=json.loads(db_cred.scopes)
            )
            
            # Auto refresh if expired
            if creds.expired and creds.refresh_token:
                creds.refresh(Request())
                db_cred.access_token = creds.token
                db_cred.expiry = creds.expiry
                db.commit()
                logger.info(f"Google credentials auto-refreshed and saved for user ID: {user_id}")
            return creds
        except Exception as e:
            logger.warning(f"Failed to build Google credentials for user ID {user_id}: {e}")
            return None

    async def execute_plan(self, user_id: int, message: str, db: Session) -> str:
        """
        Executes a multi-step task plan based on the query.
        Logs read operations directly, and pushes write operations to the Confirmation Gate.
        """
        msg = message.lower()
        creds = self._get_google_credentials(user_id, db)

        # ---------------- CASE 1: FLIPKART/AMAZON ORDER STATUS + COMPLAINT DRAFT ----------------
        if "order" in msg or "flipkart" in msg or "amazon" in msg:
            # Query order list from stateful SQLite
            orders = db.query(ECommerceOrder).filter(ECommerceOrder.user_id == user_id).all()
            
            orders_found = []
            delayed_order = None
            
            # Check Flipkart
            if "flipkart" in msg or "order" in msg:
                fk_orders = [o for o in orders if o.vendor.lower() == "flipkart"]
                orders_found.extend(fk_orders)
                for o in fk_orders:
                    if "delay" in o.status.lower():
                        delayed_order = o

            # Check Amazon
            if "amazon" in msg or "order" in msg:
                am_orders = [o for o in orders if o.vendor.lower() == "amazon"]
                orders_found.extend(am_orders)
                for o in am_orders:
                    if "delay" in o.status.lower() and not delayed_order:
                        delayed_order = o

            # If no orders in DB, return warning
            if not orders_found:
                orders_found = orders

            # Log read activity
            read_log = ActivityLog(
                user_id=user_id,
                action_type="order_lookup",
                description="Queried e-commerce order tracking statuses.",
                status="completed",
                explanation="Checked stateful SQLite database (Amazon and Flipkart simulation tables) for order details."
            )
            db.add(read_log)
            db.commit()

            # If user wanted to check and draft complaint on delay
            if delayed_order and ("draft" in msg or "complaint" in msg or "email" in msg or "delayed" in msg):
                # Queue a draft email task in confirmation gate
                payload = {
                    "to": f"support@{delayed_order.vendor.lower()}.com",
                    "subject": f"Complaint: Delayed Order {delayed_order.order_id}",
                    "body": f"Dear Support Team,\n\nMy order {delayed_order.order_id} for '{delayed_order.item}' is currently marked as '{delayed_order.status}'. It was scheduled to be delivered on {delayed_order.delivery_date}.\n\nPlease expedite this and update me on the new delivery time.\n\nRegards,\nAditya Kumar"
                }
                
                explanation = f"Drafted complaint email because {delayed_order.vendor} order #{delayed_order.order_id} was found delayed."
                
                gate_item = ConfirmationGate(
                    user_id=user_id,
                    action_type="send_email",
                    payload=json.dumps(payload),
                    explanation=explanation,
                    status="pending"
                )
                db.add(gate_item)
                
                write_log = ActivityLog(
                    user_id=user_id,
                    action_type="email_draft",
                    description=f"Drafted complaint email for delayed order #{delayed_order.order_id}.",
                    status="pending_confirmation",
                    explanation=explanation
                )
                db.add(write_log)
                db.commit()

                return (
                    f"Main check kar chuka hoon. 🔍\n\n"
                    f"Aapka {delayed_order.vendor} order **#{delayed_order.order_id}** ('{delayed_order.item}') **{delayed_order.status}** chal raha hai (Delivery date: {delayed_order.delivery_date}).\n\n"
                    f"Maine {delayed_order.vendor} Support ke liye ek complaint mail draft kiya hai aur use approval ke liye **Confirmation Gate** me daal diya hai. "
                    f"Aap use activity logs me check karke approve kar sakte hain! 📨"
                )
            
            # Simple order lookup status reply
            orders_status_str = "\n".join([f"- **{o.item}** ({o.order_id}) [{o.vendor}]: {o.status} (Expected: {o.delivery_date})" for o in orders_found])
            return f"Aapke active order details ye hain 📦:\n\n{orders_status_str}"

        # ---------------- CASE 2: CALENDAR SCHEDULING OR LISTING ----------------
        elif "meeting" in msg or "calendar" in msg or "schedule" in msg:
            if "schedule" in msg or "add" in msg or "book" in msg:
                # Parse a meeting title and time from user query
                title = "Project Sync"
                meeting_time = "4:00 PM"
                
                # Check message for explicit titles/times
                if "for" in msg:
                    parts = msg.split("for")
                    title = parts[1].split("at")[0].strip().title()
                if "at" in msg:
                    meeting_time = msg.split("at")[-1].strip().upper()

                payload = {
                    "title": title,
                    "time": meeting_time,
                    "date": "Today"
                }
                
                explanation = f"Queued scheduling of meeting '{title}' at {meeting_time}."
                
                gate_item = ConfirmationGate(
                    user_id=user_id,
                    action_type="add_calendar",
                    payload=json.dumps(payload),
                    explanation=explanation,
                    status="pending"
                )
                db.add(gate_item)
                
                write_log = ActivityLog(
                    user_id=user_id,
                    action_type="calendar_write",
                    description=f"Queued scheduling: '{title}' at {meeting_time}.",
                    status="pending_confirmation",
                    explanation=explanation
                )
                db.add(write_log)
                db.commit()

                return (
                    f"Maine calendar event coordinate kar liya hai. 📅\n\n"
                    f"Meeting **'{title}'** scheduled at **{meeting_time}** ko add karne ke liye Maine confirmation request trigger kar di hai. "
                    f"Please activity log panel me jaakar ise approve karein."
                )
            
            # List meetings from SQLite or Google Calendar
            meetings_list = []
            if creds:
                try:
                    # Load actual Google Calendar events
                    service = build("calendar", "v3", credentials=creds)
                    now_iso = datetime.utcnow().isoformat() + 'Z'
                    events_result = service.events().list(
                        calendarId='primary', timeMin=now_iso,
                        maxResults=5, singleEvents=True,
                        orderBy='startTime'
                    ).execute()
                    events = events_result.get('items', [])
                    for event in events:
                        start = event['start'].get('dateTime', event['start'].get('date'))
                        meetings_list.append({
                            "title": event.get('summary', 'Untitled Meeting'),
                            "time": start,
                            "date": "Google Calendar"
                        })
                except Exception as ex:
                    logger.error(f"Google Calendar read failed, using SQLite: {ex}")
            
            # Fallback/merge with SQLite events
            db_meetings = db.query(CalendarEvent).filter(CalendarEvent.user_id == user_id).all()
            for m in db_meetings:
                meetings_list.append({
                    "title": m.title,
                    "time": m.event_time,
                    "date": m.event_date
                })

            meetings_str = "\n".join([f"- **{m['title']}** at {m['time']} ({m['date']})" for m in meetings_list])
            
            read_log = ActivityLog(
                user_id=user_id,
                action_type="calendar_read",
                description="Viewed calendar scheduled meetings.",
                status="completed",
                explanation="Listed active meetings from Google Calendar / SQLite database."
            )
            db.add(read_log)
            db.commit()

            return f"Aapka aaj aur kal ka calendar schedule 📅:\n\n{meetings_str}"

        # ---------------- CASE 3: GMAIL INBOX READING OR DRAFTING ----------------
        elif "email" in msg or "gmail" in msg or "mail" in msg or "inbox" in msg:
            if "draft" in msg or "send" in msg:
                # Email drafting
                payload = {
                    "to": "boss@halonix.co.in",
                    "subject": "Re: URGENT: Order #F-9821 Delay Update",
                    "body": "Dear Boss,\n\nI have looked into the delayed Flipkart order. It is delayed by 3 days. A complaint email has already been drafted to Flipkart Support to expedite delivery.\n\nBest,\nAditya"
                }
                
                explanation = "Drafted response to Boss explaining order delay status."
                
                gate_item = ConfirmationGate(
                    user_id=user_id,
                    action_type="send_email",
                    payload=json.dumps(payload),
                    explanation=explanation,
                    status="pending"
                )
                db.add(gate_item)
                
                write_log = ActivityLog(
                    user_id=user_id,
                    action_type="email_draft",
                    description="Drafted reply email to Boss regarding order delay.",
                    status="pending_confirmation",
                    explanation=explanation
                )
                db.add(write_log)
                db.commit()

                return (
                    f"Boss ki mail ka reply draft kar liya hai! ✉️\n\n"
                    f"Subject: *{payload['subject']}*\n"
                    f"Send karne se pehle please **Activity Log** me confirmation gate check karein."
                )

            # List Emails from Gmail or SQLite
            emails_list = []
            if creds:
                try:
                    # Query Google Gmail API
                    service = build("gmail", "v1", credentials=creds)
                    results = service.users().messages().list(userId='me', maxResults=3).execute()
                    messages_res = results.get('messages', [])
                    for msg_item in messages_res:
                        msg_detail = service.users().messages().get(userId='me', id=msg_item['id']).execute()
                        headers = msg_detail.get('payload', {}).get('headers', [])
                        subject = next((h['value'] for h in headers if h['name'].lower() == 'subject'), 'No Subject')
                        sender = next((h['value'] for h in headers if h['name'].lower() == 'from'), 'Unknown')
                        emails_list.append({
                            "from": sender,
                            "subject": subject,
                            "snippet": msg_detail.get('snippet', '')
                        })
                except Exception as ex:
                    logger.error(f"Gmail API read failed, using SQLite: {ex}")
            
            # Fallback/merge with SQLite Emails
            db_emails = db.query(Email).filter(Email.user_id == user_id).all()
            for e in db_emails:
                emails_list.append({
                    "from": e.sender,
                    "subject": e.subject,
                    "snippet": e.snippet
                })

            emails_str = "\n".join([f"- **From**: {e['from']}\n  **Sub**: {e['subject']}\n  *'{e['snippet']}'*" for e in emails_list])
            
            read_log = ActivityLog(
                user_id=user_id,
                action_type="email_read",
                description="Queried email inbox snippets.",
                status="completed",
                explanation="Read recent email inbox messages from Gmail / SQLite database."
            )
            db.add(read_log)
            db.commit()

            return f"Aapke recent emails ye hain 📬:\n\n{emails_str}"

        return "Planner was triggered, but no specific action could be resolved."

    async def execute_confirmed_action(self, gate_item: ConfirmationGate, db: Session) -> bool:
        """Executes a write action once approved by the user via the Confirmation Gate."""
        try:
            payload = json.loads(gate_item.payload)
            creds = self._get_google_credentials(gate_item.user_id, db)

            if gate_item.action_type == "send_email":
                if creds:
                    try:
                        # Send email using Google Gmail API
                        from email.mime.text import MIMEText
                        import base64
                        service = build("gmail", "v1", credentials=creds)
                        message = MIMEText(payload['body'])
                        message['to'] = payload['to']
                        message['subject'] = payload['subject']
                        raw = base64.urlsafe_b64encode(message.as_bytes()).decode()
                        service.users().messages().send(userId='me', body={'raw': raw}).execute()
                        logger.info(f"Successfully sent real Google email to {payload['to']}")
                    except Exception as e:
                        logger.error(f"Real Google Email send failed, writing to SQLite: {e}")
                
                # Stateful fallback: write to SQLite Emails table as sent
                new_mail = Email(
                    user_id=gate_item.user_id,
                    sender="aditya@halonix.co.in",
                    recipient=payload["to"],
                    subject=payload["subject"],
                    body=payload["body"],
                    snippet=payload["body"][:80] + "...",
                    status="sent",
                    timestamp=datetime.utcnow()
                )
                db.add(new_mail)
                db.commit()
                logger.info(f"Saved sent email to SQLite: {payload['subject']}")
                
            elif gate_item.action_type == "add_calendar":
                if creds:
                    try:
                        # Insert meeting using Google Calendar API
                        service = build("calendar", "v3", credentials=creds)
                        event = {
                            'summary': payload['title'],
                            'description': 'Scheduled via Aadi AI Planner',
                            'start': {
                                'dateTime': datetime.utcnow().isoformat() + 'Z',
                                'timeZone': 'UTC',
                            },
                            'end': {
                                'dateTime': datetime.utcnow().isoformat() + 'Z',
                                'timeZone': 'UTC',
                            }
                        }
                        service.events().insert(calendarId='primary', body=event).execute()
                        logger.info(f"Successfully added real meeting '{payload['title']}' to Google Calendar")
                    except Exception as e:
                        logger.error(f"Real Google Calendar insert failed, writing to SQLite: {e}")
                
                # Stateful fallback: write to SQLite CalendarEvent table
                new_event = CalendarEvent(
                    user_id=gate_item.user_id,
                    title=payload["title"],
                    event_time=payload["time"],
                    event_date=payload["date"],
                    description="Scheduled via Aadi AI Planner",
                    timestamp=datetime.utcnow()
                )
                db.add(new_event)
                db.commit()
                logger.info(f"Saved calendar meeting to SQLite: {payload['title']}")
                
            # Log successful execution in audit trail
            audit = ActivityLog(
                user_id=gate_item.user_id,
                action_type=gate_item.action_type,
                description=f"Successfully executed user-confirmed action: {gate_item.action_type}.",
                status="completed",
                explanation=f"Confirmed action execution completed. Reason: {gate_item.explanation}"
            )
            db.add(audit)
            db.commit()
            return True
        except Exception as e:
            logger.error(f"Failed to execute confirmed action: {e}")
            audit = ActivityLog(
                user_id=gate_item.user_id,
                action_type=gate_item.action_type,
                description=f"Failed to execute action: {gate_item.action_type}.",
                status="failed",
                explanation=str(e)
            )
            db.add(audit)
            db.commit()
            return False

task_planner = TaskChainingPlanner()
