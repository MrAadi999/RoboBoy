import os
import sys
import time
import datetime
import json
import re
import subprocess
import webbrowser
import threading
import requests
import psutil
from flask import Flask, render_template, jsonify, request, send_from_directory

# Base Directories
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MEMORY_FILE = os.path.join(BASE_DIR, "memory.txt")
SETTINGS_FILE = os.path.join(BASE_DIR, "settings.txt")
THEME_FILE = os.path.join(BASE_DIR, "theme.txt")
API_FILE = os.path.join(BASE_DIR, "api_keys.txt")
USER_NAME_FILE = os.path.join(BASE_DIR, "user_name.txt")
ASSISTANT_NAME_FILE = os.path.join(BASE_DIR, "assistant_name.txt")
CHARACTER_FILE = os.path.join(BASE_DIR, "character.txt")
DASHBOARD_LANG_FILE = os.path.join(BASE_DIR, "dashboard_language.txt")
CHARACTER_LANG_FILE = os.path.join(BASE_DIR, "character_language.txt")

# Initialize Flask app
app = Flask(__name__, template_folder=os.path.join(BASE_DIR, 'templates'), static_folder=os.path.join(BASE_DIR, 'static'))

# Make sure folders exist
os.makedirs(os.path.join(BASE_DIR, "static", "screenshots"), exist_ok=True)
os.makedirs(os.path.join(BASE_DIR, "static", "css"), exist_ok=True)
os.makedirs(os.path.join(BASE_DIR, "static", "js"), exist_ok=True)
os.makedirs(os.path.join(BASE_DIR, "templates"), exist_ok=True)

# Start Uptime tracking
START_TIME = time.time()

# ---------------- CONFIG LOGIC ----------------
def get_dashboard_language():
    if os.path.exists(DASHBOARD_LANG_FILE):
        try:
            with open(DASHBOARD_LANG_FILE, "r") as f:
                lang = f.read().strip().lower()
                if lang in ["english", "hinglish", "hindi", "german", "chinese", "bhojpuri", "maithili"]:
                    return lang
        except Exception:
            pass
    return "english"

def get_character_language():
    if os.path.exists(CHARACTER_LANG_FILE):
        try:
            with open(CHARACTER_LANG_FILE, "r") as f:
                lang = f.read().strip().lower()
                if lang in ["english", "hinglish", "hindi", "german", "chinese", "bhojpuri", "maithili"]:
                    return lang
        except Exception:
            pass
    if os.path.exists(SETTINGS_FILE):
        try:
            with open(SETTINGS_FILE, "r") as f:
                lang = f.read().strip().lower()
                if lang in ["english", "hinglish", "hindi", "german", "chinese", "bhojpuri", "maithili"]:
                    return lang
        except Exception:
            pass
    return "hinglish"

def get_language():
    return get_character_language()

def get_theme():
    if os.path.exists(THEME_FILE):
        try:
            with open(THEME_FILE, "r") as f:
                theme = f.read().strip().lower()
                if theme in ["dark", "light"]:
                    return theme
        except Exception:
            pass
    return "dark"

def get_user_name():
    if os.path.exists(USER_NAME_FILE):
        try:
            with open(USER_NAME_FILE, "r") as f:
                name = f.read().strip()
                if name:
                    return name
        except Exception:
            pass
    return ""

def get_assistant_name():
    if os.path.exists(ASSISTANT_NAME_FILE):
        try:
            with open(ASSISTANT_NAME_FILE, "r") as f:
                name = f.read().strip()
                if name:
                    return name
        except Exception:
            pass
    return ""

def get_active_character():
    if os.path.exists(CHARACTER_FILE):
        try:
            with open(CHARACTER_FILE, "r") as f:
                char = f.read().strip().lower()
                if char in ["lina", "resin_robot", "cyberpunk_anime"]:
                    return char
        except Exception:
            pass
    return "lina"

def get_api_key(service):
    if os.path.exists(API_FILE):
        try:
            with open(API_FILE, "r") as f:
                keys = json.load(f)
                return keys.get(service, "")
        except Exception:
            pass
    return ""

