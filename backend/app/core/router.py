import socket
import logging
import time
from sqlalchemy.orm import Session
from app.services.fugu import fugu_service
from app.services.odysseus import odysseus_service
from app.config import settings

logger = logging.getLogger(__name__)

def check_internet(host="8.8.8.8", port=53, timeout=1.0) -> bool:
    """Quick socket connection to a public DNS server to check internet."""
    try:
        socket.setdefaulttimeout(timeout)
        socket.socket(socket.AF_INET, socket.SOCK_STREAM).connect((host, port))
        return True
    except socket.error as ex:
        logger.warning(f"Internet connection check failed: {ex}")
        return False

def check_online_api() -> bool:
    """Verify if any online LLM API is configured and reachable."""
    if not settings.ANTHROPIC_API_KEY and not settings.GEMINI_API_KEY:
        return False
    # Standard check_internet will verify general connectivity
    return check_internet()

def is_query_complex(query: str) -> bool:
    """
    Heuristics to classify query complexity:
    - Long queries (> 100 characters) are complex.
    - Coding, logic, reasoning keywords trigger Fugu.
    - Common system/casual prompts trigger Odysseus.
    """
    query_lower = query.lower().strip()
    
    # Very short queries are low complexity
    if len(query_lower) < 25:
        return False
        
    # Local assistant keywords/commands
    local_keywords = ["time", "samay", "open", "kholo", "volume", "brightness", "system", "theme", "play"]
    if any(kw in query_lower for kw in local_keywords):
        return False

    # Complex keywords that demand high reasoning (Fugu)
    complex_keywords = [
        "explain", "summarize", "write code", "python", "javascript", "program", "analyze",
        "calculate", "math", "why", "how to", "design", "planning", "research", "diff",
        "history of", "describe", "compare"
    ]
    if any(kw in query_lower for kw in complex_keywords):
        return True
        
    # Default to Fugu for general reasoning queries if they are moderate length
    if len(query_lower) > 60:
        return True
        
    return False

class SmartRouter:
    async def route_request(self, message: str, user_id: int, db: Session, mode_override: str = "auto") -> tuple[str, str, bool]:
        """
        Routes the request.
        Returns a tuple: (response_text, mode_used, is_fallback)
        """
        mode_override = mode_override.lower()
        
        # 1. Handle explicit overrides
        if mode_override == "fugu":
            try:
                response = await fugu_service.generate_response(message, user_id, db)
                return response, "fugu", False
            except Exception as e:
                logger.error(f"Forced Fugu mode failed: {e}. Falling back to Odysseus.")
                response = await odysseus_service.generate_response(message)
                return response, "odysseus", True

        elif mode_override == "odysseus":
            response = await odysseus_service.generate_response(message)
            return response, "odysseus", False

        # 2. Smart routing logic (auto mode)
        has_internet = check_online_api()
        
        if not has_internet:
            logger.info("No internet or Online API Keys not set. Routing to Odysseus Mode.")
            response = await odysseus_service.generate_response(message)
            return response, "odysseus", True

        # Internet is available. Check query complexity.
        if is_query_complex(message):
            logger.info("Query classified as COMPLEX. Routing to Fugu Mode.")
            try:
                response = await fugu_service.generate_response(message, user_id, db)
                return response, "fugu", False
            except Exception as e:
                logger.error(f"Fugu Mode failed during auto-routing: {e}. Falling back to Odysseus.")
                response = await odysseus_service.generate_response(message)
                return response, "odysseus", True
        else:
            logger.info("Query classified as SIMPLE. Routing to Odysseus Mode.")
            response = await odysseus_service.generate_response(message)
            return response, "odysseus", False

smart_router = SmartRouter()
