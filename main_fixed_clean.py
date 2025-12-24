import os
import datetime
import tkinter as tk
from tkinter import scrolledtext, ttk, messagebox, simpledialog
import threading
import speech_recognition as sr
import pyttsx3
import webbrowser
import wikipedia
import requests
import subprocess
import sys
import queue
import re
import json
from tkinter import filedialog

# ---------------- PATHS ----------------
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MEMORY_FILE = os.path.join(BASE_DIR, "memory.txt")
SETTINGS_FILE = os.path.join(BASE_DIR, "settings.txt")
THEME_FILE = os.path.join(BASE_DIR, "theme.txt")
API_FILE = os.path.join(BASE_DIR, "api_keys.txt")

# ---------------- LANGUAGE SETUP ----------------
def choose_language():
    if os.path.exists(SETTINGS_FILE):
        with open(SETTINGS_FILE, "r") as f:
            return f.read().strip()

    print("Choose Language:")
    print("01 Hinglish AI")
    print("02 English AI")
    choice = input("Enter choice: ")

    lang = "hinglish" if choice == "1" else "english"
    with open(SETTINGS_FILE, "w") as f:
        f.write(lang)
    return lang

LANGUAGE = choose_language()
BRAIN_FILE = os.path.join(BASE_DIR, f"brain_{LANGUAGE}.txt")

if not os.path.exists(BRAIN_FILE):
    open(BRAIN_FILE, "w").close()

# ---------------- THEME SYSTEM ----------------
class ThemeManager:
    def __init__(self):
        self.themes = {
            'dark': {
                'bg': '#2b2b2b',
                'fg': '#ffffff',
                'secondary_bg': '#3c3c3c',
                'accent': '#4CAF50',
                'button_bg': '#4CAF50',
                'button_fg': '#ffffff',
                'chat_bg': '#1e1e1e',
                'chat_fg': '#ffffff',
                'panel_bg': '#333333'
            },
            'light': {
                'bg': '#f0f0f0',
                'fg': '#000000',
                'secondary_bg': '#ffffff',
                'accent': '#2196F3',
                'button_bg': '#2196F3',
                'button_fg': '#ffffff',
                'chat_bg': '#ffffff',
                'chat_fg': '#000000',
                'panel_bg': '#e8e8e8'
            }
        }
        self.current_theme = self.load_theme()
    
    def load_theme(self):
        if os.path.exists(THEME_FILE):
            with open(THEME_FILE, "r") as f:
                return f.read().strip()
        return 'dark'
    
    def save_theme(self, theme):
        with open(THEME_FILE, "w") as f:
            f.write(theme)
        self.current_theme = theme
    
    def get_colors(self):
        return self.themes[self.current_theme]

theme_manager = ThemeManager()

# ---------------- API KEY MANAGEMENT ----------------
def get_api_key(service="openweather"):
    if os.path.exists(API_FILE):
        with open(API_FILE, "r") as f:
            api_keys = json.load(f)
            return api_keys.get(service, "")
    return ""

def set_api_key(service, key):
    api_keys = {}
    if os.path.exists(API_FILE):
        with open(API_FILE, "r") as f:
            api_keys = json.load(f)
    api_keys[service] = key
    with open(API_FILE, "w") as f:
        json.dump(api_keys, f)

# ---------------- SPEECH ENGINE ----------------
engine = pyttsx3.init()
speech_queue = queue.Queue()
speech_thread_running = False

def speech_worker():
    """Worker function to process speech queue"""
    global speech_thread_running
    speech_thread_running = True
    
    while speech_thread_running:
        try:
            # Get text from queue with timeout
            text = speech_queue.get(timeout=0.1)
            if text is None:  # Stop signal
                break
                
            # Update GUI from main thread
            def update_chat():
                if 'chat_area' in globals():
                    chat_area.config(state='normal')
                    chat_area.insert(tk.END, f"🤖 RoboBoy: {text}\n", "assistant")
                    chat_area.see(tk.END)
                    chat_area.config(state='disabled')
                    update_status("Response sent", "success")
            
            root.after(0, update_chat)
            
            # Speak the text
            engine.say(text)
            engine.runAndWait()
            
            # Mark task as done
            speech_queue.task_done()
            
        except queue.Empty:
            continue
        except Exception as e:
            print(f"Speech error: {e}")
            continue
    
    speech_thread_running = False

