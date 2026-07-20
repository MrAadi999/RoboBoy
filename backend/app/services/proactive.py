import logging
import json
import httpx
from datetime import datetime, timedelta
from sqlalchemy.orm import Session
from app.database import DailyBriefing, UserPreferences, ActivityLog, CalendarEvent, ECommerceOrder

logger = logging.getLogger(__name__)

class ProactiveEngine:
    async def compile_daily_briefing(self, user_id: int, db: Session) -> str:
        """
        Compiles the daily briefing:
        - Weather for city (from preferences or mock)
        - Calendar meetings for today
        - Business metrics (Flipkart/Amazon order statuses)
        - Formulates a summary personalized to the user's tone/language preferences.
        """
        # Fetch preferences
        prefs = db.query(UserPreferences).filter(UserPreferences.user_id == user_id).first()
        lang = prefs.language if prefs else "hinglish"
        tone = prefs.tone if prefs else "formal"
        
        # 1. Fetch Weather (dynamically looking up city from memory and using OpenWeather API)
        weather_info = "New Delhi: 31°C, Clear Sky 🌤️"
        try:
            from app.config import settings
            from app.database import UserMemory
            from app.services.memory_vector import decrypt_fact
            
            city = "New Delhi"
            memories = db.query(UserMemory).filter(UserMemory.user_id == user_id).all()
            for m in memories:
                fact_dec = decrypt_fact(m.fact).lower()
                if any(k in fact_dec for k in ["live in", "lives in", "city is", "hometown is", "resides in"]):
                    words = fact_dec.split()
                    for idx, w in enumerate(words):
                        if w in ["in", "is"] and idx + 1 < len(words):
                            pot_city = words[idx+1].strip(".,?!").capitalize()
                            if len(pot_city) > 2:
                                city = pot_city
                                break
            
            weather_key = settings.OPENWEATHER_KEY
            if weather_key:
                url = f"http://api.openweathermap.org/data/2.5/weather?q={city}&units=metric&appid={weather_key}"
                # Run synchronous HTTP in threadpool or direct timeout check since we are in async method
                with httpx.Client(timeout=3.0) as client:
                    res = client.get(url)
                    if res.status_code == 200:
                        wdata = res.json()
                        temp = wdata["main"]["temp"]
                        desc = wdata["weather"][0]["description"].capitalize()
                        weather_info = f"{city}: {temp}°C, {desc} 🌤️"
                    else:
                        weather_info = f"{city}: 31°C, Clear Sky 🌤️ (API Status {res.status_code})"
            else:
                weather_info = f"{city}: 31°C, Clear Sky 🌤️ (API Key Simulated)"
        except Exception as we:
            logger.warning(f"Error compiling real weather: {we}")
        
        # 2. Fetch Meetings from SQLite
        db_meetings = db.query(CalendarEvent).filter(
            CalendarEvent.user_id == user_id,
            CalendarEvent.event_date.icontains("today")
        ).all()
        
        meetings_text = ""
        if db_meetings:
            meetings_text = "\n".join([f"- {m.title} at {m.event_time} ({m.location or 'No Location'})" for m in db_meetings])
        else:
            meetings_text = "No meetings scheduled for today."

        # 3. Fetch E-commerce/Business Metrics from SQLite
        orders = db.query(ECommerceOrder).filter(ECommerceOrder.user_id == user_id).all()
        orders_text = ""
        if orders:
            orders_text = "\n".join([f"- {o.item} ({o.vendor}): {o.status} (Delivery: {o.delivery_date})" for o in orders])
        else:
            orders_text = "No pending orders."

        # 4. Formulate the Briefing text
        brief_prompt = (
            f"Generate a personal daily briefing for Aditya Kumar. "
            f"Language preference: {lang} (if hinglish, mix Hindi and English naturally). "
            f"Tone: {tone} (be very respectful and conversational). "
            f"Incorporate the following information: "
            f"\n- Weather: {weather_info}"
            f"\n- Today's Schedule:\n{meetings_text}"
            f"\n- Business Orders / Packages Status:\n{orders_text}"
            f"\nWrite a concise and motivating greeting."
        )

        response_text = ""
        from app.services.fugu import fugu_service
        from app.services.odysseus import odysseus_service
        try:
            response_text = await fugu_service.generate_response(brief_prompt, user_id, db)
        except Exception:
            try:
                response_text = await odysseus_service.generate_response(brief_prompt)
            except Exception as ex:
                logger.error(f"Failed to generate brief via LLM: {ex}")
                # Clean fallback response in preferred language
                if lang == "hinglish":
                    response_text = (
                        f"Namaste Aditya! Aapka Daily Briefing haazir hai. 🌤️\n\n"
                        f"**Mausam**: {weather_info}\n"
                        f"**Aaj ke Meetings**:\n{meetings_text}\n"
                        f"**Order Status**:\n{orders_text}\n\n"
                        f"Have a great day ahead!"
                    )
                else:
                    response_text = (
                        f"Hello Aditya! Here is your daily brief. 🌤️\n\n"
                        f"**Weather**: {weather_info}\n"
                        f"**Today's Schedule**:\n{meetings_text}\n"
                        f"**Orders Status**:\n{orders_text}\n\n"
                        f"Have a wonderful day!"
                    )

        # Store in DB
        new_brief = DailyBriefing(
            user_id=user_id,
            brief_content=response_text
        )
        db.add(new_brief)
        
        # Log to Activity Log
        audit = ActivityLog(
            user_id=user_id,
            action_type="daily_briefing",
            description="Compiled daily briefing card.",
            status="completed",
            explanation="Synthesized weather, calendar schedules, and Flipkart/Amazon orders from SQLite database."
        )
        db.add(audit)
        db.commit()

        return response_text

    async def get_traffic_adjusted_reminders(self, user_id: int, db: Session) -> list[dict]:
        """
        Simulates location + traffic context checking for meetings:
        Flags early departure warnings if traffic is simulated to be high.
        """
        db_meetings = db.query(CalendarEvent).filter(
            CalendarEvent.user_id == user_id,
            CalendarEvent.event_date.icontains("today")
        ).all()
        
        reminders = []
        
        # Simulating a dynamic check on travel times
        for idx, meeting in enumerate(db_meetings):
            is_delayed = idx % 2 == 0 # Mock alternate meetings having traffic delays
            
            lead_time = "15 mins" if is_delayed else "5 mins"
            warning = f"Traffic is heavy today. Leave {lead_time} early!" if is_delayed else None
            
            reminders.append({
                "meeting_title": meeting.title,
                "scheduled_time": meeting.event_time,
                "status": "warning" if is_delayed else "normal",
                "alert_message": f"Reminder: '{meeting.title}' starts at {meeting.event_time}. " + (warning if warning else "Traffic is clear.")
            })
            
        return reminders

proactive_engine = ProactiveEngine()