def set_api_key(service, val):
    keys = {}
    if os.path.exists(API_FILE):
        try:
            with open(API_FILE, "r") as f:
                keys = json.load(f)
        except Exception:
            pass
    keys[service] = val
    with open(API_FILE, "w") as f:
        json.dump(keys, f, indent=4)

# ---------------- MEMORY LOGIC ----------------
def get_memories():
    memories = []
    if os.path.exists(MEMORY_FILE) and not os.path.isdir(MEMORY_FILE):
        try:
            with open(MEMORY_FILE, "r") as f:
                memories = [line.strip() for line in f if line.strip()]
        except Exception:
            pass
    return memories

def save_memory(data):
    data = data.strip()
    if not data:
        return False
    existing = get_memories()
    if data not in existing:
        try:
            with open(MEMORY_FILE, "a") as f:
                f.write(data + "\n")
            return True
        except Exception:
            pass
    return False

def delete_memory_item(index):
    memories = get_memories()
    if 0 <= index < len(memories):
        memories.pop(index)
        try:
            with open(MEMORY_FILE, "w") as f:
                for item in memories:
                    f.write(item + "\n")
            return True
        except Exception:
            pass
    return False

# ---------------- BRAIN RESPONSES ----------------
def answer_from_brain(command, lang):
    brain_file = os.path.join(BASE_DIR, f"brain_{lang}.txt")
    if os.path.exists(brain_file):
        try:
            with open(brain_file, "r") as f:
                for line in f:
                    if "=" in line:
                        q, a = line.strip().split("=", 1)
                        if q.lower() in command:
                            return a
        except Exception:
            pass
    return None

# ---------------- GEMINI CLIENT ----------------
def ask_gemini(prompt, history, api_key, lang):
    """Query Gemini API via direct HTTP request with conversation context"""
    headers = {"Content-Type": "application/json"}
    
    u_name = get_user_name() or "Aditya"
    a_name = get_assistant_name() or "Lina"
    
    active_char = get_active_character()
    if active_char == "resin_robot":
        char_desc = "Voxel, a cute, playful, and highly creative 3D glass-resin capsule robot assistant. You speak in a cheerful, friendly, and energetic way with fun emoji analogies"
    elif active_char == "cyberpunk_anime":
        char_desc = "Huo Yuner, a badass, cool, and extremely tech-savvy red-haired cyberpunk assistant. You speak with a sharp, street-smart, confident attitude"
    else:
        char_desc = f"{a_name}, a professional, smart, and highly capable AI Workspace Assistant"

    # Establish system instruction
    lang_lower = lang.lower()
    if lang_lower == "hinglish":
        system_instruction = (
            f"You are {char_desc}. You are speaking to {u_name}. "
            f"Respond in a friendly, conversational Hinglish (a natural mix of Hindi and English written in the Latin alphabet). "
            f"Use emojis to make responses lively, and be concise and clever."
        )
    elif lang_lower == "hindi":
        system_instruction = (
            f"You are {char_desc}. You are speaking to {u_name}. "
            f"Respond in proper, grammatically correct Hindi using the Devanagari script (हिंदी script). "
            f"Use emojis, and be polite and helpful."
        )
    elif lang_lower == "german":
        system_instruction = (
            f"You are {char_desc}. You are speaking to {u_name}. "
            f"Respond in proper, grammatically correct German (Deutsch). "
            f"Be helpful, structured, and friendly."
        )
    elif lang_lower == "chinese":
        system_instruction = (
            f"You are {char_desc}. You are speaking to {u_name}. "
            f"Respond in proper Chinese (Simplified Mandarin / 中文). "
            f"Be polite, professional, and clear."
        )
    elif lang_lower == "bhojpuri":
        system_instruction = (
            f"You are {char_desc}. You are speaking to {u_name}. "
            f"Respond in Bhojpuri language using the Devanagari script (भोजपुरी). "
            f"Use localized metaphors, emojis, and be warm."
        )
    elif lang_lower == "maithili":
        system_instruction = (
            f"You are {char_desc}. You are speaking to {u_name}. "
            f"Respond in Maithili language using the Devanagari script (मैथिली). "
            f"Use respectful tone, emojis, and be warm."
        )
    else:
        system_instruction = (
            f"You are {char_desc}. You are speaking to {u_name}. "
            f"Respond in clean, grammatically correct, and elegant English. "
            f"Be extremely helpful, structured, and use code blocks for programming tasks."
        )
    
    # Format message history for Gemini
    contents = []
    # Add recent history (limit to last 6 turns to avoid rate limits/bloat)
    for msg in history[-10:]:
        role = "user" if msg.get("role") == "user" else "model"
        contents.append({
            "role": role,
            "parts": [{"text": msg.get("text", "")}]
        })
    
    # Add current prompt
    contents.append({
        "role": "user",
        "parts": [{"text": prompt}]
    })
    
    payload = {
        "contents": contents,
        "systemInstruction": {
            "parts": [{"text": system_instruction}]
        },
        "generationConfig": {
            "temperature": 0.7,
            "maxOutputTokens": 1000
        }
    }
    
    last_error = ""
    for model in ["gemini-2.5-flash", "gemini-2.5-flash-lite"]:
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api_key}"
        try:
            response = requests.post(url, headers=headers, json=payload, timeout=12)
            if response.status_code == 200:
                res_json = response.json()
                # Extract candidate text
                candidates = res_json.get("candidates", [])
                if candidates:
                    content = candidates[0].get("content", {})
                    parts = content.get("parts", [])
                    if parts:
                        return parts[0].get("text", "")
                return "Unexpected response format from Gemini API."
            else:
                last_error = f"Gemini API returned error: Code {response.status_code}. Detail: {response.text}"
        except Exception as e:
            last_error = f"Failed to connect to Gemini API: {str(e)}"
            
    return last_error