def speak(text):
    """Thread-safe speak function"""
    try:
        speech_queue.put(text)
    except Exception as e:
        print(f"Queue error: {e}")

def start_speech_thread():
    thread = threading.Thread(target=speech_worker, daemon=True)
    thread.start()

# ---------------- STATUS BAR ----------------
status_label = None
def update_status(message, status_type="info"):
    if status_label:
        colors = theme_manager.get_colors()
        status_colors = {
            'info': colors['fg'],
            'success': '#4CAF50',
            'error': '#f44336',
            'warning': '#ff9800'
        }
        status_label.config(text=message, fg=status_colors.get(status_type, colors['fg']))

# ---------------- MEMORY ----------------
def remember(data):
    existing = set()
    # Check if MEMORY_FILE exists and is not a directory
    if os.path.exists(MEMORY_FILE) and not os.path.isdir(MEMORY_FILE):
        with open(MEMORY_FILE, "r") as f:
            existing = set(line.strip() for line in f)

    if data not in existing:
        with open(MEMORY_FILE, "a") as f:
            f.write(data + "\n")
        # Update memory panel
        update_memory_panel()
        return True
    return False

def recall():
    # Check if MEMORY_FILE exists and is not a directory
    if not os.path.exists(MEMORY_FILE) or os.path.isdir(MEMORY_FILE):
        return "I don't remember anything yet." if LANGUAGE == "english" else "Abhi mujhe kuch yaad nahi hai."
    with open(MEMORY_FILE, "r") as f:
        return f.read().strip()

# ---------------- BRAIN ----------------
def answer_from_brain(command):
    try:
        with open(BRAIN_FILE, "r") as f:
            for line in f:
                if "=" in line:
                    q, a = line.strip().split("=", 1)
                    if q.lower() in command:
                        return a
    except Exception as e:
        print(f"Brain file error: {e}")
    return None

# ---------------- VOICE ----------------
def take_command():
    r = sr.Recognizer()
    update_status("Listening...", "info")
    with sr.Microphone() as source:
        r.adjust_for_ambient_noise(source)
        audio = r.listen(source, phrase_time_limit=5)
    try:
        command = r.recognize_google(audio).lower()
        update_status(f"Recognized: {command}", "success")
        return command
    except Exception as e:
        update_status("Could not understand audio", "error")
        return ""

# ---------------- HELPER FUNCTIONS ----------------
def open_app(app_name):
    try:
        if sys.platform == "darwin":  # Mac
            subprocess.call(["open", "-a", app_name])
        elif sys.platform == "win32":  # Windows
            subprocess.Popen(["start", app_name], shell=True)
        speak(f"{app_name} opened." if LANGUAGE=="english" else f"{app_name} khol diya.")
        update_status(f"Opened {app_name}", "success")
    except Exception as e:
        speak("Cannot open app." if LANGUAGE=="english" else "App nahi khol paya.")
        update_status(f"Failed to open {app_name}", "error")

def search_wikipedia(query):
    """Enhanced Wikipedia search with better error handling"""
    try:
        update_status("Searching Wikipedia...", "info")
        # Clean the query
        query = query.strip()
        if not query:
            speak("Please provide a search term." if LANGUAGE=="english" else "Search term dijiye.")
            update_status("No search term provided", "error")
            return
            
        # Try different search approaches
        summary = wikipedia.summary(query, sentences=2)
        speak(summary)
        update_status(f"Found information about {query}", "success")
    except wikipedia.exceptions.DisambiguationError as e:
        # Handle disambiguation by using the first option
        try:
            summary = wikipedia.summary(e.options[0], sentences=2)
            speak(summary)
            update_status(f"Found information about {e.options[0]}", "success")
        except:
            speak(f"Multiple results found for {query}. Please be more specific." if LANGUAGE=="english" 
                  else f"{query} ke liye multiple results mili. Specific hokar batao.")
            update_status(f"Multiple results for {query}", "warning")
    except wikipedia.exceptions.PageError:
        speak(f"No results found for {query}." if LANGUAGE=="english" 
              else f"{query} ke liye kuch nahi mila.")
        update_status(f"No results for {query}", "warning")
    except Exception as e:
        speak(f"Wikipedia search failed: {str(e)}" if LANGUAGE=="english" 
              else f"Wikipedia search fail ho gaya: {str(e)}")
        update_status("Wikipedia search failed", "error")

