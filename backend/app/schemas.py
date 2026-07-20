from pydantic import BaseModel
from datetime import datetime
from typing import Optional, List

# Auth schemas
class OTPRequest(BaseModel):
    phone_or_email: str

class OTPVerify(BaseModel):
    phone_or_email: str
    otp: str

class Token(BaseModel):
    access_token: str
    token_type: str

# Chat schemas
class ChatRequest(BaseModel):
    message: str
    mode_override: Optional[str] = "auto"  # "auto", "fugu" (cloud), "odysseus" (local)

class ChatResponse(BaseModel):
    response: str
    mode_used: str  # "fugu" or "odysseus"
    is_fallback: bool
    timestamp: datetime

# Memory schemas
class MemoryCreate(BaseModel):
    fact: str

class MemoryResponse(BaseModel):
    id: int
    fact: str
    created_at: datetime

    class Config:
        from_attributes = True

# Preferences schemas
class PreferencesUpdate(BaseModel):
    tone: Optional[str] = None
    language: Optional[str] = None
    permission_calendar: Optional[bool] = None
    permission_email: Optional[bool] = None
    permission_location: Optional[bool] = None
    permission_business: Optional[bool] = None
    user_name: Optional[str] = None
    assistant_name: Optional[str] = None

class PreferencesResponse(BaseModel):
    tone: str
    language: str
    hinglish_ratio: float
    preferred_length: str
    permission_calendar: bool
    permission_email: bool
    permission_location: bool
    permission_business: bool
    user_name: Optional[str] = "Aditya"
    assistant_name: Optional[str] = "Aadi AI"
    updated_at: datetime

    class Config:
        from_attributes = True

# Activity Log schemas
class ActivityLogResponse(BaseModel):
    id: int
    action_type: str
    description: str
    status: str
    explanation: Optional[str]
    timestamp: datetime

    class Config:
        from_attributes = True

# Confirmation Gate schemas
class ConfirmationAction(BaseModel):
    approve: bool  # True to approve, False to deny

class ConfirmationGateResponse(BaseModel):
    id: int
    action_type: str
    payload: str
    explanation: Optional[str]
    status: str
    timestamp: datetime

    class Config:
        from_attributes = True

# Daily Briefing schemas
class DailyBriefingResponse(BaseModel):
    id: int
    brief_content: str
    compiled_at: datetime

    class Config:
        from_attributes = True

# Voice schemas
class TTSRequest(BaseModel):
    text: str
    language: Optional[str] = "hinglish"

