import os
import base64
import hashlib
import json
import logging
import httpx
from datetime import datetime, timedelta
from sqlalchemy.orm import Session
from cryptography.fernet import Fernet
from app.config import settings
from app.database import UserMemory, ChatMessage, UserPreferences

logger = logging.getLogger(__name__)

# Derive Fernet encryption key from JWT Secret
try:
    key_material = hashlib.sha256(settings.JWT_SECRET.encode()).digest()
    fernet_key = base64.urlsafe_b64encode(key_material)
    cipher = Fernet(fernet_key)
except Exception as e:
    logger.error(f"Failed to initialize memory encryption: {e}")
    cipher = None

def encrypt_fact(fact: str) -> str:
    """Encrypt fact string using Fernet, returns url-safe base64 string."""
    if not cipher:
        return fact
    return cipher.encrypt(fact.encode()).decode()

def decrypt_fact(encrypted_fact: str) -> str:
    """Decrypt Fernet encrypted fact, fall back to raw if decryption fails."""
    if not cipher:
        return encrypted_fact
    try:
        return cipher.decrypt(encrypted_fact.encode()).decode()
    except Exception:
        # If it was stored unencrypted or key changed, return as is
        return encrypted_fact

async def get_embedding(text: str) -> list[float] | None:
    """
    Generate text embeddings:
    1. Try Gemini API online (text-embedding-004) if internet is available.
    2. Try local Ollama /api/embeddings offline if Ollama is available.
    3. Fallback to None (which triggers keyword matching fallback).
    """
    # 1. Try Gemini Embeddings if configured
    # We retrieve gemini_key from environment or dynamic config
    gemini_key = getattr(settings, "GEMINI_API_KEY", "") or os.getenv("GEMINI_API_KEY", "")
    if gemini_key:
        for model in ["gemini-embedding-2", "gemini-embedding-001"]:
            url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:embedContent?key={gemini_key}"
            payload = {
                "model": f"models/{model}",
                "content": {
                    "parts": [{"text": text}]
                }
            }
            try:
                async with httpx.AsyncClient(timeout=5.0) as client:
                    res = await client.post(url, json=payload)
                    if res.status_code == 200:
                        data = res.json()
                        embedding = data.get("embedding", {}).get("values")
                        if embedding:
                            return embedding
            except Exception as e:
                logger.warning(f"Failed to fetch Gemini embedding {model}: {e}")

    # 2. Try Ollama Embeddings
    try:
        ollama_url = f"{settings.OLLAMA_HOST.rstrip('/')}/api/embeddings"
        payload = {
            "model": settings.OLLAMA_MODEL,
            "prompt": text
        }
        async with httpx.AsyncClient(timeout=4.0) as client:
            res = await client.post(ollama_url, json=payload)
            if res.status_code == 200:
                data = res.json()
                embedding = data.get("embedding")
                if embedding:
                    return embedding
    except Exception as e:
        logger.warning(f"Failed to fetch Ollama embedding: {e}")

    # 3. Fallback to Jaccard Term Overlap (returns None vector)
    return None

def compute_similarity(vec1: list[float] | None, vec2: list[float] | None, text1: str, text2: str) -> float:
    """
    Calculate similarity between two text items:
    - If vector embeddings exist, calculates Cosine Similarity.
    - Otherwise, falls back to a normalized Jaccard Token Overlap.
    """
    if vec1 is not None and vec2 is not None:
        try:
            dot_product = sum(a * b for a, b in zip(vec1, vec2))
            norm_a = sum(a * a for a in vec1) ** 0.5
            norm_b = sum(b * b for b in vec2) ** 0.5
            if norm_a > 0 and norm_b > 0:
                return dot_product / (norm_a * norm_b)
        except Exception as e:
            logger.error(f"Error computing cosine similarity: {e}")
            
    # Fallback to Jaccard Overlap
    words1 = set(text1.lower().split())
    words2 = set(text2.lower().split())
    if not words1 or not words2:
        return 0.0
    intersection = words1.intersection(words2)
    union = words1.union(words2)
    return len(intersection) / len(union)