def get_weather(city):
    try:
        api_key = get_api_key("openweather")
        if not api_key or api_key == "YOUR_OPENWEATHERMAP_API_KEY":
            speak("Please set up your OpenWeatherMap API key in settings." if LANGUAGE=="english" 
                  else "Settings me OpenWeatherMap API key set karo.")
            update_status("API key not configured", "error")
            return
            
        update_status(f"Getting weather for {city}...", "info")
        url = f"http://api.openweathermap.org/data/2.5/weather?q={city}&units=metric&appid={api_key}"
        data = requests.get(url).json()
        if data.get("main"):
            temp = data["main"]["temp"]
            desc = data["weather"][0]["description"]
            speak(f"The temperature in {city} is {temp}°C with {desc}" if LANGUAGE=="english"
                  else f"{city} me temperature {temp}°C hai aur condition {desc} hai.")
            update_status(f"Weather: {temp}°C, {desc}", "success")
        else:
            speak("City not found." if LANGUAGE=="english" else "City nahi mili.")
            update_status("City not found", "warning")
    except Exception as e:
        speak("Weather service failed." if LANGUAGE=="english" else "Weather service fail ho gaya.")
        update_status("Weather service failed", "error")

def calculate(command):
    """Enhanced calculation function with better parsing"""
    try:
        update_status("Calculating...", "info")
        # Clean the command and extract mathematical expression
        command = command.lower().strip()
        
        # Remove various prefixes
        prefixes_to_remove = ["what is", "calculate", "calc", "solve", "compute"]
        expr = command
        for prefix in prefixes_to_remove:
            if expr.startswith(prefix):
                expr = expr[len(prefix):].strip()
                break
        
        # If nothing left, try the whole command
        if not expr:
            expr = command
            
        # Extract mathematical expression using regex
        # Look for numbers, operators, and parentheses
        math_pattern = r'[\d\.\+\-\*/\(\)\s]+'
        matches = re.findall(math_pattern, expr)
        
        if matches:
            # Use the longest match (most likely to be the full expression)
            expr = max(matches, key=len).strip()
        else:
            # If no math pattern found, try the whole cleaned expression
            expr = expr
            
        # Additional cleaning - remove any remaining words
        expr = re.sub(r'[a-zA-Z]', '', expr)
        expr = expr.strip()
        
        if not expr or not re.search(r'[\d\+\-\*/\.\(\)]', expr):
            # If still no mathematical expression, this might not be a calculation
            speak("I couldn't find a mathematical expression to calculate." if LANGUAGE=="english" 
                  else "Koi mathematical expression nahi mila calculate karne ke liye.")
            update_status("No mathematical expression found", "warning")
            return
            
        # Safety check - only allow safe mathematical operations
        allowed_chars = set('0123456789+-*/.() ')
        if not all(c in allowed_chars for c in expr):
            speak("Invalid mathematical expression." if LANGUAGE=="english" 
                  else "Invalid mathematical expression.")
            update_status("Invalid expression", "error")
            return
            
        result = eval(expr)
        speak(f"The answer is {result}" if LANGUAGE=="english" else f"Answer hai {result}")
        update_status(f"Calculation result: {result}", "success")
        
    except ZeroDivisionError:
        speak("Cannot divide by zero." if LANGUAGE=="english" else "Zero se divide nahi kar sakte.")
        update_status("Division by zero", "error")
    except SyntaxError:
        speak("Invalid mathematical expression." if LANGUAGE=="english" 
              else "Invalid mathematical expression.")
        update_status("Syntax error", "error")
    except Exception as e:
        speak(f"Cannot calculate: {str(e)}" if LANGUAGE=="english" 
              else f"Calculate nahi kar paya: {str(e)}")
        update_status("Calculation failed", "error")

