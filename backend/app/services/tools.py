import logging
import json
import urllib.parse
import webbrowser
import requests
import os
import sys
from datetime import datetime
from sqlalchemy.orm import Session
from app.database import ActivityLog, ConfirmationGate, Email, CalendarEvent, ECommerceOrder, UserMemory, UserPreferences
from app.config import settings

logger = logging.getLogger(__name__)

# List of tool schema definitions in Gemini / OpenAI standard format
TOOL_DEFINITIONS = [
    {
        "name": "get_weather",
        "description": "Fetch the current weather for a specific city.",
        "parameters": {
            "type": "object",
            "properties": {
                "city": {"type": "string", "description": "The city to check weather for (e.g., 'Mumbai', 'New Delhi')."}
            },
            "required": ["city"]
        }
    },
    {
        "name": "search_wikipedia",
        "description": "Lookup informational summaries on Wikipedia.",
        "parameters": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "The topic to search on Wikipedia."}
            },
            "required": ["query"]
        }
    },
    {
        "name": "google_search",
        "description": "Search Google Web for external information or links.",
        "parameters": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "The search query query string."}
            },
            "required": ["query"]
        }
    },
    {
        "name": "play_youtube_video",
        "description": "Play videos or search queries on YouTube in the browser.",
        "parameters": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "Name of the video or song to search and play."}
            },
            "required": ["query"]
        }
    },
    {
        "name": "get_system_stats",
        "description": "Check current system CPU usage, memory percentage, and active uptime.",
        "parameters": {
            "type": "object",
            "properties": {}
        }
    },
    {
        "name": "take_screenshot",
        "description": "Capture a screenshot of the local computer screen.",
        "parameters": {
            "type": "object",
            "properties": {}
        }
    },
    {
        "name": "open_desktop_app",
        "description": "Open or launch standard applications locally (e.g. Chrome, Safari, Slack).",
        "parameters": {
            "type": "object",
            "properties": {
                "app_name": {"type": "string", "description": "Name of the application to open."}
            },
            "required": ["app_name"]
        }
    },
    {
        "name": "read_emails",
        "description": "List the recent email inbox snippets from Gmail or the local database.",
        "parameters": {
            "type": "object",
            "properties": {}
        }
    },
    {
        "name": "draft_email",
        "description": "Create a new email draft to send. This requires confirmation gate approval before actual sending.",
        "parameters": {
            "type": "object",
            "properties": {
                "to": {"type": "string", "description": "Recipient email address."},
                "subject": {"type": "string", "description": "Subject of the email."},
                "body": {"type": "string", "description": "Body content of the email."}
            },
            "required": ["to", "subject", "body"]
        }
    },
    {
        "name": "read_calendar_events",
        "description": "Query Google Calendar or local meetings schedule for today and tomorrow.",
        "parameters": {
            "type": "object",
            "properties": {}
        }
    },
    {
        "name": "schedule_meeting",
        "description": "Schedule a new calendar event. This requires confirmation gate approval.",
        "parameters": {
            "type": "object",
            "properties": {
                "title": {"type": "string", "description": "Title of the meeting."},
                "date": {"type": "string", "description": "Date of the event (e.g. 'Today', 'Tomorrow', '2026-08-15')."},
                "time": {"type": "string", "description": "Time of the event (e.g. '10:00 AM', '4:30 PM')."}
            },
            "required": ["title", "date", "time"]
        }
    },
    {
        "name": "manage_memory",
        "description": "Manage user memory profile facts (save new fact, delete obsolete memory).",
        "parameters": {
            "type": "object",
            "properties": {
                "action": {"type": "string", "enum": ["save", "delete"], "description": "Action to perform: 'save' or 'delete'."},
                "fact": {"type": "string", "description": "The fact text to save (required for action='save')."},
                "memory_id": {"type": "integer", "description": "The ID of the memory to delete (required for action='delete')."}
            },
            "required": ["action"]
        }
    },
    {
        "name": "system_power",
        "description": "Execute system controls like shutdown or restart.",
        "parameters": {
            "type": "object",
            "properties": {
                "action": {"type": "string", "enum": ["shutdown", "restart"], "description": "Power action to trigger: 'shutdown' or 'restart'."}
            },
            "required": ["action"]
        }
    }
]

