import logging
import httpx
import json
from anthropic import AsyncAnthropic
from app.config import settings
from app.services.tools import TOOL_DEFINITIONS, tool_executor
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

# Helper to transform standard tool definitions to Anthropic format (using input_schema)
def get_anthropic_tools():
    anth_tools = []
    for tool in TOOL_DEFINITIONS:
        anth_tools.append({
            "name": tool["name"],
            "description": tool["description"],
            "input_schema": tool["parameters"]
        })
    return anth_tools

# Helper to transform standard tool definitions to Gemini format
def get_gemini_tools():
    return [
        {
            "functionDeclarations": TOOL_DEFINITIONS
        }
    ]

class FuguService:
    async def generate_response(self, prompt: str, user_id: int, db: Session, system_prompt: str = None) -> str:
        """
        Query cloud LLM (Claude or Gemini) under Fugu Mode.
        Enforces a full ReAct tool execution loop (up to 5 iterations) if the model requests tool calls.
        """
        anthropic_key = settings.ANTHROPIC_API_KEY
        gemini_key = settings.GEMINI_API_KEY

        if not anthropic_key and not gemini_key:
            raise ValueError("Neither Anthropic nor Gemini API Key is set in backend settings.")

        # Indian assistant base system prompt
        default_system = (
            "You are Aadi AI, a highly intelligent, polite personal assistant built for Indian users. "
            "You understand Hinglish (natural Hindi + English) and Indian contexts perfectly. "
            "You have access to a set of local and cloud tools to fetch weather, search Wikipedia/Google, "
            "capture screen, open apps, check CPU/RAM stats, read/draft emails, read/add calendar events, and manage memories. "
            "If a tool returns an error, explain it nicely. "
            "If a tool triggers a confirmation (such as draft_email or schedule_meeting), let the user know they need to approve it. "
            "This is Fugu Mode (Online Cloud Inference)."
        )
        system = system_prompt or default_system

        # ---------------- OPTION 1: CLAUDE 3.5 SONNET WITH TOOLS ----------------
        if anthropic_key:
            try:
                client = AsyncAnthropic(api_key=anthropic_key)
                anth_tools = get_anthropic_tools()
                
                messages = [{"role": "user", "content": prompt}]
                
                for iteration in range(5):
                    logger.info(f"Claude ReAct loop iteration {iteration}...")
                    response = await client.messages.create(
                        model="claude-3-5-sonnet-20241022",
                        max_tokens=1024,
                        system=system,
                        tools=anth_tools,
                        messages=messages
                    )
                    
                    # Check if Claude wants to use tools
                    tool_calls = [p for p in response.content if p.type == "tool_use"]
                    text_content = next((p.text for p in response.content if p.type == "text"), "")
                    
                    if not tool_calls:
                        return text_content
                        
                    # Build assistant message block including tool use requests
                    assistant_message_content = []
                    tool_responses = []
                    
                    for call in tool_calls:
                        assistant_message_content.append({
                            "type": "tool_use",
                            "id": call.id,
                            "name": call.name,
                            "input": call.input
                        })
                        
                        # Execute the tool
                        tool_result = await tool_executor.execute_tool(call.name, call.input, user_id, db)
                        tool_responses.append({
                            "type": "tool_result",
                            "tool_use_id": call.id,
                            "content": tool_result
                        })
                    
                    # Update message history
                    if text_content:
                        assistant_message_content.insert(0, {"type": "text", "text": text_content})
                        
                    messages.append({"role": "assistant", "content": assistant_message_content})
                    messages.extend([{"role": "user", "content": [tr]} for tr in tool_responses])
                    
                # If we timed out on iterations, return whatever text we have
                return text_content
                
            except Exception as e:
                logger.error(f"Claude tool agent execution failed: {e}. Falling back to Gemini.")
                if not gemini_key:
                    raise e

        # ---------------- OPTION 2: GEMINI 2.5 FLASH WITH TOOLS ----------------
        if gemini_key:
            for model in ["gemini-2.5-flash", "gemini-2.5-flash-lite"]:
                url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={gemini_key}"
                
                # Setup initial contents structure
                contents = [
                    {
                        "role": "user",
                        "parts": [{"text": prompt}]
                    }
                ]
                
                for iteration in range(5):
                    logger.info(f"Gemini {model} ReAct loop iteration {iteration}...")
                    
                    payload = {
                        "contents": contents,
                        "systemInstruction": {
                            "parts": [{"text": system}]
                        },
                        "tools": get_gemini_tools(),
                        "generationConfig": {
                            "temperature": 0.7,
                            "maxOutputTokens": 1024
                        }
                    }
                    
                    try:
                        async with httpx.AsyncClient(timeout=15.0) as client:
                            response = await client.post(url, json=payload)
                            if response.status_code != 200:
                                raise Exception(f"Gemini API returned code {response.status_code}: {response.text}")
                                
                            res_json = response.json()
                            candidates = res_json.get("candidates", [])
                            if not candidates:
                                raise Exception(f"Empty candidates in Gemini response: {res_json}")
                                
                            candidate = candidates[0]
                            content = candidate.get("content", {})
                            parts = content.get("parts", [])
                            
                            # Append assistant's response to history
                            contents.append(content)
                            
                            # Check for function calls
                            function_calls = [p.get("functionCall") for p in parts if p.get("functionCall")]
                            text_response = next((p.get("text") for p in parts if p.get("text")), "")
                            
                            if not function_calls:
                                return text_response
                                
                            # We have function calls to process
                            function_parts = []
                            for call in function_calls:
                                name = call.get("name")
                                args = call.get("args", {})
                                
                                # Execute tool
                                tool_result = await tool_executor.execute_tool(name, args, user_id, db)
                                
                                # Format as functionResponse part
                                function_parts.append({
                                    "functionResponse": {
                                        "name": name,
                                        "response": {
                                            "result": tool_result
                                        }
                                    }
                                })
                                
                            # Append function responses as next user message turn
                            contents.append({
                                "role": "function",
                                "parts": function_parts
                            })
                            
                    except Exception as ex:
                        logger.error(f"Gemini {model} tool loop failed: {ex}")
                        break
                        
            raise Exception("All Gemini model tool loops under Fugu Mode failed.")

fugu_service = FuguService()