def system_command(command):
    try:
        update_status("Executing system command...", "info")
        if "shutdown" in command:
            if sys.platform=="darwin":
                subprocess.call(["sudo", "shutdown", "-h", "now"])
            elif sys.platform=="win32":
                subprocess.call(["shutdown", "/s", "/t", "0"])
        elif "restart" in command:
            if sys.platform=="darwin":
                subprocess.call(["sudo", "shutdown", "-r", "now"])
            elif sys.platform=="win32":
                subprocess.call(["shutdown", "/r", "/t", "0"])
        update_status("System command executed", "success")
    except:
        speak("Cannot execute system command." if LANGUAGE=="english" 
              else "System command nahi ho paya.")
        update_status("System command failed", "error")

# ---------------- COMMAND PROCESS ----------------
def process_command(command):
    if command.startswith("roboboy"):
        command = command.replace("roboboy", "").strip()
    elif command.startswith("aadi"):  # Backward compatibility
        command = command.replace("aadi", "").strip()

    # Brain response
    brain_answer = answer_from_brain(command)
    if brain_answer:
        speak(brain_answer)
        return

    # Time and date
    if "time" in command:
        current_time = datetime.datetime.now().strftime("%H:%M")
        speak(current_time)
        update_status(f"Current time: {current_time}", "info")
    elif "date" in command:
        current_date = str(datetime.date.today())
        speak(current_date)
        update_status(f"Current date: {current_date}", "info")

    # Memory features
    elif command.startswith("remember"):
        data = command.replace("remember", "").strip()
        if data:
            if remember(data):
                speak("Yaad rakh liya 👍" if LANGUAGE=="hinglish" else "I will remember that.")
                update_status("Information remembered", "success")
            else:
                speak("I already remember that." if LANGUAGE=="english" else "Yeh cheez pehle se yaad hai.")
                update_status("Already remembered", "info")
        else:
            speak("What should I remember?" if LANGUAGE=="english" 
                  else "Kya yaad rakhe?")
            update_status("No data to remember", "warning")
    elif "what do you remember" in command:
        memory_content = recall()
        speak(memory_content)
        update_status("Memory recalled", "info")

    # Wikipedia search (enhanced)
    elif "wikipedia" in command:
        query = command.replace("wikipedia", "").strip()
        if query:
            search_wikipedia(query)
        else:
            speak("What should I search on Wikipedia?" if LANGUAGE=="english" 
                  else "Wikipedia pe kya search karu?")
            update_status("No search query", "warning")
    
    # Weather
    elif "weather in" in command:
        city = command.replace("weather in", "").strip()
        if city:
            get_weather(city)
        else:
            speak("Which city's weather do you want?" if LANGUAGE=="english" 
                  else "Kaun se shahar ka weather chahiye?")
            update_status("No city specified", "warning")

    # Calculation (enhanced)
    elif any(phrase in command for phrase in ["what is", "calculate", "calc", "solve", "compute"]):
        calculate(command)
    
    # Application opening
    elif "open" in command:
        app_name = command.replace("open", "").strip()
        if app_name:
            open_app(app_name)
        else:
            speak("Which application should I open?" if LANGUAGE=="english" 
                  else "Kaun sa app kholu?")
            update_status("No app specified", "warning")

    # System commands
    elif "shutdown" in command or "restart" in command:
        system_command(command)

    # Exit
    elif command == "exit":
        speak("Bye Aditya 👋" if LANGUAGE=="hinglish" else "Goodbye Aditya 👋")
        root.destroy()

    # Help command
    elif "help" in command or "what can you do" in command:
        help_text = "I can help with calculations, Wikipedia searches, weather updates, opening apps, remembering things, and more!" if LANGUAGE=="english" else "Main calculations, Wikipedia search, weather, apps kholna, yaad rakhna aur bhi bohot kuch kar sakta hun!"
        speak(help_text)
        update_status("Help provided", "info")

    else:
        # Enhanced fallback response
        fallback_responses = [
            "Mujhe samajh nahi aaya 😐" if LANGUAGE == "hinglish" else "I didn't understand.",
            "Try saying 'help' for available commands." if LANGUAGE == "english" else "Available commands ke liye 'help' bolo.",
            "I can calculate, search Wikipedia, check weather, and more!" if LANGUAGE == "english" else "Main calculate kar sakta hun, Wikipedia search kar sakta hun, weather check kar sakta hun, aur bhi bohot!"
        ]
        import random
        response = random.choice(fallback_responses)
        speak(response)
        update_status("Unknown command", "warning")