class VectorMemoryService:
    def __init__(self):
        self._cache = {}

    async def _ensure_cache(self, user_id: int, db: Session):
        """Pre-populate the memory cache for the user if it doesn't exist."""
        if user_id not in self._cache:
            memories = db.query(UserMemory).filter(UserMemory.user_id == user_id).all()
            user_mems = []
            for m in memories:
                decrypted = decrypt_fact(m.fact)
                try:
                    m_vec = json.loads(m.embedding) if m.embedding else None
                except Exception:
                    m_vec = None
                user_mems.append({
                    "id": m.id,
                    "fact": decrypted,
                    "vec": m_vec
                })
            self._cache[user_id] = user_mems
            logger.info(f"Loaded {len(user_mems)} memories into in-memory cache for user {user_id}")

    async def resolve_contradictions(self, user_id: int, new_fact: str, db: Session):
        """Use the LLM to identify and delete memories that contradict the new fact."""
        await self._ensure_cache(user_id, db)
        existing = self._cache[user_id]
        if not existing:
            return

        # Prepare facts list for LLM prompt
        facts_list = "\n".join([f"{idx}: {item['fact']}" for idx, item in enumerate(existing)])
        
        prompt = (
            f"You are the memory profile manager for Aadi AI. Aditya is adding a new fact about himself.\n"
            f"New Fact: \"{new_fact}\"\n\n"
            f"Here are the existing facts we remember about Aditya:\n"
            f"{facts_list}\n\n"
            f"Does the new fact directly contradict, update, or make any of the existing facts obsolete?\n"
            f"If yes, respond ONLY with a comma-separated list of the indices of the contradicted/obsolete facts (e.g. \"1, 3\").\n"
            f"If there are no contradictions or updates needed, respond with \"NO CONTRADICTION\".\n"
            f"Do not write any explanation, introduction, or markdown."
        )

        response_text = ""
        from app.services.fugu import fugu_service
        from app.services.odysseus import odysseus_service
        try:
            response_text = await fugu_service.generate_response(prompt, user_id, db)
        except Exception:
            try:
                response_text = await odysseus_service.generate_response(prompt)
            except Exception as ex:
                logger.error(f"Failed to query LLM for conflict resolution: {ex}")
                return

        response_text = response_text.strip().upper()
        if "NO CONTRADICTION" in response_text or not response_text:
            return

        # Parse indices
        try:
            indices = [int(idx.strip()) for idx in response_text.split(",") if idx.strip().isdigit()]
            to_delete_ids = []
            for idx in indices:
                if 0 <= idx < len(existing):
                    item = existing[idx]
                    to_delete_ids.append(item["id"])
                    logger.info(f"Flagged contradicting memory for deletion: '{item['fact']}'")
            
            if to_delete_ids:
                # Delete from SQLite database
                db.query(UserMemory).filter(UserMemory.id.in_(to_delete_ids)).delete(synchronize_session='fetch')
                db.commit()
                # Update in-memory cache
                self._cache[user_id] = [item for item in existing if item["id"] not in to_delete_ids]
                logger.info(f"Deleted {len(to_delete_ids)} contradicting memories.")
        except Exception as e:
            logger.error(f"Error resolving contradiction index list: {e}")

    async def save_user_memory(self, user_id: int, fact: str, db: Session) -> UserMemory:
        """Resolve contradictions, calculate embedding, save to SQLite, and update cache."""
        # 1. Resolve contradictions before saving
        await self.resolve_contradictions(user_id, fact, db)
        
        # 2. Encrypt and get embedding
        encrypted = encrypt_fact(fact)
        embedding_vector = await get_embedding(fact)
        embedding_str = json.dumps(embedding_vector) if embedding_vector else None

        new_mem = UserMemory(
            user_id=user_id,
            fact=encrypted,
            embedding=embedding_str
        )
        db.add(new_mem)
        db.commit()
        db.refresh(new_mem)

        # 3. Update cache
        await self._ensure_cache(user_id, db)
        self._cache[user_id].append({
            "id": new_mem.id,
            "fact": fact,
            "vec": embedding_vector
        })

        return new_mem

    async def get_relevant_context(self, user_id: int, query: str, db: Session, limit: int = 5) -> str:
        """
        Embed query, score user memories from cache, and construct a context block.
        """
        await self._ensure_cache(user_id, db)
        memories = self._cache[user_id]
        if not memories:
            return ""

        query_vec = await get_embedding(query)
        scored_memories = []

        for m in memories:
            score = compute_similarity(query_vec, m["vec"], query, m["fact"])
            scored_memories.append((score, m["fact"]))

        # Sort descending by similarity score
        scored_memories.sort(key=lambda x: x[0], reverse=True)
        top_hits = [text for score, text in scored_memories[:limit] if score > 0.15]

        if not top_hits:
            return ""

        context_str = "Relevant context from user profile & preferences:\n"
        for hit in top_hits:
            context_str += f"- {hit}\n"
        return context_str

    async def run_nightly_summarization(self, user_id: int, db: Session):
        """
        Nightly Memory Summarization Job:
        1. Fetch all chat logs of the last 24 hours.
        2. Feed logs to active LLM to extract key facts/preferences.
        3. Save new extracted facts back to user memories.
        """
        yesterday = datetime.utcnow() - timedelta(days=1)
        messages = db.query(ChatMessage).filter(
            ChatMessage.user_id == user_id,
            ChatMessage.timestamp >= yesterday
        ).order_by(ChatMessage.timestamp.asc()).all()

        if len(messages) < 4:
            logger.info("Not enough messages in last 24 hours to summarize.")
            return

        # Format conversation context
        history_text = ""
        for msg in messages:
            history_text += f"{msg.role.capitalize()}: {msg.content}\n"

        summary_prompt = (
            "Review this conversation history between Aditya and Aadi AI. "
            "Identify any new permanent facts about Aditya (e.g. food preferences, job details, schedule, hobbies, location) "
            "or changes in how he wants to interact. "
            "Output only a clean list of facts as plain bullet points, prefixing each with '* '. "
            "Do not include general small talk or temporary facts. If nothing permanent was learned, output nothing."
            f"\n\nConversation:\n{history_text}"
        )

        response_text = ""
        from app.services.fugu import fugu_service
        from app.services.odysseus import odysseus_service
        try:
            response_text = await fugu_service.generate_response(summary_prompt, user_id, db)
        except Exception:
            try:
                response_text = await odysseus_service.generate_response(summary_prompt)
            except Exception as ex:
                logger.error(f"Memory summarizer failed to query LLM: {ex}")
                return

        if not response_text.strip() or "no new facts" in response_text.lower():
            logger.info("No new memories found in nightly logs.")
            return

        # Parse bullet points
        lines = response_text.split("\n")
        new_facts = []
        for line in lines:
            line = line.strip()
            if line.startswith("*") or line.startswith("-"):
                fact = line.lstrip("* -").strip()
                if len(fact) > 5:
                    new_facts.append(fact)

        logger.info(f"Extracted {len(new_facts)} candidate memories. Checking duplicates...")

        # Add new facts if they aren't duplicate
        await self._ensure_cache(user_id, db)
        for fact in new_facts:
            is_duplicate = False
            fact_vec = await get_embedding(fact)

            for em in self._cache[user_id]:
                sim = compute_similarity(fact_vec, em["vec"], fact, em["fact"])
                if sim > 0.75:
                    is_duplicate = True
                    break

            if not is_duplicate:
                await self.save_user_memory(user_id, fact, db)
                logger.info(f"Memory summarized & saved: '{fact}'")

    def invalidate_cache(self, user_id: int):
        """Public helper to clear/invalidate the user's cache when deleted outside this service."""
        if user_id in self._cache:
            del self._cache[user_id]
            logger.info(f"Invalidated memory cache for user {user_id}")

memory_vector_service = VectorMemoryService()
