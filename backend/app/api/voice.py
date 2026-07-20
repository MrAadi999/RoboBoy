import logging
from fastapi import APIRouter, UploadFile, File, Depends, HTTPException, status
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
from io import BytesIO
from app.database import get_db, User
from app.schemas import TTSRequest
from app.api.auth import get_current_user
from app.services.voice import voice_service

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/voice", tags=["voice"])

@router.post("/stt")
async def speech_to_text_endpoint(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Upload an audio recording file and receive its text transcription.
    """
    logger.info(f"Received speech audio file {file.filename} for transcription.")
    try:
        audio_bytes = await file.read()
        transcription = await voice_service.speech_to_text(audio_bytes, file.filename)
        return {
            "status": "success",
            "transcription": transcription
        }
    except Exception as e:
        logger.error(f"Speech-to-text endpoint failure: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Speech transcription failed: {str(e)}"
        )

@router.post("/tts")
async def text_to_speech_endpoint(
    payload: TTSRequest,
    current_user: User = Depends(get_current_user)
):
    """
    Synthesize text to speech audio and return a streaming audio response.
    """
    logger.info(f"Synthesizing speech for text: '{payload.text}' in {payload.language}.")
    try:
        audio_bytes, mime_type = await voice_service.text_to_speech(payload.text, payload.language)
        return StreamingResponse(
            BytesIO(audio_bytes),
            media_type=mime_type,
            headers={
                "Content-Disposition": f"attachment; filename=speech.{mime_type.split('/')[-1]}"
            }
        )
    except Exception as e:
        logger.error(f"Text-to-speech endpoint failure: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Speech synthesis failed: {str(e)}"
        )