# ---------------- GUI COMPONENTS ----------------
chat_area = None
input_box = None
memory_panel = None
command_buttons = {}

def apply_theme():
    """Apply current theme to all widgets"""
    colors = theme_manager.get_colors()
    
    # Configure root window
    root.configure(bg=colors['bg'])
    
    # Configure all frames and widgets
    for widget in root.winfo_children():
        if hasattr(widget, 'configure'):
            try:
                widget.configure(bg=colors['bg'], fg=colors['fg'])
            except:
                pass
    
    # Update text widget colors
    if chat_area:
        chat_area.configure(
            bg=colors['chat_bg'], 
            fg=colors['chat_fg'],
            insertbackground=colors['fg']
        )
    
    # Update button colors
    for btn in command_buttons.values():
        if btn:
            btn.configure(
                bg=colors['button_bg'],
                fg=colors['button_fg'],
                activebackground=colors['accent']
            )

def update_memory_panel():
    """Update the memory panel with current memories"""
    if memory_panel:
        memory_panel.delete(1.0, tk.END)
        # Check if MEMORY_FILE exists and is not a directory
        if os.path.exists(MEMORY_FILE) and not os.path.isdir(MEMORY_FILE):
            with open(MEMORY_FILE, "r") as f:
                memories = f.readlines()
                if memories:
                    for i, memory in enumerate(memories, 1):
                        memory_panel.insert(tk.END, f"{i}. {memory.strip()}\n")
                else:
                    memory_panel.insert(tk.END, "No memories yet." if LANGUAGE=="english" else "Abhi koi yaad nahi hai.")
        else:
            memory_panel.insert(tk.END, "No memories yet." if LANGUAGE=="english" else "Abhi koi yaad nahi hai.")

def create_modern_button(parent, text, command, tooltip=None, icon=None):
    """Create a modern styled button"""
    btn = tk.Button(
        parent, 
        text=text, 
        command=command,
        font=("Arial", 10, "bold"),
        relief="flat",
        padx=15,
        pady=8
    )
    
    if tooltip:
        # Create tooltip (simple implementation)
        def on_enter(e):
            tooltip_label = tk.Label(parent, text=tooltip, bg='black', fg='white', 
                                   font=("Arial", 8), relief="solid", borderwidth=1)
            tooltip_label.place(x=e.x_root - parent.winfo_rootx(), y=e.y_root - parent.winfo_rooty() - 25)
            btn.tooltip = tooltip_label
        
        def on_leave(e):
            if hasattr(btn, 'tooltip') and btn.tooltip:
                btn.tooltip.destroy()
        
        btn.bind("<Enter>", on_enter)
        btn.bind("<Leave>", on_leave)
    
    return btn

def send_text():
    user_input = input_box.get()
    if not user_input.strip():
        return
    
    input_box.delete(0, tk.END)
    chat_area.config(state='normal')
    chat_area.insert(tk.END, f"👤 You: {user_input}\n", "user")
    chat_area.see(tk.END)
    chat_area.config(state='disabled')
    update_status("Processing command...", "info")
    threading.Thread(target=process_command, args=(user_input.lower(),)).start()

def voice_input():
    threading.Thread(target=lambda: process_command(take_command())).start()

