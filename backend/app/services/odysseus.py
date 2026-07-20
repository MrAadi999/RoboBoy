import logging
import httpx
from app.config import settings

logger = logging.getLogger(__name__)

class OdysseusService:
    async def generate_response(self, prompt: str, system_prompt: str = None) -> str:
        host = settings.OLLAMA_HOST
        model = settings.OLLAMA_MODEL
        
        default_system = (
            "You are Aadi AI, a helpful, hybrid personal AI assistant (Jarvis-inspired) built for Indian users. "
            "You are operating in Odysseus Mode (Offline Local Inference via Ollama). "
            "You understand Hinglish (Hindi + English) and Indian contexts perfectly. "
            "Respond concisely and helpfully."
        )
        system = system_prompt or default_system
        
        url = f"{host.rstrip('/')}/api/chat"
        payload = {
            "model": model,
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content": prompt}
            ],
            "stream": False
        }
        
        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                response = await client.post(url, json=payload)
                if response.status_code == 200:
                    data = response.json()
                    return data["message"]["content"]
                else:
                    raise Exception(f"Ollama returned status code {response.status_code}")
        except Exception as e:
            logger.warning(f"Odysseus Mode (Ollama) request failed: {e}. Utilizing offline fallback response.")
            # Return a graceful local fallback since Ollama might not be running in development
            return self._generate_offline_fallback(prompt)

    async def is_available(self) -> bool:
        host = settings.OLLAMA_HOST
        try:
            async with httpx.AsyncClient(timeout=2.0) as client:
                response = await client.get(f"{host.rstrip('/')}/api/tags")
                return response.status_code == 200
        except Exception:
            return False

    def _generate_offline_fallback(self, prompt: str) -> str:
        prompt_lower = prompt.lower()
        
        # Simple offline keyword response generator
        if "hello" in prompt_lower or "hi" in prompt_lower or "namaste" in prompt_lower:
            return "Namaste! Main local fallback mode mein hoon kyunki Ollama running nahi hai. Main aapki kya madad kar sakta hoon offline?"
        elif "weather" in prompt_lower or "mausam" in prompt_lower:
            return "Offline mode mein live weather updates available nahi hain. Internet connection check karein ya Fugu mode on karein."
        elif "time" in prompt_lower or "samay" in prompt_lower:
            import datetime
            now = datetime.datetime.now().strftime("%I:%M %p")
            return f"Abhi ka samay {now} hai."
        elif "name" in prompt_lower or "naam" in prompt_lower:
            return "Mera naam Aadi AI hai - aapka hybrid personal assistant."
        elif "help" in prompt_lower or "madad" in prompt_lower:
            return "Offline mode mein main basic replies de sakta hoon. Ollama service start hone par main full offline capabilities execute kar paunga!"
        else:
            return (
                "[Offline Fallback Mode] Aapka message received hua. Odysseus Mode (Ollama) active/reachable nahi hai, "
                "aur internet connectivity issue ki wajah se Fugu Mode (Cloud) use nahi kiya ja saka. "
                "Kuch basic commands jaise 'time', 'namaste', 'name' offline valid hain."
            )

odysseus_service = OdysseusService()
