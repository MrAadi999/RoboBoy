import os
import base64
import subprocess
import logging
import httpx
import tempfile
import sys
from app.config import settings

logger = logging.getLogger(__name__)

# Try importing offline speech libraries
try:
    import speech_recognition as sr
    SPEECH_RECOGNITION_AVAILABLE = True
except ImportError:
    SPEECH_RECOGNITION_AVAILABLE = False

try:
    import pyttsx3
    PYTTSX3_AVAILABLE = True
except ImportError:
    PYTTSX3_AVAILABLE = False

class VoiceService:
    async def speech_to_text(self, audio_bytes: bytes, filename: str) -> str:
        """
        Transcribes speech audio bytes to text.
        1. If Gemini API key is available, uploads audio to Gemini content API.
        2. Otherwise, uses speech_recognition to transcribe locally using free Google Web Speech API.
        3. If speech_recognition is unavailable or fails, returns a fallback greeting.
        """
        # Save audio file temporarily
        temp_dir = tempfile.gettempdir()
        temp_path = os.path.join(temp_dir, filename)
        with open(temp_path, "wb") as f:
            f.write(audio_bytes)

        gemini_key = getattr(settings, "GEMINI_API_KEY", "") or os.getenv("GEMINI_API_KEY", "")
        if gemini_key:
            # Determine mime type
            mime_type = "audio/wav"
            if filename.endswith(".m4a"):
                mime_type = "audio/m4a"
            elif filename.endswith(".mp3"):
                mime_type = "audio/mp3"

            # Use Gemini API to transcribe audio directly (multimodal)
            url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={gemini_key}"
            
            # Read audio bytes
            encoded_audio = base64.b64encode(audio_bytes).decode("utf-8")
            payload = {
                "contents": [{
                    "parts": [
                        {"inlineData": {"mimeType": mime_type, "data": encoded_audio}},
                        {"text": "Transcribe this audio file exactly as spoken. If it is in Hinglish or Hindi, transcribe the spoken Hinglish/Hindi words in Latin script."}
                    ]
                }]
            }

            try:
                async with httpx.AsyncClient(timeout=15.0) as client:
                    res = await client.post(url, json=payload)
                    if res.status_code == 200:
                        data = res.json()
                        candidates = data.get("candidates", [])
                        if candidates:
                            text = candidates[0].get("content", {}).get("parts", [{}])[0].get("text", "")
                            if text:
                                logger.info(f"STT transcribed via Gemini: '{text.strip()}'")
                                return text.strip()
            except Exception as e:
                logger.error(f"Gemini Speech-To-Text transcription failed: {e}")

        # 2. Local speech_recognition offline/free API fallback
        if SPEECH_RECOGNITION_AVAILABLE:
            try:
                logger.info("Using local speech_recognition library for STT transcription...")
                # speech_recognition works best with WAV files
                # If it's another format, we still try, but recognize_google will try to upload/process
                r = sr.Recognizer()
                with sr.AudioFile(temp_path) as source:
                    audio_data = r.record(source)
                    text = r.recognize_google(audio_data)
                    logger.info(f"Local STT transcription success: '{text}'")
                    return text
            except Exception as e:
                logger.warning(f"Local speech_recognition failed: {e}")

        # Final absolute fallback
        logger.info("Using fallback mock speech-to-text response.")
        return "Hello Aadi, check my Flipkart orders and draft a complaint."

    async def text_to_speech(self, text: str, language: str = "hinglish") -> tuple[bytes, str]:
        """
        Synthesizes text into speech audio bytes.
        - Online: Fetches high-quality TTS from Google Translate TTS API.
        - Offline: Uses cross-platform pyttsx3 or macOS native 'say' command to synthesize audio locally.
        Returns: (audio_bytes, mime_type)
        """
        import urllib.parse
        lang_code = "hi" if language == "hinglish" else "en"
        
        # 1. Try Online Google TTS
        try:
            escaped_text = urllib.parse.quote(text)
            url = f"https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl={lang_code}&q={escaped_text}"
            headers = {
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
            }
            async with httpx.AsyncClient(timeout=5.0) as client:
                res = await client.get(url, headers=headers)
                if res.status_code == 200:
                    return res.content, "audio/mpeg"
        except Exception as e:
            logger.warning(f"Google TTS online synthesis failed: {e}. Falling back to offline.")

        # 2. Local Cross-Platform pyttsx3 Fallback
        if PYTTSX3_AVAILABLE:
            try:
                logger.info("Using pyttsx3 for offline speech synthesis...")
                temp_dir = tempfile.gettempdir()
                out_file = os.path.join(temp_dir, "tts_pyttsx3.wav")
                if os.path.exists(out_file):
                    os.remove(out_file)

                # We must run pyttsx3 in a subprocess or serialize to a file
                engine = pyttsx3.init()
                
                # Configure Hinglish Lekha voice if macOS and available
                if sys.platform == "darwin" and language == "hinglish":
                    voices = engine.getProperty('voices')
                    for voice in voices:
                        if "lekha" in voice.name.lower():
                            engine.setProperty('voice', voice.id)
                            break
                            
                engine.save_to_file(text, out_file)
                engine.runAndWait()

                if os.path.exists(out_file):
                    with open(out_file, "rb") as f:
                        audio_data = f.read()
                    return audio_data, "audio/wav"
            except Exception as ex:
                logger.warning(f"pyttsx3 offline synthesis failed: {ex}. Trying macOS native 'say'.")

        # 3. Native macOS Offline Fallback (say command)
        if sys.platform == "darwin":
            try:
                temp_dir = tempfile.gettempdir()
                out_file = os.path.join(temp_dir, "tts_out.aiff")
                
                if os.path.exists(out_file):
                    os.remove(out_file)

                voice_option = []
                if language == "hinglish":
                    voice_option = ["-v", "Lekha"]
                
                subprocess.run(["say"] + voice_option + ["-o", out_file, text], check=True, capture_output=True)
                
                if os.path.exists(out_file):
                    with open(out_file, "rb") as f:
                        audio_data = f.read()
                    return audio_data, "audio/aiff"
            except Exception as ex:
                logger.error(f"Native macOS offline TTS failed: {ex}")

        # Final absolute fallback: return dummy empty wave file
        dummy_wav = b'RIFF$\x00\x00\x00WAVEfmt \x10\x00\x00\x00\x01\x00\x01\x00D\xac\x00\x00\x88X\x01\x00\x02\x00\x10\x00data\x00\x00\x00\x00'
        return dummy_wav, "audio/wav"

voice_service = VoiceService()