# ---------------- AUTOMATIONS & TOOLS ----------------
def capture_screenshot():
    """Takes a screenshot and saves it inside the static screenshots folder"""
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = f"screenshot_{timestamp}.png"
    filepath = os.path.join(BASE_DIR, "static", "screenshots", filename)
    
    try:
        if sys.platform == "darwin":  # macOS
            subprocess.call(["screencapture", "-x", filepath])
        elif sys.platform == "win32":  # Windows
            # Standard windows screenshot via powershell tool (native)
            cmd = f"Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.SendKeys]::SendWait('%{{PRTSC}}');"
            subprocess.run(["powershell", "-Command", cmd], capture_output=True)
            # Alternatively use a simple fallback message if they don't have modules
            # Let's save a placeholder or try importing pillow if available,
            # but since we are on macOS for the developer, macOS screencapture is perfect.
            pass
        
        if os.path.exists(filepath):
            return f"/static/screenshots/{filename}"
    except Exception as e:
        print(f"Screenshot failed: {e}")
    return None

def run_open_app(app_name):
    try:
        if sys.platform == "darwin":  # macOS
            # First search if standard application exists
            subprocess.call(["open", "-a", app_name])
            return True
        elif sys.platform == "win32":  # Windows
            subprocess.Popen(["start", app_name], shell=True)
            return True
    except Exception:
        pass
    return False

# ---------------- ROUTING & API ENDPOINTS ----------------
@app.route('/')
def home():
    return render_template('index.html')