def create_command_buttons(panel):
    """Create quick access command buttons"""
    global command_buttons
    
    # Command buttons data
    commands = [
        ("🕒 Time", "roboboy time"),
        ("📅 Date", "roboboy date"),
        ("🧠 Remember", "roboboy remember"),
        ("💭 Recall", "roboboy what do you remember"),
        ("🌐 Wikipedia", "roboboy wikipedia"),
        ("🌤️ Weather", "roboboy weather in"),
        ("🧮 Calculate", "roboboy calculate"),
        ("📖 Help", "roboboy help"),
        ("🔧 Open App", "roboboy open"),
        ("❌ Exit", "roboboy exit")
    ]
    
    for i, (text, command) in enumerate(commands):
        btn = create_modern_button(
            panel, 
            text, 
            lambda cmd=command: send_command(cmd),
            tooltip=f"Execute: {command}" if LANGUAGE=="english" else f"Execute karo: {command}"
        )
        btn.pack(fill=tk.X, pady=2, padx=5)
        command_buttons[text] = btn

def send_command(command):
    """Send a predefined command"""
    input_box.delete(0, tk.END)
    input_box.insert(0, command)
    send_text()

def open_settings():
    """Open settings dialog"""
    settings_window = tk.Toplevel(root)
    settings_window.title("Settings")
    settings_window.geometry("500x400")
    settings_window.configure(bg=theme_manager.get_colors()['bg'])
    
    # Language selection
    lang_frame = tk.LabelFrame(settings_window, text="Language", font=("Arial", 12, "bold"))
    lang_frame.pack(fill=tk.X, padx=20, pady=10)
    
    current_lang = tk.StringVar(value=LANGUAGE)
    tk.Radiobutton(lang_frame, text="Hinglish", variable=current_lang, value="hinglish").pack(anchor=tk.W)
    tk.Radiobutton(lang_frame, text="English", variable=current_lang, value="english").pack(anchor=tk.W)
    
    # Theme selection
    theme_frame = tk.LabelFrame(settings_window, text="Theme", font=("Arial", 12, "bold"))
    theme_frame.pack(fill=tk.X, padx=20, pady=10)
    
    current_theme = tk.StringVar(value=theme_manager.current_theme)
    tk.Radiobutton(theme_frame, text="Dark", variable=current_theme, value="dark").pack(anchor=tk.W)
    tk.Radiobutton(theme_frame, text="Light", variable=current_theme, value="light").pack(anchor=tk.W)
    
    # API Keys
    api_frame = tk.LabelFrame(settings_window, text="API Keys", font=("Arial", 12, "bold"))
    api_frame.pack(fill=tk.X, padx=20, pady=10)
    
    tk.Label(api_frame, text="OpenWeatherMap API Key:").pack(anchor=tk.W)
    api_entry = tk.Entry(api_frame, width=50)
    api_entry.insert(0, get_api_key("openweather"))
    api_entry.pack(fill=tk.X, pady=5)
    
    def save_settings():
        # Save language
        with open(SETTINGS_FILE, "w") as f:
            f.write(current_lang.get())
        
        # Save theme
        theme_manager.save_theme(current_theme.get())
        
        # Save API key
        set_api_key("openweather", api_entry.get())
        
        # Apply theme
        apply_theme()
        
        messagebox.showinfo("Settings", "Settings saved successfully!")
        settings_window.destroy()
    
    tk.Button(settings_window, text="Save", command=save_settings, 
              font=("Arial", 10, "bold")).pack(pady=20)

def create_menu():
    """Create the menu bar"""
    menubar = tk.Menu(root)
    root.config(menu=menubar)
    
    # File menu
    file_menu = tk.Menu(menubar, tearoff=0)
    menubar.add_cascade(label="File", menu=file_menu)
    file_menu.add_command(label="Settings", command=open_settings)
    file_menu.add_separator()
    file_menu.add_command(label="Exit", command=root.destroy)
    
    # Help menu
    help_menu = tk.Menu(menubar, tearoff=0)
    menubar.add_cascade(label="Help", menu=help_menu)
    help_menu.add_command(label="Commands", command=lambda: send_command("roboboy help"))
    help_menu.add_command(label="About", command=lambda: messagebox.showinfo("About", 
        "RoboBoy Voice Assistant\nVersion 2.0\nMade with ❤️ by Aditya Kumar"))

