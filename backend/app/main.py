import logging
import threading
import time
import asyncio
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import os
from app.database import init_db
from app.api import auth, chat, memory, preferences, proactive, planner, voice, system, google_oauth

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

# Initialize FastAPI application
app = FastAPI(
    title="Aadi AI - Phase 2 Backend",
    description="Backend services for deep memory, voice pipeline, task automation, and proactive briefings.",
    version="2.0.0"
)

# Mount static files folder
backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
static_dir = os.path.join(backend_dir, "static")
os.makedirs(static_dir, exist_ok=True)
app.mount("/static", StaticFiles(directory=static_dir), name="static")

# CORS Configuration for Flutter Frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # In production, restrict this to specific origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

async def run_async_scheduler():
    """Asynchronous scheduler running in the main event loop, checking hourly for job execution."""
    logger.info("Starting background async scheduler loop...")
    await asyncio.sleep(10)
    
    from app.services.memory_vector import memory_vector_service
    from app.services.proactive import proactive_engine
    from app.database import SessionLocal, User
    from datetime import datetime
    
    last_summarization_date = None
    last_briefing_date = None
    
    while True:
        now = datetime.now()
        current_date = now.date()
        current_hour = now.hour
        
        db = SessionLocal()
        try:
            # 1. Run Nightly Memory Summarization (at 2:00 AM)
            if current_hour == 2 and last_summarization_date != current_date:
                users = db.query(User).all()
                for user in users:
                    logger.info(f"Running nightly memory summarization job for user ID {user.id}")
                    await memory_vector_service.run_nightly_summarization(user.id, db)
                    await asyncio.sleep(2)
                last_summarization_date = current_date
                logger.info("Nightly memory summarization completed.")
                
            # 2. Run Daily Briefing Compilation (at 8:00 AM)
            elif current_hour == 8 and last_briefing_date != current_date:
                users = db.query(User).all()
                for user in users:
                    logger.info(f"Running daily briefing compiler for user ID {user.id}")
                    brief_text = await proactive_engine.compile_daily_briefing(user.id, db)
                    # Push via WebSocket
                    from app.api.proactive import ws_manager
                    await ws_manager.send_personal_message({
                        "type": "daily_briefing",
                        "briefing": brief_text
                    }, user.id)
                    await asyncio.sleep(2)
                last_briefing_date = current_date
                logger.info("Daily briefing compilation completed.")
                
            # 3. Check for traffic adjusted alerts and push over WS
            users = db.query(User).all()
            for user in users:
                reminders = await proactive_engine.get_traffic_adjusted_reminders(user.id, db)
                warnings = [r for r in reminders if r["status"] == "warning"]
                if warnings:
                    from app.api.proactive import ws_manager
                    await ws_manager.send_personal_message({
                        "type": "traffic_warnings",
                        "reminders": warnings
                    }, user.id)

        except Exception as e:
            logger.error(f"Error in scheduler job execution: {e}")
        finally:
            db.close()
            
        # Sleep for 15 minutes before checking the clock again
        await asyncio.sleep(900)

# Initialize Database tables
@app.on_event("startup")
def on_startup():
    logger.info("Initializing SQLite database...")
    init_db()
    logger.info("SQLite database initialized successfully.")
    
    # Start async background scheduler in the event loop
    asyncio.create_task(run_async_scheduler())
    logger.info("Async background scheduler task spawned in event loop.")

# Include Endpoints under /api prefix
app.include_router(auth.router, prefix="/api")
app.include_router(chat.router, prefix="/api")
app.include_router(memory.router, prefix="/api")
app.include_router(preferences.router, prefix="/api")
app.include_router(proactive.router, prefix="/api")
app.include_router(planner.router, prefix="/api")
app.include_router(voice.router, prefix="/api")
app.include_router(system.router, prefix="/api")
app.include_router(google_oauth.router, prefix="/api")

@app.get("/health")
def health_check():
    return {
        "status": "healthy",
        "service": "Aadi AI Backend",
        "timestamp": "2026-07-16T23:51:56+05:30"
    }

@app.get("/")
def read_root():
    return {
        "message": "Welcome to Aadi AI Phase 2 API. Namaste!",
        "docs_url": "/docs"
    }