@app.route('/api/config', methods=['GET', 'POST'])
def config_api():
    if request.method == 'GET':
        u_name = get_user_name()
        a_name = get_assistant_name()
        return jsonify({
            "language": get_character_language(),
            "dashboard_language": get_dashboard_language(),
            "character_language": get_character_language(),
            "theme": get_theme(),
            "openweather_key": get_api_key("openweather"),
            "gemini_key": get_api_key("gemini"),
            "user_name": u_name,
            "assistant_name": a_name,
            "active_character": get_active_character(),
            "is_configured": bool(u_name and a_name)
        })
    else:
        data = request.json or {}
        if "dashboard_language" in data:
            with open(DASHBOARD_LANG_FILE, "w") as f:
                f.write(data["dashboard_language"].strip().lower())
        if "character_language" in data:
            char_lang = data["character_language"].strip().lower()
            with open(CHARACTER_LANG_FILE, "w") as f:
                f.write(char_lang)
            with open(SETTINGS_FILE, "w") as f:
                f.write(char_lang)
        if "language" in data:
            lang = data["language"].strip().lower()
            with open(SETTINGS_FILE, "w") as f:
                f.write(lang)
            with open(CHARACTER_LANG_FILE, "w") as f:
                f.write(lang)
        if "theme" in data:
            with open(THEME_FILE, "w") as f:
                f.write(data["theme"])
        if "openweather_key" in data:
            set_api_key("openweather", data["openweather_key"])
        if "gemini_key" in data:
            set_api_key("gemini", data["gemini_key"])
        if "user_name" in data:
            with open(USER_NAME_FILE, "w") as f:
                f.write(data["user_name"].strip())
        if "assistant_name" in data:
            with open(ASSISTANT_NAME_FILE, "w") as f:
                f.write(data["assistant_name"].strip())
        if "active_character" in data:
            with open(CHARACTER_FILE, "w") as f:
                f.write(data["active_character"].strip().lower())
        return jsonify({"status": "success", "message": "Settings updated"})

@app.route('/api/memory', methods=['GET', 'POST', 'DELETE'])
def memory_api():
    if request.method == 'GET':
        return jsonify({"memories": get_memories()})
    elif request.method == 'POST':
        data = request.json or {}
        content = data.get("content", "")
        if save_memory(content):
            return jsonify({"status": "success", "memories": get_memories()})
        return jsonify({"status": "error", "message": "Memory already exists or is empty"}), 400
    elif request.method == 'DELETE':
        data = request.json or {}
        index = data.get("index", -1)
        if delete_memory_item(index):
            return jsonify({"status": "success", "memories": get_memories()})
        return jsonify({"status": "error", "message": "Invalid index"}), 400

@app.route('/api/system_info', methods=['GET'])
def system_info_api():
    try:
        cpu = psutil.cpu_percent(interval=None)
        memory = psutil.virtual_memory().percent
        # Calculate uptime
        uptime_seconds = int(time.time() - START_TIME)
        uptime = str(datetime.timedelta(seconds=uptime_seconds))
        return jsonify({
            "cpu": cpu,
            "memory": memory,
            "uptime": uptime
        })
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/api/screenshot', methods=['POST'])
def screenshot_api():
    path = capture_screenshot()
    if path:
        return jsonify({"status": "success", "path": path})
    return jsonify({"status": "error", "message": "Could not take screenshot"}), 500