class ToolExecutor:
    async def execute_tool(self, name: str, arguments: dict, user_id: int, db: Session) -> str:
        """Executes a tool call and returns the result as string."""
        logger.info(f"Executing tool {name} with args {arguments} for user {user_id}")
        
        # Verify permissions if applicable
        prefs = db.query(UserPreferences).filter(UserPreferences.user_id == user_id).first()
        
        try:
            if name == "get_weather":
                city = arguments.get("city", "New Delhi")
                weather_key = settings.OPENWEATHER_KEY
                if weather_key:
                    url = f"http://api.openweathermap.org/data/2.5/weather?q={city}&units=metric&appid={weather_key}"
                    res = requests.get(url, timeout=3.0)
                    if res.status_code == 200:
                        data = res.json()
                        temp = data["main"]["temp"]
                        desc = data["weather"][0]["description"].capitalize()
                        return f"Weather in {city}: {temp}°C, {desc}."
                # Fallback
                return f"Weather in {city}: 31°C, Clear Sky (API Key Simulated)."

            elif name == "search_wikipedia":
                query = arguments.get("query", "")
                url = f"https://en.wikipedia.org/w/api.php?action=query&prop=extracts&exintro&explaintext&titles={query}&format=json&redirects=1"
                res = requests.get(url, timeout=4.0).json()
                pages = res.get("query", {}).get("pages", {})
                page_id = list(pages.keys())[0]
                if page_id != "-1":
                    extract = pages[page_id].get("extract", "")
                    sentences = ". ".join(extract.split(". ")[:2]) + "."
                    return f"Wikipedia result: {sentences}"
                return "No Wikipedia entry found for this query."

            elif name == "google_search":
                query = arguments.get("query", "")
                url = f"https://www.google.com/search?q={urllib.parse.quote(query)}"
                webbrowser.open(url)
                return f"Opened Google Web search for '{query}' in user's browser."

            elif name == "play_youtube_video":
                query = arguments.get("query", "")
                url = f"https://www.youtube.com/results?search_query={urllib.parse.quote(query)}"
                webbrowser.open(url)
                return f"Opened YouTube search for '{query}' in user's browser."

            elif name == "get_system_stats":
                import psutil
                cpu = psutil.cpu_percent()
                mem = psutil.virtual_memory().percent
                return f"System CPU is at {cpu}% and Virtual Memory is at {mem}%."

            elif name == "take_screenshot":
                from app.api.system import capture_screenshot_local
                path = capture_screenshot_local()
                if path:
                    return f"Screenshot taken successfully and saved at {path}."
                return "Failed to take screen capture."

            elif name == "open_desktop_app":
                app_name = arguments.get("app_name", "")
                from app.api.system import run_open_app_local
                success = run_open_app_local(app_name)
                if success:
                    return f"Successfully launched {app_name}."
                return f"Could not launch application {app_name}."

            elif name == "read_emails":
                if prefs and not prefs.permission_email:
                    return "ERROR: Permission denied. User has not granted email access permissions in settings."
                
                from app.services.planner import task_planner
                creds = task_planner._get_google_credentials(user_id, db)
                emails_list = []
                if creds:
                    try:
                        from googleapiclient.discovery import build
                        service = build("gmail", "v1", credentials=creds)
                        results = service.users().messages().list(userId='me', maxResults=3).execute()
                        messages = results.get('messages', [])
                        for m_item in messages:
                            m_detail = service.users().messages().get(userId='me', id=m_item['id']).execute()
                            headers = m_detail.get('payload', {}).get('headers', [])
                            sub = next((h['value'] for h in headers if h['name'].lower() == 'subject'), 'No Subject')
                            snd = next((h['value'] for h in headers if h['name'].lower() == 'from'), 'Unknown')
                            emails_list.append(f"From: {snd}, Subject: {sub}, Snippet: {m_detail.get('snippet', '')}")
                    except Exception as ge:
                        logger.error(f"Google Gmail read failed: {ge}")
                
                # Fallback / merge with local
                db_emails = db.query(Email).filter(Email.user_id == user_id).limit(3).all()
                for e in db_emails:
                    emails_list.append(f"From: {e.sender}, Subject: {e.subject}, Snippet: {e.snippet} (Local Database)")
                
                if emails_list:
                    return "\n".join(emails_list)
                return "Your inbox is empty."

            elif name == "draft_email":
                if prefs and not prefs.permission_email:
                    return "ERROR: Permission denied. User has not granted email access permissions in settings."
                
                to = arguments.get("to")
                subject = arguments.get("subject")
                body = arguments.get("body")
                
                payload = {"to": to, "subject": subject, "body": body}
                explanation = f"Drafted email to {to} regarding '{subject}'."
                
                gate = ConfirmationGate(
                    user_id=user_id,
                    action_type="send_email",
                    payload=json.dumps(payload),
                    explanation=explanation,
                    status="pending"
                )
                db.add(gate)
                
                log = ActivityLog(
                    user_id=user_id,
                    action_type="email_draft",
                    description=f"Drafted email to {to}.",
                    status="pending_confirmation",
                    explanation=explanation
                )
                db.add(log)
                db.commit()
                db.refresh(gate)
                
                return f"[CONFIRMATION_REQUIRED] Action queued for approval. Action ID: {gate.id}. Explanation: {explanation}."

            elif name == "read_calendar_events":
                if prefs and not prefs.permission_calendar:
                    return "ERROR: Permission denied. User has not granted calendar access permissions in settings."
                
                from app.services.planner import task_planner
                creds = task_planner._get_google_credentials(user_id, db)
                meetings = []
                if creds:
                    try:
                        from googleapiclient.discovery import build
                        service = build("calendar", "v3", credentials=creds)
                        now = datetime.utcnow().isoformat() + 'Z'
                        res = service.events().list(calendarId='primary', timeMin=now, maxResults=3, singleEvents=True, orderBy='startTime').execute()
                        events = res.get('items', [])
                        for e in events:
                            start = e['start'].get('dateTime', e['start'].get('date'))
                            meetings.append(f"Title: {e.get('summary', 'Untitled')}, Time: {start} (Google Calendar)")
                    except Exception as ge:
                        logger.error(f"Google Calendar read failed: {ge}")
                
                # Merge local db meetings
                db_meetings = db.query(CalendarEvent).filter(CalendarEvent.user_id == user_id).all()
                for m in db_meetings:
                    meetings.append(f"Title: {m.title}, Time: {m.event_time} ({m.event_date})")
                
                if meetings:
                    return "\n".join(meetings)
                return "No meetings scheduled."

            elif name == "schedule_meeting":
                if prefs and not prefs.permission_calendar:
                    return "ERROR: Permission denied. User has not granted calendar access permissions in settings."
                
                title = arguments.get("title")
                date = arguments.get("date")
                time_str = arguments.get("time")
                
                payload = {"title": title, "date": date, "time": time_str}
                explanation = f"Add calendar event: '{title}' at {time_str} ({date})."
                
                gate = ConfirmationGate(
                    user_id=user_id,
                    action_type="add_calendar",
                    payload=json.dumps(payload),
                    explanation=explanation,
                    status="pending"
                )
                db.add(gate)
                
                log = ActivityLog(
                    user_id=user_id,
                    action_type="calendar_write",
                    description=f"Scheduled meeting: {title}.",
                    status="pending_confirmation",
                    explanation=explanation
                )
                db.add(log)
                db.commit()
                db.refresh(gate)
                
                return f"[CONFIRMATION_REQUIRED] Action queued for approval. Action ID: {gate.id}. Explanation: {explanation}."

            elif name == "manage_memory":
                action = arguments.get("action")
                from app.services.memory_vector import memory_vector_service
                
                if action == "save":
                    fact = arguments.get("fact")
                    if not fact:
                        return "ERROR: Missing 'fact' parameter for action='save'."
                    await memory_vector_service.save_user_memory(user_id, fact, db)
                    return f"Successfully saved memory fact: '{fact}'."
                    
                elif action == "delete":
                    mem_id = arguments.get("memory_id")
                    if not mem_id:
                        return "ERROR: Missing 'memory_id' parameter for action='delete'."
                    
                    mem = db.query(UserMemory).filter(UserMemory.id == mem_id, UserMemory.user_id == user_id).first()
                    if not mem:
                        return f"Memory with ID {mem_id} not found."
                    db.delete(mem)
                    db.commit()
                    memory_vector_service.invalidate_cache(user_id)
                    return f"Successfully deleted memory fact ID {mem_id}."
                
                return f"Unsupported memory management action: {action}."

            elif name == "system_power":
                action = arguments.get("action")
                from app.api.system import power_endpoint, PowerPayload
                
                # Directly execute
                import threading
                import time
                def exec_power():
                    time.sleep(3)
                    if action == "shutdown":
                        if sys.platform == "darwin":
                            os.system("sudo shutdown -h now")
                        else:
                            os.system("shutdown /s /t 0")
                    elif action == "restart":
                        if sys.platform == "darwin":
                            os.system("sudo shutdown -r now")
                        else:
                            os.system("shutdown /r /t 0")
                
                threading.Thread(target=exec_power, daemon=True).start()
                return f"Triggered system {action} in 3 seconds."

        except Exception as err:
            logger.error(f"Error executing tool {name}: {err}")
            return f"ERROR: Tool execution failed: {str(err)}"
            
        return f"Tool {name} was not recognized."

tool_executor = ToolExecutor()
