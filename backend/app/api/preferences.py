import logging
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.database import get_db, User, UserPreferences
from app.schemas import PreferencesResponse, PreferencesUpdate
from app.api.auth import get_current_user

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/preferences", tags=["preferences"])

def get_or_create_preferences(user_id: int, db: Session) -> UserPreferences:
    prefs = db.query(UserPreferences).filter(UserPreferences.user_id == user_id).first()
    if not prefs:
        prefs = UserPreferences(
            user_id=user_id,
            tone="formal",
            language="hinglish",
            hinglish_ratio=0.5,
            preferred_length="medium",
            permission_calendar=False,
            permission_email=False,
            permission_location=False,
            permission_business=False,
            user_name="Aditya",
            assistant_name="Aadi AI"
        )
        db.add(prefs)
        db.commit()
        db.refresh(prefs)
        logger.info(f"Initialized default preferences for user ID {user_id}")
    return prefs

@router.get("/", response_model=PreferencesResponse)
def get_preferences(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get user configuration preferences, tone, and permissions.
    """
    prefs = get_or_create_preferences(current_user.id, db)
    return prefs

@router.put("/", response_model=PreferencesResponse)
def update_preferences(
    payload: PreferencesUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Update explicit preferences (tone, language, calendar/email/location/business permission switches).
    """
    prefs = get_or_create_preferences(current_user.id, db)
    
    if payload.tone is not None:
        prefs.tone = payload.tone
    if payload.language is not None:
        prefs.language = payload.language
    if payload.permission_calendar is not None:
        prefs.permission_calendar = payload.permission_calendar
    if payload.permission_email is not None:
        prefs.permission_email = payload.permission_email
    if payload.permission_location is not None:
        prefs.permission_location = payload.permission_location
    if payload.permission_business is not None:
        prefs.permission_business = payload.permission_business
    if payload.user_name is not None:
        prefs.user_name = payload.user_name
    if payload.assistant_name is not None:
        prefs.assistant_name = payload.assistant_name

    db.commit()
    db.refresh(prefs)
    logger.info(f"Updated preferences for user ID {current_user.id}")
    return prefs