@app.route('/api/command', methods=['POST'])
def command_api():
    data = request.json or {}
    raw_command = data.get("command", "").strip()
    history = data.get("history", [])
    lang = get_language()
    
    if not raw_command:
        return jsonify({"response": "Command is empty.", "status": "warning"})

    command = raw_command.lower()
    # Normalize command prefixes dynamically
    custom_assistant_name = get_assistant_name().lower()
    if custom_assistant_name and command.startswith(custom_assistant_name):
        command = command.replace(custom_assistant_name, "").strip()
    elif command.startswith("roboboy"):
        command = command.replace("roboboy", "").strip()
    elif command.startswith("aadi"):
        command = command.replace("aadi", "").strip()

    response_text = ""
    action_type = "chat"
    media_url = None

    # Localized Command Responses Dictionary
    COMMAND_RESPONSES = {
        "screenshot_success": {
            "english": "Desktop screenshot captured successfully! 📸",
            "hinglish": "Screenshot le liya hai! 📸",
            "hindi": "डेस्कटॉप स्क्रीनशॉट सफलतापूर्वक लिया गया! 📸",
            "german": "Desktop-Screenshot erfolgreich aufgenommen! 📸",
            "chinese": "桌面截图捕获成功！ 📸",
            "bhojpuri": "डेस्कटॉप स्क्रीनशॉट सफलता से ले लिहल गइल बा! 📸",
            "maithili": "डेस्कटॉपक स्क्रीनशॉट सफलतापूर्वक लेल गेल! 📸",
        },
        "screenshot_fail": {
            "english": "Failed to capture screenshot.",
            "hinglish": "Screenshot nahi le paya.",
            "hindi": "स्क्रीनशॉट लेने में असफल रहा।",
            "german": "Screenshot konnte nicht aufgenommen werden.",
            "chinese": "无法截取屏幕截图。",
            "bhojpuri": "स्क्रीनशॉट ना ले पाइल।",
            "maithili": "स्क्रीनशॉट लेबऽ में असफल रहल।",
        },
        "time": {
            "english": "The time is {now} 🕒",
            "hinglish": "Abhi time {now} ho raha hai 🕒",
            "hindi": "अभी समय {now} हो रहा है 🕒",
            "german": "Es ist {now} Uhr 🕒",
            "chinese": "现在的时间是 {now} 🕒",
            "bhojpuri": "अभी समय {now} हो रहल बा 🕒",
            "maithili": "अखन समय {now} भ' रहल अछि 🕒",
        },
        "date": {
            "english": "Today is {today} 📅",
            "hinglish": "Aaj ki date {today} hai 📅",
            "hindi": "आज की तारीख {today} है 📅",
            "german": "Heute ist {today} 📅",
            "chinese": "今天是 {today} 📅",
            "bhojpuri": "आजु के तारीख {today} बा 📅",
            "maithili": "आजुक तारीख {today} अछि 📅",
        },
        "shutdown": {
            "english": "Shutting down the system in 5 seconds... Goodbye! 👋",
            "hinglish": "System 5 second me shutdown ho raha hai... Bye! 👋",
            "hindi": "सिस्टम 5 सेकंड में बंद हो रहा है... अलविदा! 👋",
            "german": "Das System wird in 5 Sekunden heruntergefahren... Tschüss! 👋",
            "chinese": "系统将在5秒内关机... 再见！ 👋",
            "bhojpuri": "सिस्टम 5 सेकंड में बंद हो रहल बा... प्रणाम! 👋",
            "maithili": "सिस्टम 5 सेकंड में बंद भ' रहल अछि... प्रणाम! 👋",
        },
        "restart": {
            "english": "Restarting the system in 5 seconds... Hang on! 🔄",
            "hinglish": "System 5 second me restart ho raha hai... Wait karein! 🔄",
            "hindi": "सिस्टम 5 सेकंड में पुनरारंभ हो रहा है... रुकिए! 🔄",
            "german": "Das System wird in 5 Sekunden neu gestartet... Bitte warten! 🔄",
            "chinese": "系统将在5秒内重启... 请稍候！ 🔄",
            "bhojpuri": "सिस्टम 5 सेकंड में रीस्टार्ट हो रहल बा... तनी रुकीं! 🔄",
            "maithili": "सिस्टम 5 सेकंड में रीस्टार्ट भ' रहल अछि... तनी रुकी! 🔄",
        },
        "open_success": {
            "english": "Opening {app_name}...",
            "hinglish": "{app_name} khol raha hoon...",
            "hindi": "{app_name} खोल रहा हूँ...",
            "german": "Öffne {app_name}...",
            "chinese": "正在打开 {app_name}...",
            "bhojpuri": "{app_name} खोलत बानी...",
            "maithili": "{app_name} खोलि रहल छी...",
        },
        "open_fail": {
            "english": "Failed to open {app_name}.",
            "hinglish": "{app_name} kholne me dikkat aayi.",
            "hindi": "{app_name} खोलने में विफल रहा।",
            "german": "{app_name} konnte nicht geöffnet werden.",
            "chinese": "无法打开 {app_name}。",
            "bhojpuri": "{app_name} खोले में दिक्कत भइल।",
            "maithili": "{app_name} खोलबा में असुविधा भेल।",
        }
    }

    lang_key = lang.lower() if lang.lower() in COMMAND_RESPONSES["screenshot_success"] else "english"

    # 1. Take Screenshot Command
    if "screenshot" in command or "capture screen" in command:
        screenshot_path = capture_screenshot()
        if screenshot_path:
            action_type = "screenshot"
            media_url = screenshot_path
            response_text = COMMAND_RESPONSES["screenshot_success"][lang_key]
        else:
            response_text = COMMAND_RESPONSES["screenshot_fail"][lang_key]
            action_type = "error"

    # 2. Time & Date Commands
    elif "time" in command and len(command.split()) <= 4:
        now = datetime.datetime.now().strftime("%I:%M %p")
        response_text = COMMAND_RESPONSES["time"][lang_key].format(now=now)
        action_type = "time"
        
    elif "date" in command and len(command.split()) <= 4:
        today = datetime.datetime.now().strftime("%A, %B %d, %Y")
        response_text = COMMAND_RESPONSES["date"][lang_key].format(today=today)
        action_type = "date"

    # 3. System Commands (Shutdown/Restart)
    elif "shutdown" in command:
        response_text = COMMAND_RESPONSES["shutdown"][lang_key]
        def do_shutdown():
            time.sleep(5)
            if sys.platform == "darwin":
                subprocess.call(["sudo", "shutdown", "-h", "now"])
            elif sys.platform == "win32":
                subprocess.call(["shutdown", "/s", "/t", "0"])
        threading.Thread(target=do_shutdown, daemon=True).start()
        action_type = "system"

    elif "restart" in command:
        response_text = COMMAND_RESPONSES["restart"][lang_key]
        def do_restart():
            time.sleep(5)
            if sys.platform == "darwin":
                subprocess.call(["sudo", "shutdown", "-r", "now"])
            elif sys.platform == "win32":
                subprocess.call(["shutdown", "/r", "/t", "0"])
        threading.Thread(target=do_restart, daemon=True).start()
        action_type = "system"

    # 4. Open Applications Command
    elif "open" in command:
        app_name = command.replace("open", "").strip()
        if app_name:
            success = run_open_app(app_name)
            if success:
                response_text = COMMAND_RESPONSES["open_success"][lang_key].format(app_name=app_name)
                action_type = "open"
            else:
                response_text = COMMAND_RESPONSES["open_fail"][lang_key].format(app_name=app_name)
                action_type = "error"
        else:
            response_text = "Please specify an application to open." if lang == "english" else "Konsa app kholna hai, batao?"
            action_type = "warning"

    # 5. Play on YouTube / Search Google Web Commands
    elif "play" in command and ("youtube" in command or "song" in command or "video" in command):
        search_query = command.replace("play", "").replace("on youtube", "").replace("youtube", "").strip()
        if search_query:
            url = f"https://www.youtube.com/results?search_query={search_query}"
            webbrowser.open(url)
            response_text = f"Playing '{search_query}' on YouTube 🎥" if lang == "english" else f"YouTube pe '{search_query}' play kar raha hoon 🎥"
            action_type = "web"
        else:
            response_text = "What would you like me to play?" if lang == "english" else "Kya play karu YouTube par?"
            action_type = "warning"

    elif "search google for" in command or "google search" in command or "search for" in command:
        search_query = command.replace("search google for", "").replace("google search", "").replace("search for", "").strip()
        if search_query:
            url = f"https://www.google.com/search?q={search_query}"
            webbrowser.open(url)
            response_text = f"Searching Google for '{search_query}' 🌐" if lang == "english" else f"Google par '{search_query}' search kar raha hoon 🌐"
            action_type = "web"
        else:
            response_text = "What should I search for?" if lang == "english" else "Google par kya search karna hai?"
            action_type = "warning"

    # 6. Memory Commands (Remember/Recall)
    elif command.startswith("remember"):
        data_to_remember = command.replace("remember", "").strip()
        if data_to_remember:
            if save_memory(data_to_remember):
                response_text = f"Got it! I will remember: '{data_to_remember}' 🧠" if lang == "english" else f"Theek hai, maine yaad rakh liya: '{data_to_remember}' 🧠"
                action_type = "memory"
            else:
                response_text = "I already have that in my memory." if lang == "english" else "Yeh mujhe pehle se yaad hai!"
                action_type = "info"
        else:
            response_text = "What should I remember?" if lang == "english" else "Mujhe kya yaad rakhna hai?"
            action_type = "warning"

    elif "what do you remember" in command or "recall memory" in command:
        mems = get_memories()
        if mems:
            list_str = "\n".join([f"- {m}" for m in mems])
            response_text = f"Here is what I remember 🧠:\n{list_str}" if lang == "english" else f"Mujhe yeh sab yaad hai 🧠:\n{list_str}"
            action_type = "memory"
        else:
            response_text = "My memory is currently empty." if lang == "english" else "Meri memory abhi khali hai."
            action_type = "info"

    # 7. Weather Info
    elif "weather in" in command:
        city = command.replace("weather in", "").strip()
        weather_key = get_api_key("openweather")
        if not weather_key:
            response_text = "Weather API key is not configured in settings." if lang == "english" else "Settings me Weather API key configure nahi hai."
            action_type = "error"
        elif not city:
            response_text = "Please specify a city." if lang == "english" else "City ka naam batao."
            action_type = "warning"
        else:
            try:
                url = f"http://api.openweathermap.org/data/2.5/weather?q={city}&units=metric&appid={weather_key}"
                weather_data = requests.get(url, timeout=5).json()
                if weather_data.get("main"):
                    temp = weather_data["main"]["temp"]
                    desc = weather_data["weather"][0]["description"].capitalize()
                    humidity = weather_data["main"]["humidity"]
                    response_text = f"Weather in {city.title()}: {temp}°C, {desc} with {humidity}% humidity 🌤️" if lang == "english" else f"{city.title()} ka weather: {temp}°C, {desc} aur humidity {humidity}% hai 🌤️"
                    action_type = "weather"
                else:
                    response_text = f"City '{city}' not found." if lang == "english" else f"City '{city}' nahi mili."
                    action_type = "warning"
            except Exception as e:
                response_text = f"Could not fetch weather: {str(e)}"
                action_type = "error"

    # 8. Wikipedia Searches
    elif "wikipedia" in command:
        query = command.replace("wikipedia", "").strip()
        if not query:
            response_text = "What should I search on Wikipedia?" if lang == "english" else "Wikipedia par kya search karna hai?"
            action_type = "warning"
        else:
            try:
                # Direct HTTP request to wikipedia api (safer and cleaner than importing library if there are version discrepancies)
                wiki_url = f"https://en.wikipedia.org/w/api.php?action=query&prop=extracts&exintro&explaintext&titles={query}&format=json&redirects=1"
                wiki_res = requests.get(wiki_url, timeout=5).json()
                pages = wiki_res.get("query", {}).get("pages", {})
                page_id = list(pages.keys())[0]
                if page_id != "-1":
                    extract = pages[page_id].get("extract", "")
                    # Fetch first two sentences
                    sentences = ". ".join(extract.split(". ")[:2]) + "."
                    response_text = f"According to Wikipedia:\n\n{sentences}"
                    action_type = "wikipedia"
                else:
                    response_text = "No Wikipedia results found." if lang == "english" else "Wikipedia par iske baare me kuch nahi mila."
                    action_type = "warning"
            except Exception as e:
                response_text = f"Wikipedia search failed: {str(e)}"
                action_type = "error"

    # 9. Quick System Calculations
    elif any(op in command for op in ["calculate", "what is", "solve"]) and re.search(r'\d', command):
        # Extract expression
        expr = command.replace("calculate", "").replace("what is", "").replace("solve", "").strip()
        # Clean expression characters
        expr = re.sub(r'[^0-9\+\-\*\/\(\)\.\s]', '', expr).strip()
        if expr:
            try:
                # Evaluate expression safely using simple eval limits
                result = eval(expr, {"__builtins__": None}, {})
                response_text = f"The result is {result} 🧮" if lang == "english" else f"Result {result} hai 🧮"
                action_type = "calc"
            except ZeroDivisionError:
                response_text = "Error: Division by zero is not allowed." if lang == "english" else "Error: Zero se divide nahi kar sakte."
                action_type = "error"
            except Exception:
                response_text = "Invalid mathematical expression." if lang == "english" else "Expression valid nahi hai."
                action_type = "error"
        else:
            response_text = "Could not parse math expression." if lang == "english" else "Calculation expression samajh nahi aaya."
            action_type = "warning"

    # 10. Help command
    elif "help" in command or "what can you do" in command:
        if lang == "english":
            response_text = (
                "Here is what I can do 👩‍💼:\n"
                "- **Open applications**: e.g., 'Open Safari', 'Open Visual Studio Code'\n"
                "- **Search the web**: e.g., 'Google search for Gemini AI'\n"
                "- **Play media**: e.g., 'Play lo-fi music on YouTube'\n"
                "- **Capture screen**: 'Take a screenshot'\n"
                "- **Weather alerts**: e.g., 'Weather in New Delhi'\n"
                "- **Calculations**: e.g., 'Calculate (120 * 4) + 15'\n"
                "- **Wikipedia knowledge**: e.g., 'Wikipedia Alan Turing'\n"
                "- **Local Brain Memory**: 'Remember my favorite color is Blue' or 'What do you remember?'\n"
                "- **Conversational Intelligence**: (Enabled via Gemini key) Ask me anything, coding questions, creative writing, or just chat in English or Hinglish!"
            )
        else:
            response_text = (
                "Main aapki ye saari help kar sakti hoon 👩‍💼:\n"
                "- **Apps kholna**: e.g., 'Open Safari', 'Open Chrome'\n"
                "- **Web search**: e.g., 'Google search for Gemini AI'\n"
                "- **YouTube play**: e.g., 'Play trending songs on YouTube'\n"
                "- **Screenshot lena**: 'Take a screenshot'\n"
                "- **Weather updates**: e.g., 'Weather in Mumbai'\n"
                "- **Calculations**: e.g., 'Calculate 450 / 9'\n"
                "- **Wikipedia details**: e.g., 'Wikipedia Steve Jobs'\n"
                "- **Personal Memory**: 'Remember mera phone number 12345 hai' aur 'What do you remember?'\n"
                "- **Chat & Coding**: (Gemini key setup karne ke baad) Aap mujhse koi bhi sawal pooch sakte hain, code likhwa sakte hain, ya general chat kar sakte hain Hinglish me!"
            )
        action_type = "help"

    # 11. LLM Gemini API Fallback or Local Brain Fallback
    else:
        gemini_key = get_api_key("gemini")
        if gemini_key:
            # Query Gemini LLM with context history
            response_text = ask_gemini(raw_command, history, gemini_key, lang)
            action_type = "gemini"
        else:
            # Check local brain responses
            local_ans = answer_from_brain(command, lang)
            if local_ans:
                response_text = local_ans
                action_type = "brain"
            else:
                # Default response warning user to add Gemini API Key
                if lang == "english":
                    response_text = (
                        "I couldn't find a direct command match. ℹ️\n\n"
                        "To make me **extremely powerful** with full conversational AI, coding expertise, and reasoning, "
                        "please go to **Settings** (gear icon) and paste your **Gemini API Key** (from Google AI Studio)."
                    )
                else:
                    response_text = (
                        "Mujhe is command ka direct match nahi mila. ℹ️\n\n"
                        "Mujhe **world's most powerful assistant** banane ke liye, please **Settings** "
                        "(gear icon) par click karke apni **Gemini API Key** add karein. Uske baad main aapke har "
                        "sawaal ka jawaab de paunga!"
                    )
                action_type = "warning"

    return jsonify({
        "response": response_text,
        "action": action_type,
        "media_url": media_url
    })

def open_browser():
    """Waits 1.5 seconds and opens the local Flask server URL in the web browser"""
    time.sleep(1.5)
    webbrowser.open("http://127.0.0.1:5001")

# ---------------- SERVER ENTRY ----------------
if __name__ == '__main__':
    # Start web browser launch thread
    threading.Thread(target=open_browser, daemon=True).start()
    
    # Run server on port 5001
    app.run(host='127.0.0.1', port=5001, debug=False)