# ---------------- MAIN GUI INITIALIZATION ----------------
def initialize_gui():
    global root, chat_area, input_box, memory_panel, status_label
    
    # Create main window
    root = tk.Tk()
    root.title("🤖 RoboBoy - Advanced Voice Assistant")
    root.geometry("1200x800")
    root.configure(bg=theme_manager.get_colors()['bg'])
    
    # Create menu
    create_menu()
    
    # Create main container
    main_container = tk.Frame(root, bg=theme_manager.get_colors()['bg'])
    main_container.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)
    
    # Left panel - Chat area
    left_panel = tk.Frame(main_container, bg=theme_manager.get_colors()['bg'])
    left_panel.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=(0, 5))
    
    # Chat area
    chat_frame = tk.LabelFrame(left_panel, text="Chat", font=("Arial", 12, "bold"))
    chat_frame.pack(fill=tk.BOTH, expand=True, pady=(0, 10))
    
    # Configure text tags for styling
    chat_area = scrolledtext.ScrolledText(chat_frame, state='disabled', wrap=tk.WORD)
    chat_area.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)
    
    # Configure text tags
    colors = theme_manager.get_colors()
    chat_area.tag_configure("user", foreground="#4CAF50", font=("Arial", 10, "bold"))
    chat_area.tag_configure("assistant", foreground="#2196F3", font=("Arial", 10, "bold"))
    
    # Input area
    input_frame = tk.Frame(left_panel, bg=theme_manager.get_colors()['bg'])
    input_frame.pack(fill=tk.X, pady=(0, 10))
    
    input_box = tk.Entry(input_frame, font=("Arial", 12), relief="flat", bd=5)
    input_box.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(0, 5))
    input_box.bind('<Return>', lambda e: send_text())
    
    # Input buttons
    input_buttons = tk.Frame(input_frame, bg=theme_manager.get_colors()['bg'])
    input_buttons.pack(side=tk.RIGHT)
    
    send_btn = create_modern_button(input_buttons, "Send", send_text, "Send message")
    send_btn.pack(side=tk.LEFT, padx=2)
    
    voice_btn = create_modern_button(input_buttons, "🎤 Voice", voice_input, "Voice input")
    voice_btn.pack(side=tk.LEFT, padx=2)
    
    # Right panel - Controls
    right_panel = tk.Frame(main_container, bg=theme_manager.get_colors()['bg'], width=300)
    right_panel.pack(side=tk.RIGHT, fill=tk.Y, padx=(5, 0))
    right_panel.pack_propagate(False)
    
    # Quick commands panel
    commands_frame = tk.LabelFrame(right_panel, text="Quick Commands", font=("Arial", 12, "bold"))
    commands_frame.pack(fill=tk.X, pady=(0, 10))
    
    create_command_buttons(commands_frame)
    
    # Memory panel
    memory_frame = tk.LabelFrame(right_panel, text="Memory", font=("Arial", 12, "bold"))
    memory_frame.pack(fill=tk.BOTH, expand=True, pady=(0, 10))
    
    memory_panel = tk.Text(memory_frame, height=8, wrap=tk.WORD, relief="flat", bd=5)
    memory_panel.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)
    
    # Status bar
    status_frame = tk.Frame(root, relief=tk.SUNKEN, bd=1)
    status_frame.pack(side=tk.BOTTOM, fill=tk.X)
    
    status_label = tk.Label(status_frame, text="Ready", anchor=tk.W)
    status_label.pack(side=tk.LEFT, padx=5)
    
    # Update memory panel
    update_memory_panel()
    
    # Apply theme
    apply_theme()
    
    return root

# ---------------- MAIN EXECUTION ----------------
if __name__ == "__main__":
    # Initialize GUI
    root = initialize_gui()
    
    # Start speech thread
    start_speech_thread()
    
    # Welcome message
    welcome_msg = "Hello Aditya 👋 Main tumhara RoboBoy hoon 🤖" if LANGUAGE=="hinglish" else "Hello Aditya 👋 I am RoboBoy 🤖"
    chat_area.config(state='normal')
    chat_area.insert(tk.END, f"🤖 RoboBoy: {welcome_msg}\n", "assistant")
    chat_area.config(state='disabled')
    speak(welcome_msg)
    update_status("RoboBoy is ready!", "success")
    
    # Run main loop
    root.mainloop()
