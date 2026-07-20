import logging
from fastapi import APIRouter, Depends, HTTPException, status, WebSocket, WebSocketDisconnect
from sqlalchemy.orm import Session
from app.database import get_db, User
from app.api.auth import get_current_user
from app.services.proactive import proactive_engine

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/proactive", tags=["proactive"])

class ConnectionManager:
    def __init__(self):
        # Map user_id (int) -> list of WebSockets
        self.active_connections: dict[int, list[WebSocket]] = {}

    async def connect(self, user_id: int, websocket: WebSocket):
        await websocket.accept()
        if user_id not in self.active_connections:
            self.active_connections[user_id] = []
        self.active_connections[user_id].append(websocket)
        logger.info(f"User {user_id} connected via WebSocket. Active: {len(self.active_connections[user_id])}")

    def disconnect(self, user_id: int, websocket: WebSocket):
        if user_id in self.active_connections:
            if websocket in self.active_connections[user_id]:
                self.active_connections[user_id].remove(websocket)
            if not self.active_connections[user_id]:
                del self.active_connections[user_id]
        logger.info(f"User {user_id} disconnected from WebSocket.")

    async def send_personal_message(self, message: dict, user_id: int):
        if user_id in self.active_connections:
            for connection in self.active_connections[user_id]:
                try:
                    await connection.send_json(message)
                except Exception as e:
                    logger.warning(f"Error sending message over WS: {e}")

ws_manager = ConnectionManager()

@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket, token: str = None, db: Session = Depends(get_db)):
    if not token:
        token = websocket.query_params.get("token")
        
    user_id = None
    from jose import jwt
    from app.config import settings
    
    if not token:
        if settings.DEV_MODE:
            default_user = db.query(User).filter(User.phone_or_email == "aadi@ai.local").first()
            user_id = default_user.id if default_user else 1
        else:
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
            return
    else:
        try:
            payload = jwt.decode(token, settings.JWT_SECRET, algorithms=[settings.JWT_ALGORITHM])
            phone_or_email = payload.get("sub")
            user = db.query(User).filter(User.phone_or_email == phone_or_email).first()
            if user:
                user_id = user.id
            else:
                await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
                return
        except Exception:
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
            return

    await ws_manager.connect(user_id, websocket)
    try:
        while True:
            # Keep connection open and check client-side pings
            data = await websocket.receive_text()
            logger.info(f"WebSocket received text: {data}")
    except WebSocketDisconnect:
        ws_manager.disconnect(user_id, websocket)

@router.get("/daily-briefing")
async def get_daily_briefing(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Triggers and compiles a fresh daily briefing for the current user.
    """
    logger.info(f"Generating daily brief for user {current_user.phone_or_email}")
    try:
        brief_text = await proactive_engine.compile_daily_briefing(current_user.id, db)
        return {
            "status": "success",
            "briefing": brief_text
        }
    except Exception as e:
        logger.error(f"Failed to compile daily briefing: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Daily brief compilation failed: {str(e)}"
        )

@router.get("/reminders")
async def get_reminders(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Fetch context-aware, traffic-adjusted reminders for today's events.
    """
    logger.info(f"Checking reminders for user {current_user.phone_or_email}")
    try:
        reminders = await proactive_engine.get_traffic_adjusted_reminders(current_user.id, db)
        return {
            "status": "success",
            "reminders": reminders
        }
    except Exception as e:
        logger.error(f"Failed to query reminders: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to retrieve reminders: {str(e)}"
        )
