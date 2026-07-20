import logging
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.database import get_db, ChatMessage, User, InteractionLog
from app.schemas import ChatRequest, ChatResponse
from app.api.auth import get_current_user
from app.api.preferences import get_or_create_preferences
from app.core.router import smart_router
from app.services.memory_vector import memory_vector_service
from app.services.planner import task_planner

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/chat", tags=["chat"])

@router.post("/", response_model=ChatResponse)
async def chat_interaction(
    payload: ChatRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # 1. Fetch user preferences (explicit tone/language + implicit learning metrics)
    prefs = get_or_create_preferences(current_user.id, db)
    
    # 2. Check if the task requires multi-step planning (Task Chaining Automation Layer)
    if task_planner.can_handle(payload.message):
        logger.info(f"Routing query '{payload.message}' to task planner agent.")
        try:
            response_text = await task_planner.execute_plan(current_user.id, payload.message, db)
            mode_used = "odysseus"  # Local executor
            is_fallback = False
        except Exception as e:
            logger.error(f"Task planning execution failed: {e}")
            response_text = "I encountered an issue executing the automation plan. Please try again."
            mode_used = "odysseus"
            is_fallback = True
    else:
        # 3. Retrieve relevant memory facts via Vector Search (works offline & online)
        memory_context = await memory_vector_service.get_relevant_context(current_user.id, payload.message, db)

        # 4. Synthesize personalized instructions based on user style
        u_name = prefs.user_name or "Aditya"
        a_name = prefs.assistant_name or "Aadi AI"
        char_lang = (prefs.character_language or "hinglish").lower()
        style_instruction = (
            f"User Preference Settings: Character Language={char_lang}, Tone={prefs.tone}. "
            f"Your assistant name is {a_name}. The user's name is {u_name}. "
            f"Address yourself as {a_name} and address the user as {u_name}. "
        )
        if char_lang == "hinglish":
            style_instruction += "Respond in Hinglish (natural Hindi + English written in Roman/Latin characters). "
        elif char_lang == "hindi":
            style_instruction += "Respond in proper, grammatically correct Hindi using the Devanagari script (हिंदी script). "
        elif char_lang == "german":
            style_instruction += "Respond in proper German (Deutsch). "
        elif char_lang == "chinese":
            style_instruction += "Respond in proper Chinese (Simplified Mandarin / 中文). "
        elif char_lang == "bhojpuri":
            style_instruction += "Respond in Bhojpuri language using the Devanagari script (भोजपुरी). "
        elif char_lang == "maithili":
            style_instruction += "Respond in Maithili language using the Devanagari script (मैथिली). "
        else:
            style_instruction += "Respond in clear, grammatical, professional English. "
            
        if prefs.tone == "casual":
            style_instruction += "Keep the tone friendly, conversational, and use emojis."
        else:
            style_instruction += "Keep the tone structured, polite, and formal."

        prompt = payload.message
        if memory_context:
            prompt = f"{memory_context}\n\n{style_instruction}\n\nUser Query: {payload.message}"
        else:
            prompt = f"{style_instruction}\n\nUser Query: {payload.message}"

        # 5. Route request to cloud/local LLM
        try:
            response_text, mode_used, is_fallback = await smart_router.route_request(
                message=prompt, 
                user_id=current_user.id,
                db=db,
                mode_override=payload.mode_override
            )
        except Exception as e:
            logger.error(f"Routing failed completely: {e}")
            response_text = "I'm sorry, both my cloud and local minds are experiencing high latency. Main abhi aapki help nahi kar paunga. Please try again."
            mode_used = "odysseus"
            is_fallback = True

    # 6. Log messages to database
    user_msg = ChatMessage(
        user_id=current_user.id,
        role="user",
        content=payload.message
    )
    db.add(user_msg)
    
    assistant_msg = ChatMessage(
        user_id=current_user.id,
        role="assistant",
        content=response_text,
        mode=mode_used
    )
    db.add(assistant_msg)
    
    # 7. IMPLICIT PERSONALIZATION: Analyze language style (Hinglish ratio) and message counts
    words = payload.message.lower().split()
    total_words = len(words)
    hindi_keywords = ["hai", "ko", "se", "ka", "ki", "aur", "toh", "aadi", "tum", "mera", "kya", "kar", "ho", "raha", "batao", "kholo", "likho", "karo", "naam", "samay", "namaste", "bilkul", "samajh", "bhai", "yaar", "accha", "haan"]
    hindi_count = sum(1 for w in words if w in hindi_keywords)
    ratio = hindi_count / total_words if total_words > 0 else 0.5

    interaction = InteractionLog(
        user_id=current_user.id,
        query_type="voice" if ("voice" in payload.message.lower() or "suno" in payload.message.lower()) else "chat",
        hinglish_words_count=hindi_count,
        total_words_count=total_words,
        response_length=len(response_text)
    )
    db.add(interaction)
    
    # Update Hinglish moving average ratio if user input is moderately long
    if total_words > 3:
        prefs.hinglish_ratio = prefs.hinglish_ratio * 0.85 + ratio * 0.15
        
    db.commit()

    return ChatResponse(
        response=response_text,
        mode_used=mode_used,
        is_fallback=is_fallback,
        timestamp=datetime.utcnow()
    )

@router.get("/history")
def get_chat_history(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Retrieve all historical chat messages for the current user."""
    messages = db.query(ChatMessage).filter(ChatMessage.user_id == current_user.id).order_by(ChatMessage.timestamp.asc()).all()
    return [
        {
            "role": msg.role,
            "content": msg.content,
            "mode_used": msg.mode,
            "is_fallback": False,
            "timestamp": msg.timestamp
        }
        for msg in messages
    ]

