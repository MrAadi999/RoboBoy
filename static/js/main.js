// ==========================================
// STATE MANAGEMENT
// ==========================================
let currentLanguage = 'hinglish';
let dashboardLanguage = 'english';
let characterLanguage = 'hinglish';
// Default to dark theme as base
let currentTheme = 'dark';
let ttsEnabled = true;
let chatHistory = []; // Tracks [{role: 'user'|'model', text: '...'}]
let speechRecognition = null;
let isListening = false;
let currentUserName = 'User';
let currentAssistantName = 'Lina';
let activeCharacter = 'lina';
let setupLanguage = 'hinglish';

// Voice Presets Configuration
const voicePresets = {
    'cute_girl': {
        name: 'Cute Girl',
        pitch: 1.45,
        rate: 1.05,
        gender: 'female',
        emoji: '👧🏻'
    },
    'hot_boy': {
        name: 'Hot Boy',
        pitch: 0.90,
        rate: 0.95,
        gender: 'male',
        emoji: '🙋‍♂️'
    },
    'gents': {
        name: 'Gentleman',
        pitch: 1.0,
        rate: 0.95,
        gender: 'male',
        emoji: '👨🏻'
    },
    'woman': {
        name: 'Woman',
        pitch: 1.1,
        rate: 1.0,
        gender: 'female',
        emoji: '👩'
    },
    'men_robot': {
        name: 'Men Robot',
        pitch: 0.6,
        rate: 0.9,
        gender: 'male',
        emoji: '🤖‍♂️'
    },
    'girl_child': {
        name: 'Girl Child',
        pitch: 1.7,
        rate: 1.1,
        gender: 'female',
        emoji: '👧'
    },
    'boys_child': {
        name: 'Boys Child',
        pitch: 1.6,
        rate: 1.1,
        gender: 'male',
        emoji: '👦'
    },
    'women_robot': {
        name: 'Women Robot',
        pitch: 0.65,
        rate: 0.9,
        gender: 'female',
        emoji: '🤖‍♀️'
    },
    'old_man': {
        name: 'Old Man',
        pitch: 0.75,
        rate: 0.8,
        gender: 'male',
        emoji: '👴'
    },
    'old_woman': {
        name: 'Old Woman',
        pitch: 0.85,
        rate: 0.8,
        gender: 'female',
        emoji: '👵'
    }
};

let activeVoicePreset = localStorage.getItem('activeVoicePreset') || 'cute_girl';

// Badge metrics
let codeCount = 0;
let conversationCount = 1;

// Web Speech Synthesis
const synth = window.speechSynthesis;

// ==========================================
// DOM INITIALIZATION
// ==========================================
document.addEventListener('DOMContentLoaded', () => {
    loadConfiguration();
    setupEventListeners();
    setupSpeechRecognition();
    initVoicePresets();
    
    if (synth && synth.onvoiceschanged !== undefined) {
        synth.onvoiceschanged = () => {
            initVoicePresets();
        };
    }
    
    // Start metric updates loop
    updateMetrics();
    setInterval(updateMetrics, 3000);
    
    // Initialize real-time dashboard telemetry graph (Pin 2 style)
    if (document.getElementById('activityChart')) {
        setInterval(updateTelemetryChart, 1500);
    }
    
    // Hacker simulator additions:
    initWindowManager();
    initMatrixRain();
    initSimulatedWidgets();
    setInterval(updateClockTray, 1000);
});

// ==========================================
// SET UP EVENT HANDLERS
// ==========================================
function setupEventListeners() {
    // Theme switches
    const themeButtons = document.querySelectorAll('#themeToggle button');
    themeButtons.forEach(btn => {
        btn.addEventListener('click', () => {
            const theme = btn.getAttribute('data-theme');
            setTheme(theme);
            themeButtons.forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
        });
    });

    // No static buttons for language engine anymore, handled by dropdown select

    // Vocal response checkbox
    const ttsCheckbox = document.getElementById('ttsEnabled');
    ttsCheckbox.addEventListener('change', (e) => {
        ttsEnabled = e.target.checked;
    });

    // Input Enter listener
    const userInput = document.getElementById('userInput');
    userInput.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') {
            submitMessage();
        }
    });

    // Voice trigger button
    const voiceTrigger = document.getElementById('voiceTriggerBtn');
    voiceTrigger.addEventListener('click', toggleVoiceInput);
    
    // Close drawers when clicking outside their boundaries
    document.addEventListener('click', (e) => {
        if (!e.target.closest('.drawer-overlay') && !e.target.closest('.toolbar-btn') && !e.target.closest('.footer-action-btn')) {
            document.querySelectorAll('.drawer-overlay').forEach(drawer => {
                drawer.classList.remove('open');
            });
        }
    });

    // Voice Speed calibration slider listener
    const voiceSpeed = document.getElementById('voiceSpeed');
    const speedVal = document.getElementById('speedVal');
    if (voiceSpeed && speedVal) {
        voiceSpeed.addEventListener('input', (e) => {
            speedVal.innerText = parseFloat(e.target.value).toFixed(1) + 'x';
        });
    }

    // Voice Pitch calibration slider listener
    const voicePitch = document.getElementById('voicePitch');
    const pitchVal = document.getElementById('pitchVal');
    if (voicePitch && pitchVal) {
        voicePitch.addEventListener('input', (e) => {
            pitchVal.innerText = parseFloat(e.target.value).toFixed(2) + 'x';
        });
    }

    // Voice Volume calibration slider listener
    const voiceVolume = document.getElementById('voiceVolume');
    const volumeVal = document.getElementById('volumeVal');
    if (voiceVolume && volumeVal) {
        voiceVolume.addEventListener('input', (e) => {
            volumeVal.innerText = parseInt(e.target.value) + '%';
        });
    }

    // Keydown typing events mapping (Hacker typing animation)
    document.addEventListener('keydown', handleKeyboardTyper);

    // Terminal override command listener
    const terminalInput = document.getElementById('terminalInput');
    if (terminalInput) {
        terminalInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') {
                const cmd = terminalInput.value.trim();
                if (!cmd) return;
                terminalInput.value = '';
                
                const output = document.getElementById('terminalOutput');
                if (output) {
                    output.innerHTML += `\n<div class="terminal-line"><span class="term-prompt">root@override:~#</span> ${cmd}</div>`;
                }
                
                if (cmd.toLowerCase() === 'help') {
                    output.innerHTML += `\n<div class="terminal-line">Available commands: help, clear, nuke, crypto, scan, connect</div>`;
                } else if (cmd.toLowerCase() === 'clear') {
                    output.innerHTML = `<div class="terminal-line"><span class="term-prompt">root@override:~#</span> Terminal cleared.</div>`;
                } else if (cmd.toLowerCase() === 'nuke') {
                    openWindow('win-nuclear');
                    triggerNuclearOverload();
                } else if (cmd.toLowerCase() === 'crypto') {
                    openWindow('win-miner');
                } else if (cmd.toLowerCase() === 'scan') {
                    openWindow('win-cctv');
                } else if (cmd.toLowerCase() === 'connect') {
                    openWindow('win-remote');
                    resetRemoteTunnel();
                } else {
                    submitTerminalPromptToAI(cmd);
                }
                if (output) output.scrollTop = output.scrollHeight;
            }
        });
    }
}

// ==========================================
// CONFIGURATIONS & API SYNC
// ==========================================
async function loadConfiguration() {
    try {
        const response = await fetch('/api/config');
        const config = await response.json();
        
        dashboardLanguage = config.dashboard_language || 'english';
        characterLanguage = config.character_language || 'hinglish';
        currentLanguage = characterLanguage;
        currentTheme = config.theme || 'dark';
        activeCharacter = config.active_character || 'lina';
        
        // Update select dropdowns layout state
        const dbSelect = document.getElementById('dashboardLangSelect');
        if (dbSelect) dbSelect.value = dashboardLanguage;
        const charSelect = document.getElementById('characterLangSelect');
        if (charSelect) charSelect.value = characterLanguage;
        localizeUI(dashboardLanguage);
        
        document.querySelectorAll('#themeToggle button').forEach(b => {
            b.classList.toggle('active', b.getAttribute('data-theme') === currentTheme);
        });
        
        // Apply theme and character class to body
        document.body.className = `${currentTheme}-theme doer-workspace char-${activeCharacter}`;
        
        // Update character switch UI buttons active class
        document.querySelectorAll('.char-select-btn').forEach(btn => {
            btn.classList.remove('active');
        });
        const activeBtn = document.getElementById(`char-btn-${activeCharacter}`);
        if (activeBtn) activeBtn.classList.add('active');
        
        // Fill input key displays
        document.getElementById('geminiKey').value = config.gemini_key || '';
        document.getElementById('weatherKey').value = config.openweather_key || '';
        
        // Fill user & assistant name displays
        document.getElementById('userName').value = config.user_name || '';
        document.getElementById('assistantName').value = config.assistant_name || '';
        
        currentUserName = config.user_name || 'User';
        currentAssistantName = config.assistant_name || 'Lina';
        
        updateUIWithAssistantName();
        updateProfileSidebarDetails();
        
        if (!config.is_configured) {
            document.getElementById('setupOverlay').classList.remove('hidden');
        }
        
        // Load memory items
        fetchMemoryLogs();
        updateSidebarBadges();
        initVoicePresets();
    } catch (e) {
        showToast("Error loading system configuration.", "error");
    }
}

function updateUIWithAssistantName() {
    const userInput = document.getElementById('userInput');
    if (userInput) {
        userInput.placeholder = `Ask ${currentAssistantName} anything...`;
    }
    const welcomeBubbleText = document.querySelector('#chatMessages .chat-bubble.assistant p');
    if (welcomeBubbleText && (welcomeBubbleText.innerText.includes('System initialized') || welcomeBubbleText.innerText.includes('Lina'))) {
        welcomeBubbleText.innerHTML = `System initialized. I am <strong>${currentAssistantName}</strong> — your personal AI Workspace Assistant ⚡. How can I help you today, ${currentUserName}?`;
    }
}

function getCharacterImagePath(char) {
    const character = char || activeCharacter;
    if (character === 'resin_robot') {
        return '/static/images/resin_robot.png';
    } else if (character === 'cyberpunk_anime') {
        return '/static/images/cyberpunk_anime.png';
    }
    return '/static/images/lina.png';
}

function updateProfileSidebarDetails() {
    const portrait = document.getElementById('characterPortrait');
    const nameEl = document.getElementById('characterProfileName');
    const titleEl = document.getElementById('characterProfileTitle');
    
    if (portrait) portrait.src = getCharacterImagePath();
    
    if (nameEl) {
        let nameText = currentAssistantName;
        if (activeCharacter === 'resin_robot') {
            nameText = 'Voxel';
        } else if (activeCharacter === 'cyberpunk_anime') {
            nameText = 'Huo Yuner';
        }
        nameEl.innerHTML = `${nameText} <span class="verified-badge" title="Verified Assistant">✓</span>`;
    }
    
    if (titleEl) {
        if (activeCharacter === 'resin_robot') {
            titleEl.innerText = 'CREATIVE 3D COMPANION';
        } else if (activeCharacter === 'cyberpunk_anime') {
            titleEl.innerText = 'CYBERPUNK STRATEGIST';
        } else {
            titleEl.innerText = 'EXECUTIVE VOICE ASSISTANT';
        }
    }
}

async function selectCharacter(charName) {
    if (charName === activeCharacter) return;
    
    try {
        const response = await fetch('/api/config', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                active_character: charName
            })
        });
        
        const res = await response.json();
        if (res.status === 'success') {
            activeCharacter = charName;
            
            // Apply body classes (preserving current theme)
            document.body.className = `${currentTheme}-theme doer-workspace char-${activeCharacter}`;
            
            // Update character switcher active classes
            document.querySelectorAll('.char-select-btn').forEach(btn => {
                btn.classList.remove('active');
            });
            const activeBtn = document.getElementById(`char-btn-${activeCharacter}`);
            if (activeBtn) activeBtn.classList.add('active');
            
            updateProfileSidebarDetails();
            showToast(`Switched assistant to ${charName === 'resin_robot' ? 'Voxel' : charName === 'cyberpunk_anime' ? 'Huo Yuner' : 'Lina'}! ⚡`);
        } else {
            showToast("Failed to switch assistant.", "error");
        }
    } catch (e) {
        showToast("Error connecting to settings server.", "error");
    }
}

// setSetupLanguage function deprecated as select element handles state directly

async function saveFirstTimeSetup() {
    const userName = document.getElementById('setupUserName').value.trim();
    const assistantName = document.getElementById('setupAssistantName').value.trim();
    const geminiKey = document.getElementById('setupGeminiKey').value.trim();
    
    if (!userName || !assistantName) {
        showToast("Please enter both your name and assistant's name.", "error");
        return;
    }
    
    try {
        const response = await fetch('/api/config', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                user_name: userName,
                assistant_name: assistantName,
                gemini_key: geminiKey,
                dashboard_language: document.getElementById('setupDashboardLangSelect').value,
                character_language: document.getElementById('setupCharacterLangSelect').value,
                language: document.getElementById('setupCharacterLangSelect').value,
                theme: currentTheme
            })
        });
        
        const res = await response.json();
        if (res.status === 'success') {
            document.getElementById('setupOverlay').classList.add('hidden');
            showToast("System initialized! Welcome! ⚡");
            loadConfiguration();
        } else {
            showToast("Initialization failed.", "error");
        }
    } catch (e) {
        showToast("Connection error during setup.", "error");
    }
}

async function saveConfiguration() {
    const saveLoader = document.getElementById('saveLoader');
    saveLoader.classList.remove('hidden');
    
    const userName = document.getElementById('userName').value.trim();
    const assistantName = document.getElementById('assistantName').value.trim();
    const geminiKey = document.getElementById('geminiKey').value;
    const weatherKey = document.getElementById('weatherKey').value;
    
    try {
        const response = await fetch('/api/config', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                user_name: userName,
                assistant_name: assistantName,
                gemini_key: geminiKey,
                openweather_key: weatherKey,
                language: currentLanguage,
                theme: currentTheme
            })
        });
        
        const res = await response.json();
        if (res.status === 'success') {
            currentUserName = userName;
            currentAssistantName = assistantName;
            updateUIWithAssistantName();
            showToast("System settings updated! ⚡");
        } else {
            showToast("Failed to save settings.", "error");
        }
    } catch (e) {
        showToast("Error connecting to settings server.", "error");
    } finally {
        saveLoader.classList.add('hidden');
    }
}

function setTheme(theme) {
    currentTheme = theme;
    document.body.className = `${theme}-theme doer-workspace`;
    saveSettingsState();
}

// UI Translations Dictionary
const UI_TRANSLATIONS = {
    "english": {
        "title_system_credentials": "SYSTEM CREDENTIALS",
        "lbl_dashboard_language": "DASHBOARD LANGUAGE",
        "lbl_character_language": "CHARACTER VOICE LANGUAGE",
        "lbl_interface_style": "INTERFACE STYLE",
        "lbl_audio_channels": "AUDIO CHANNELS",
        "lbl_vocal_synthesis": "Vocal Synthesis Output",
        "lbl_weather_city": "WEATHER CITY MAP",
        "lbl_active_workspace": "ACTIVE WORKSPACE PROFILE",
        "lbl_dark": "Dark",
        "lbl_light": "Light",
        "lbl_what_call": "What should I call you?",
        "lbl_what_name": "What would you like to name me?",
        "lbl_gemini_key": "Gemini API Key (Optional)",
        "lbl_init_assistant": "INITIALIZE ASSISTANT ⚡",
        "lbl_listening": "Suno, main sun raha hoon... Speak now",
        "lbl_welcome_title": "Welcome to RoboBoy",
        "lbl_welcome_desc": "Let's personalize your voice assistant to match your environment. Configure your profile below to start.",
        "placeholder_msg": "Type your request...",
        "btn_save_settings": "Save Settings",
        "btn_close": "Close",
    },
    "hinglish": {
        "title_system_credentials": "SYSTEM CREDENTIALS",
        "lbl_dashboard_language": "DASHBOARD LANGUAGE",
        "lbl_character_language": "CHARACTER VOICE LANGUAGE",
        "lbl_interface_style": "INTERFACE STYLE",
        "lbl_audio_channels": "AUDIO CHANNELS",
        "lbl_vocal_synthesis": "Vocal Synthesis Output",
        "lbl_weather_city": "WEATHER CITY MAP",
        "lbl_active_workspace": "ACTIVE WORKSPACE PROFILE",
        "lbl_dark": "Dark",
        "lbl_light": "Light",
        "lbl_what_call": "Aapka naam kya hai?",
        "lbl_what_name": "Mera naam kya rakhoge?",
        "lbl_gemini_key": "Gemini API Key (Optional)",
        "lbl_init_assistant": "ASSISTANT INITIALIZE KAREIN ⚡",
        "lbl_listening": "Suno, main sun raha hoon... Speak now",
        "lbl_welcome_title": "RoboBoy me aapka Swagat hai",
        "lbl_welcome_desc": "Aapke environment ke hisaab se assistant ko personalize karte hain. Apni settings select karein.",
        "placeholder_msg": "Kuchh poochhiye ya command dijiye...",
        "btn_save_settings": "Save Settings",
        "btn_close": "Close",
    },
    "hindi": {
        "title_system_credentials": "सिस्टम सेटिंग्स",
        "lbl_dashboard_language": "डैशबोर्ड की भाषा",
        "lbl_character_language": "3D कैरेक्टर की भाषा",
        "lbl_interface_style": "इंटरफ़ेस शैली",
        "lbl_audio_channels": "ऑडियो चैनल",
        "lbl_vocal_synthesis": "आवाज संश्लेषण आउटपुट",
        "lbl_weather_city": "मौसम शहर नक्शा",
        "lbl_active_workspace": "सक्रिय कार्यक्षेत्र प्रोफ़ाइल",
        "lbl_dark": "डार्क",
        "lbl_light": "लाइट",
        "lbl_what_call": "मुझे आपको क्या बुलाना चाहिए?",
        "lbl_what_name": "आप मेरा नाम क्या रखना चाहेंगे?",
        "lbl_gemini_key": "जेमिनी एपीआई कुंजी (वैकल्पिक)",
        "lbl_init_assistant": "असिस्टेंट प्रारंभ करें ⚡",
        "lbl_listening": "सुन रहा हूँ... बोलिए",
        "lbl_welcome_title": "रोबोबॉय में आपका स्वागत है",
        "lbl_welcome_desc": "आइए आपके परिवेश से मेल खाने के लिए आपके वॉयस असिस्टेंट को वैयक्तिकृत करें। प्रारंभ करने के लिए नीचे अपना प्रोफ़ाइल कॉन्फ़िगर करें।",
        "placeholder_msg": "अपनी आवश्यकता टाइप करें...",
        "btn_save_settings": "सेटिंग्स सहेजें",
        "btn_close": "बंद करें",
    },
    "german": {
        "title_system_credentials": "SYSTEM-CREDENTIALS",
        "lbl_dashboard_language": "DASHBOARD-SPRACHE",
        "lbl_character_language": "STIMMEN-SPRACHE",
        "lbl_interface_style": "OBERFLÄCHEN-STIL",
        "lbl_audio_channels": "AUDIO-KANÄLE",
        "lbl_vocal_synthesis": "Sprachausgabe aktivieren",
        "lbl_weather_city": "WETTER-STADTPLAN",
        "lbl_active_workspace": "AKTIVES WORKSPACE-PROFIL",
        "lbl_dark": "Dunkel",
        "lbl_light": "Hell",
        "lbl_what_call": "Wie soll ich Sie nennen?",
        "lbl_what_name": "Wie möchten Sie mich nennen?",
        "lbl_gemini_key": "Gemini-API-Schlüssel (Optional)",
        "lbl_init_assistant": "ASSISTENT INITIALISIEREN ⚡",
        "lbl_listening": "Ich höre zu... Bitte sprechen",
        "lbl_welcome_title": "Willkommen bei RoboBoy",
        "lbl_welcome_desc": "Lassen Sie uns Ihren Sprachassistenten personalisieren. Konfigurieren Sie unten Ihr Profil, um zu starten.",
        "placeholder_msg": "Schreiben Sie Ihre Anfrage...",
        "btn_save_settings": "Speichern",
        "btn_close": "Schließen",
    },
    "chinese": {
        "title_system_credentials": "系统凭证与设置",
        "lbl_dashboard_language": "仪表盘语言",
        "lbl_character_language": "角色语音语言",
        "lbl_interface_style": "界面风格风格",
        "lbl_audio_channels": "音频通道",
        "lbl_vocal_synthesis": "启用语音合成输出",
        "lbl_weather_city": "天气定位城市",
        "lbl_active_workspace": "活跃工作区个人资料",
        "lbl_dark": "深色",
        "lbl_light": "浅色",
        "lbl_what_call": "我该如何称呼您？",
        "lbl_what_name": "您想给我起什么名字？",
        "lbl_gemini_key": "Gemini API 密钥 (可选)",
        "lbl_init_assistant": "初始化助理 ⚡",
        "lbl_listening": "正在倾听... 请开始说话",
        "lbl_welcome_title": "欢迎使用 RoboBoy",
        "lbl_welcome_desc": "让我们个性化您的语音助理以匹配您的环境。在下方配置您的个人资料以开始使用。",
        "placeholder_msg": "输入您的请求...",
        "btn_save_settings": "保存设置",
        "btn_close": "关闭",
    },
    "bhojpuri": {
        "title_system_credentials": "सिस्टम सेटिंग",
        "lbl_dashboard_language": "डैशबोर्ड के भाषा",
        "lbl_character_language": "3D कैरेक्टर के भाषा",
        "lbl_interface_style": "इंटरफ़ेस के स्टाइल",
        "lbl_audio_channels": "ऑडियो चैनल",
        "lbl_vocal_synthesis": "बोले वाला आउटपुट",
        "lbl_weather_city": "मौसम शहर",
        "lbl_active_workspace": "चालू प्रोफाइल",
        "lbl_dark": "अँधेरिया",
        "lbl_light": "अँजोर",
        "lbl_what_call": "हम रउआ का कह के बुलाईं?",
        "lbl_what_name": "रउआ हमार का नाम रखल चाहत बानी?",
        "lbl_gemini_key": "जेमिनी एपीआई कुंजी (चाही तँ)",
        "lbl_init_assistant": "असिस्टेंट चालू करीं ⚡",
        "lbl_listening": "सुनात बानी... बोलीं",
        "lbl_welcome_title": "रोबोबॉय में रउआ स्वागत बा",
        "lbl_welcome_desc": "आईं रउआ पसंद के हिसाब से असिस्टेंट के प्रोफाइल सेट कइल जाव।",
        "placeholder_msg": "कुछ लिख के पूछीं...",
        "btn_save_settings": "सेटिंग सहेजीं",
        "btn_close": "बंद करीं",
    },
    "maithili": {
        "title_system_credentials": "सिस्टमक सेटिंग",
        "lbl_dashboard_language": "डैशबोर्डक भाषा",
        "lbl_character_language": "3D पात्रक भाषा",
        "lbl_interface_style": "इंटरफ़ेसक शैली",
        "lbl_audio_channels": "ऑडियो चैनल",
        "lbl_vocal_synthesis": "आवाज आउटपुट",
        "lbl_weather_city": "मौसम शहर",
        "lbl_active_workspace": "सक्रिय प्रोफाइल",
        "lbl_dark": "डार्क",
        "lbl_light": "लाइट",
        "lbl_what_call": "हम अहाँ के की कहि क' बाजी?",
        "lbl_what_name": "अहाँ हमार की नाम रखऽ चाहैत छी?",
        "lbl_gemini_key": "जेमिनी एपीआई कुंजी (वैकल्पिक)",
        "lbl_init_assistant": "असिस्टेंट प्रारंभ करू ⚡",
        "lbl_listening": "सुनि रहल छी... बाजू",
        "lbl_welcome_title": "रोबोबॉय में अपनेक स्वागत अछि",
        "lbl_welcome_desc": "आऊ अपनेक पसंद के अनुसार असिस्टेंट के सेटिंग कयल जाय।",
        "placeholder_msg": "किछु लिखि क' पुछू...",
        "btn_save_settings": "सेटिंग सुरक्षित करू",
        "btn_close": "बंद करू",
    }
};

function getSpeechLangCode(lang) {
    const langMap = {
        "english": "en-US",
        "hinglish": "hi-IN",
        "hindi": "hi-IN",
        "german": "de-DE",
        "chinese": "zh-CN",
        "bhojpuri": "hi-IN",
        "maithili": "hi-IN"
    };
    return langMap[lang.toLowerCase()] || "en-US";
}

function localizeUI(lang) {
    const translations = UI_TRANSLATIONS[lang] || UI_TRANSLATIONS["english"];
    
    // System Credentials Title
    const titleEl = document.querySelector('#settingsDrawer h2');
    if (titleEl && translations["title_system_credentials"]) titleEl.textContent = translations["title_system_credentials"];
    
    // Labels
    const lblDbLang = document.getElementById('lblDashboardLanguage');
    if (lblDbLang) lblDbLang.textContent = translations["lbl_dashboard_language"];
    
    const lblCharLang = document.getElementById('lblCharacterLanguage');
    if (lblCharLang) lblCharLang.textContent = translations["lbl_character_language"];
    
    const lblStyle = document.querySelector('#settingsDrawer .control-group:nth-of-type(3) label');
    if (lblStyle) lblStyle.textContent = translations["lbl_interface_style"];
    
    const lblAudio = document.querySelector('#settingsDrawer .control-group:nth-of-type(4) label');
    if (lblAudio) lblAudio.textContent = translations["lbl_audio_channels"];
    
    const lblVocal = document.querySelector('label[for="ttsEnabled"]');
    if (lblVocal) lblVocal.textContent = translations["lbl_vocal_synthesis"];
    
    // Setup wizard translations
    const setupTitle = document.querySelector('.setup-card h2');
    if (setupTitle) setupTitle.textContent = translations["lbl_welcome_title"];
    
    const setupDesc = document.querySelector('.setup-card p');
    if (setupDesc) setupDesc.textContent = translations["lbl_welcome_desc"];
    
    const lblSetupCall = document.querySelector('.setup-card .control-group:nth-of-type(1) label');
    if (lblSetupCall) lblSetupCall.textContent = translations["lbl_what_call"];
    
    const lblSetupName = document.querySelector('.setup-card .control-group:nth-of-type(2) label');
    if (lblSetupName) lblSetupName.textContent = translations["lbl_what_name"];
    
    const lblSetupDb = document.getElementById('lblSetupDashboardLang');
    if (lblSetupDb) lblSetupDb.textContent = translations["lbl_dashboard_language"];
    
    const lblSetupChar = document.getElementById('lblSetupCharacterLang');
    if (lblSetupChar) lblSetupChar.textContent = translations["lbl_character_language"];
    
    const lblSetupGemini = document.querySelector('.setup-card .control-group:nth-of-type(5) label');
    if (lblSetupGemini) lblSetupGemini.textContent = translations["lbl_gemini_key"];
    
    const btnInit = document.querySelector('.save-settings-btn span');
    if (btnInit) btnInit.textContent = translations["lbl_init_assistant"];
    
    // Chat placeholder
    const chatInput = document.getElementById('chatInput');
    if (chatInput) chatInput.placeholder = translations["placeholder_msg"];
    
    // Listening text
    const listeningEl = document.querySelector('.listening-status-text');
    if (listeningEl) listeningEl.textContent = translations["lbl_listening"];
}

async function updateDashboardLanguage(lang) {
    dashboardLanguage = lang;
    localizeUI(lang);
    
    // Sync to backend config
    try {
        await fetch('/api/config', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({ dashboard_language: lang })
        });
    } catch(e) {
        console.error("Failed to sync dashboard language to backend", e);
    }
}

async function updateCharacterLanguage(lang) {
    characterLanguage = lang;
    currentLanguage = lang;
    
    // Update SpeechRecognition BCP-47 code dynamically
    if (speechRecognition) {
        speechRecognition.lang = getSpeechLangCode(lang);
    }
    
    // Sync to backend config
    try {
        await fetch('/api/config', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({
                character_language: lang,
                language: lang
            })
        });
    } catch(e) {
        console.error("Failed to sync character language to backend", e);
    }
}

// ==========================================
// DRAWER OVERLAYS CONTROL
// ==========================================
function toggleDrawer(drawerId) {
    const drawer = document.getElementById(drawerId);
    if (drawer) {
        const isOpen = drawer.classList.contains('open');
        // Close all drawers
        document.querySelectorAll('.drawer-overlay').forEach(d => d.classList.remove('open'));
        if (!isOpen) {
            drawer.classList.add('open');
        }
    }
}

// ==========================================
// SYSTEM STATS MONITORING
// ==========================================
async function updateMetrics() {
    try {
        const response = await fetch('/api/system_info');
        const stats = await response.json();
        
        if (response.ok) {
            // Update CPU Gauge
            updateGauge('cpuRing', 'cpuVal', stats.cpu);
            
            // Update RAM Gauge
            updateGauge('ramRing', 'ramVal', stats.memory);
            
            // Update Uptime display
            document.getElementById('serverUptime').innerText = stats.uptime;
            
            // Sync power badge count based on CPU load (interactive details!)
            document.getElementById('badgePower').innerText = Math.round(stats.cpu);
        }
    } catch (e) {
        console.error("Stats fetch error.");
    }
}

function updateGauge(circleId, textId, percent) {
    const circle = document.getElementById(circleId);
    const text = document.getElementById(textId);
    if (!circle || !text) return;
    
    const rounded = Math.round(percent);
    text.innerText = rounded;
    
    // Radius is 34, Circumference = 213.63
    const circumference = 2 * Math.PI * 34;
    const offset = circumference - (rounded / 100) * circumference;
    circle.style.strokeDashoffset = offset;
}

// ==========================================
// MEMORY DATABASE OPERATIONS
// ==========================================
async function fetchMemoryLogs() {
    const container = document.getElementById('memoryScroll');
    if (!container) return;
    
    try {
        const response = await fetch('/api/memory');
        const data = await response.json();
        
        container.innerHTML = '';
        if (data.memories && data.memories.length > 0) {
            data.memories.forEach((memory, index) => {
                const itemDiv = document.createElement('div');
                itemDiv.className = 'memory-item';
                itemDiv.innerHTML = `
                    <p>${memory}</p>
                    <button class="delete-memory-btn" onclick="deleteMemoryItem(${index})" title="Delete Memory">🗑️</button>
                `;
                container.appendChild(itemDiv);
            });
        } else {
            container.innerHTML = `<div class="memory-empty">No stored records.</div>`;
        }
    } catch (e) {
        container.innerHTML = `<div class="memory-empty">Failed to fetch logs.</div>`;
    }
}

async function addMemoryPrompt() {
    const promptText = prompt("Enter info to save in DOER's cognitive memory logs:");
    if (!promptText || !promptText.trim()) return;
    
    try {
        const response = await fetch('/api/memory', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ content: promptText })
        });
        
        if (response.ok) {
            showToast("Cognitive record saved! 🧠");
            fetchMemoryLogs();
        } else {
            const err = await response.json();
            showToast(err.message || "Failed to save memory.", "error");
        }
    } catch (e) {
        showToast("Connection to memory API failed.", "error");
    }
}

async function deleteMemoryItem(index) {
    if (!confirm("Are you sure you want to delete this memory record?")) return;
    
    try {
        const response = await fetch('/api/memory', {
            method: 'DELETE',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ index: index })
        });
        
        if (response.ok) {
            showToast("Memory record deleted.");
            fetchMemoryLogs();
        }
    } catch (e) {
        showToast("Failed to delete memory item.", "error");
    }
}

// ==========================================
// VOICE CORE SPEECH RECOGNITION (Web Speech API)
// ==========================================
function setupSpeechRecognition() {
    const Speech = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!Speech) {
        console.warn("Speech recognition not supported. Keyboard inputs only.");
        document.getElementById('voiceTriggerBtn').style.display = 'none';
        return;
    }
    
    speechRecognition = new Speech();
    speechRecognition.continuous = false;
    speechRecognition.interimResults = false;
    speechRecognition.lang = (currentLanguage === 'hinglish') ? 'hi-IN' : 'en-US';
    
    speechRecognition.onstart = () => {
        isListening = true;
        document.getElementById('voiceTriggerBtn').classList.add('listening');
        document.getElementById('voiceVisualizer').classList.remove('hidden');
        document.getElementById('statusText').innerText = "Listening...";
        document.getElementById('voiceVisualizerText').innerText = "Listening for command...";
    };
    
    speechRecognition.onresult = (event) => {
        const text = event.results[0][0].transcript;
        document.getElementById('userInput').value = text;
        submitMessage();
    };
    
    speechRecognition.onerror = (event) => {
        console.error("Speech Recognition Error:", event.error);
        if (event.error !== 'no-speech') {
            showToast("Speech Recognition Error: " + event.error, "error");
        }
    };
    
    speechRecognition.onend = () => {
        isListening = false;
        document.getElementById('voiceTriggerBtn').classList.remove('listening');
        document.getElementById('voiceVisualizer').classList.add('hidden');
        document.getElementById('statusText').innerText = "DOER Engine Ready";
    };
}

function toggleVoiceInput() {
    if (!speechRecognition) {
        showToast("Speech recognition not supported in this browser.", "error");
        return;
    }
    
    if (isListening) {
        speechRecognition.stop();
    } else {
        synth.cancel();
        speechRecognition.start();
    }
}

// ==========================================
// VOICE PRESET FUNCTIONS
// ==========================================
function initVoicePresets() {
    selectVoicePreset(activeVoicePreset, false);
}

function selectVoicePreset(presetName, speakTest = true) {
    if (!voicePresets[presetName]) return;
    
    activeVoicePreset = presetName;
    localStorage.setItem('activeVoicePreset', presetName);
    
    document.querySelectorAll('.voice-select-btn').forEach(btn => {
        btn.classList.remove('active');
    });
    const activeBtn = document.getElementById(`voice-btn-${presetName}`);
    if (activeBtn) {
        activeBtn.classList.add('active');
    }
    
    const presetSelect = document.getElementById('voicePresetSelect');
    if (presetSelect) {
        presetSelect.value = presetName;
    }
    
    const preset = voicePresets[presetName];
    const speedSlider = document.getElementById('voiceSpeed');
    const pitchSlider = document.getElementById('voicePitch');
    const speedVal = document.getElementById('speedVal');
    const pitchVal = document.getElementById('pitchVal');
    
    if (speedSlider && speedVal) {
        speedSlider.value = preset.rate;
        speedVal.innerText = preset.rate.toFixed(1) + 'x';
    }
    if (pitchSlider && pitchVal) {
        pitchSlider.value = preset.pitch;
        pitchVal.innerText = preset.pitch.toFixed(2) + 'x';
    }
    
    if (speakTest) {
        speakText(`Testing ${preset.name} voice.`);
    }
}

function findVoiceByGenderAndLang(gender, lang) {
    if (!synth) return null;
    const voices = synth.getVoices();
    if (!voices || voices.length === 0) return null;
    
    let langFiltered = [];
    if (lang === 'hinglish') {
        langFiltered = voices.filter(v => v.lang.includes('hi') || v.name.toLowerCase().includes('google hindi') || v.name.toLowerCase().includes('lekha'));
    } else {
        langFiltered = voices.filter(v => v.lang.includes('en'));
    }
    
    if (langFiltered.length === 0) {
        langFiltered = voices;
    }
    
    const femaleKeywords = ['female', 'zira', 'samantha', 'karen', 'moira', 'tessa', 'veena', 'victoria', 'susan', 'hazel', 'elizabeth', 'serena', 'salli', 'joanna', 'ivy', 'kendra', 'kimberly', 'nicole', 'lekha'];
    const maleKeywords = ['male', 'david', 'ravi', 'george', 'daniel', 'oliver', 'rishi', 'alex', 'fred', 'tom', 'guy', 'russell', 'joey', 'justin', 'matthew'];
    
    let genderFiltered = langFiltered.filter(v => {
        const name = v.name.toLowerCase();
        if (gender === 'female') {
            return femaleKeywords.some(kw => name.includes(kw)) && !maleKeywords.some(kw => name.includes(kw));
        } else if (gender === 'male') {
            return maleKeywords.some(kw => name.includes(kw)) && !femaleKeywords.some(kw => name.includes(kw));
        }
        return true;
    });
    
    if (genderFiltered.length === 0) {
        genderFiltered = langFiltered;
    }
    
    return genderFiltered[0] || voices[0];
}

// ==========================================
// VOICE SYNTHESIS RESPONDER (Text to Speech)
// ==========================================
function speakText(text) {
    if (!ttsEnabled || !synth) return;
    
    synth.cancel();
    
    // Filter markdown codes out of voice
    let spokenText = text.replace(/```[\s\S]*?```/g, "[Code block]");
    spokenText = spokenText.replace(/[*#`_\-]/g, ""); 
    
    const utterance = new SpeechSynthesisUtterance(spokenText);
    
    const preset = voicePresets[activeVoicePreset];
    const gender = preset ? preset.gender : 'female';
    const selectedVoice = findVoiceByGenderAndLang(gender, currentLanguage);
    
    if (selectedVoice) {
        utterance.voice = selectedVoice;
    }
    
    const speedEl = document.getElementById('voiceSpeed');
    const pitchEl = document.getElementById('voicePitch');
    const volumeEl = document.getElementById('voiceVolume');
    
    utterance.rate = speedEl ? parseFloat(speedEl.value) : 1.0;
    utterance.pitch = pitchEl ? parseFloat(pitchEl.value) : 1.05;
    utterance.volume = volumeEl ? parseFloat(volumeEl.value) / 100 : 1.0;
    
    // Center Screen Cyber Face Lip-Sync & Speech Banner Trigger
    const hudSpeechText = document.getElementById('hudSpeechText');
    const hudSpeechBanner = document.getElementById('hudSpeechBanner');
    const cyberFaceHologram = document.getElementById('cyberFaceHologram');
    const cyberMouthEqualizer = document.getElementById('cyberMouthEqualizer');

    if (hudSpeechText) hudSpeechText.innerText = spokenText;
    if (hudSpeechBanner) hudSpeechBanner.classList.add('speaking');
    if (cyberFaceHologram) cyberFaceHologram.classList.add('speaking');
    if (cyberMouthEqualizer) cyberMouthEqualizer.classList.add('speaking');

    const resetLipSync = () => {
        if (hudSpeechBanner) hudSpeechBanner.classList.remove('speaking');
        if (cyberFaceHologram) cyberFaceHologram.classList.remove('speaking');
        if (cyberMouthEqualizer) cyberMouthEqualizer.classList.remove('speaking');
        if (hudSpeechText) hudSpeechText.innerText = "SYSTEM READY. AWAITING COMMAND.";
    };

    utterance.onend = resetLipSync;
    utterance.onerror = resetLipSync;
    
    synth.speak(utterance);
}

// ==========================================
// CONTEXT-AWARE COMMAND CLIENT SUBMISSION
// ==========================================
async function submitMessage() {
    const input = document.getElementById('userInput');
    const text = input.value.trim();
    if (!text) return;
    
    input.value = '';
    synth.cancel();
    
    // Clear chat client logic
    if (text.toLowerCase() === 'clear chat' || text.toLowerCase() === 'new chat') {
        clearChat();
        return;
    }
    
    // Append User speech bubble (sand pill color)
    appendChatBubble('user', text);
    
    document.getElementById('statusText').innerText = "Processing command...";
    
    try {
        const response = await fetch('/api/command', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                command: text,
                history: chatHistory
            })
        });
        
        const data = await response.json();
        
        // Add user turn to context history
        chatHistory.push({ role: 'user', text: text });
        
        // Count code blocks if assistant sends any
        if (data.response.includes('```')) {
            codeCount++;
        }
        conversationCount++;
        updateSidebarBadges();
        
        // Render bubble responses
        if (data.action === 'screenshot' && data.media_url) {
            appendScreenshotBubble(data.response, data.media_url);
        } else {
            appendChatBubble('assistant', data.response);
        }
        
        // Add assistant response to history
        chatHistory.push({ role: 'model', text: data.response });
        
        // Audio synthesis output
        speakText(data.response);
        
        if (data.action === 'memory') {
            fetchMemoryLogs();
        }
        
        document.getElementById('statusText').innerText = "DOER Engine Ready";
        
    } catch (e) {
        appendChatBubble('assistant', "Could not establish workspace connection with python server.");
        document.getElementById('statusText').innerText = "Connection Error";
    }
}

function executeQuickCommand(cmd) {
    if (cmd === 'Clear Chat') {
        clearChat();
    } else {
        document.getElementById('userInput').value = cmd;
        submitMessage();
    }
}

function clearChat() {
    chatHistory = [];
    codeCount = 0;
    conversationCount = 1;
    updateSidebarBadges();
    
    let charName = currentAssistantName;
    if (activeCharacter === 'resin_robot') {
        charName = 'Voxel';
    } else if (activeCharacter === 'cyberpunk_anime') {
        charName = 'Huo Yuner';
    }
    
    const messagesCanvas = document.getElementById('chatMessages');
    messagesCanvas.innerHTML = `
        <div class="chat-bubble assistant animate-fade-in">
            <div class="bubble-avatar-img-container">
                <img src="${getCharacterImagePath()}" class="bubble-avatar-img" alt="${charName}">
            </div>
            <div class="bubble-body">
                <p>System initialized. I am <strong>${charName}</strong> — your personal AI Workspace Assistant ⚡. How can I help you today, ${currentUserName}?</p>
            </div>
        </div>
    `;
    showToast("Chat context cleared.");
}

function updateSidebarBadges() {
    const codeBadge = document.getElementById('badgeCode');
    const convBadge = document.getElementById('badgeConversations');
    if (codeBadge) codeBadge.innerText = codeCount;
    if (convBadge) convBadge.innerText = conversationCount;
}

function triggerScreenshot() {
    appendChatBubble('user', 'Take a screenshot');
    synth.cancel();
    document.getElementById('statusText').innerText = "Capturing screen...";
    
    fetch('/api/screenshot', { method: 'POST' })
        .then(res => res.json())
        .then(data => {
            if (data.status === 'success') {
                appendScreenshotBubble("Desktop screenshot captured successfully! 📸", data.path);
                speakText("Screenshot taken.");
            } else {
                appendChatBubble('assistant', "Screenshot capture failed.");
            }
            document.getElementById('statusText').innerText = "DOER Engine Ready";
        })
        .catch(() => {
            appendChatBubble('assistant', "Error communicating with screenshot server.");
            document.getElementById('statusText').innerText = "DOER Engine Ready";
        });
}

// ==========================================
// CHAT HTML BUBBLE RENDERING IMPLEMENTATIONS
// ==========================================
function appendChatBubble(sender, text) {
    const chatMessages = document.getElementById('chatMessages');
    const bubble = document.createElement('div');
    bubble.className = `chat-bubble ${sender} animate-fade-in`;
    
    const formattedText = parseMarkdown(text);
    if (sender === 'assistant') {
        let charName = currentAssistantName;
        if (activeCharacter === 'resin_robot') charName = 'Voxel';
        else if (activeCharacter === 'cyberpunk_anime') charName = 'Huo Yuner';
        
        bubble.innerHTML = `
            <div class="bubble-avatar-img-container">
                <img src="${getCharacterImagePath()}" class="bubble-avatar-img" alt="${charName}">
            </div>
            <div class="bubble-body">${formattedText}</div>
        `;
    } else {
        bubble.innerHTML = `
            <div class="bubble-body">${formattedText}</div>
        `;
    }
    
    chatMessages.appendChild(bubble);
    chatMessages.scrollTop = chatMessages.scrollHeight;
}

function appendScreenshotBubble(text, imagePath) {
    const chatMessages = document.getElementById('chatMessages');
    const bubble = document.createElement('div');
    bubble.className = `chat-bubble assistant animate-fade-in`;
    
    const cacheBusterPath = `${imagePath}?t=${new Date().getTime()}`;
    
    let charName = currentAssistantName;
    if (activeCharacter === 'resin_robot') charName = 'Voxel';
    else if (activeCharacter === 'cyberpunk_anime') charName = 'Huo Yuner';
    
    bubble.innerHTML = `
        <div class="bubble-avatar-img-container">
            <img src="${getCharacterImagePath()}" class="bubble-avatar-img" alt="${charName}">
        </div>
        <div class="bubble-body">
            <p>${text}</p>
            <img src="${cacheBusterPath}" class="screenshot-media" alt="Screenshot" onclick="window.open(this.src, '_blank')">
        </div>
    `;
    
    chatMessages.appendChild(bubble);
    chatMessages.scrollTop = chatMessages.scrollHeight;
}

// ==========================================
// TEXT PARSERS (Markdown & code highlighter)
// ==========================================
function parseMarkdown(text) {
    if (!text) return "";
    
    let html = text;
    
    // 1. Code blocks: ```javascript [code] ```
    const codeBlockRegex = /```(\w*)\n([\s\S]*?)```/g;
    html = html.replace(codeBlockRegex, (match, lang, code) => {
        const cleanCode = code.replace(/</g, "&lt;").replace(/>/g, "&gt;");
        const displayLang = lang || 'code';
        return `
            <div class="code-container">
                <div class="code-header">
                    <span>${displayLang.toUpperCase()}</span>
                    <button class="copy-btn" onclick="copyCodeBlock(this)">Copy</button>
                </div>
                <div class="code-block">${cleanCode.trim()}</div>
            </div>
        `;
    });
    
    // 2. Inline codes: `code`
    html = html.replace(/`([^`]+)`/g, '<code style="background: rgba(250, 245, 238, 0.08); padding: 2px 6px; border-radius: 4px; font-family: monospace; font-size: 0.9em;">$1</code>');
    
    // 3. Bold text: **bold**
    html = html.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
    
    // 4. Bullet lists: - item
    html = html.replace(/^\-\s+(.+)$/gm, '<li>$1</li>');
    html = html.replace(/(<li>.*<\/li>)/gs, '<ul>$1</ul>');
    
    // Replace double newlines with line breaks
    html = html.replace(/\n\n/g, '<br><br>');
    
    return html;
}

function copyCodeBlock(btn) {
    const codeBlock = btn.closest('.code-container').querySelector('.code-block');
    const text = codeBlock.innerText;
    
    navigator.clipboard.writeText(text).then(() => {
        const oldText = btn.innerText;
        btn.innerText = "Copied!";
        setTimeout(() => {
            btn.innerText = oldText;
        }, 2000);
    }).catch(err => {
        showToast("Clipboard copy failed.", "error");
    });
}

// ==========================================
// TOAST NOTIFICATIONS & VISIBILITIES
// ==========================================
function showToast(message, type = "success") {
    const toast = document.getElementById('toast');
    const toastMsg = document.getElementById('toastMsg');
    if (!toast || !toastMsg) return;
    
    toastMsg.innerText = message;
    
    toast.className = 'toast'; // Reset classes
    if (type === 'error') {
        toast.classList.add('error');
    }
    
    toast.classList.remove('hidden');
    
    setTimeout(() => {
        toast.classList.add('hidden');
    }, 3500);
}

function toggleKeyVisibility(inputId) {
    const input = document.getElementById(inputId);
    if (input.type === 'password') {
        input.type = 'text';
    } else {
        input.type = 'password';
    }
}

function toggleDropdown() {
    // Left as aesthetic placeholder, can expand or toggle nav filters
    showToast("Workspace scope: Chat");
}

// ==========================================
// TELEMETRY LIVE CHART RENDERING (Pin 2 style)
// ==========================================
let chartData = [35, 45, 25, 50, 30, 40, 20, 35, 45, 30];

function updateTelemetryChart() {
    chartData.shift();
    const cpuVal = parseInt(document.getElementById('cpuVal').innerText) || 30;
    // Map CPU load to telemetry peaks
    const baseHeight = 55 - (cpuVal / 100) * 45;
    const newVal = Math.max(10, Math.min(50, baseHeight + (Math.random() * 16 - 8)));
    chartData.push(newVal);
    
    const strokePath = document.getElementById('chartStrokePath');
    const areaPath = document.getElementById('chartAreaPath');
    if (!strokePath || !areaPath) return;
    
    // Width is 240, 10 points -> spacing is 240 / 9 = 26.66
    let d = `M 0 ${chartData[0]}`;
    for (let i = 1; i < chartData.length; i++) {
        const x = i * 26.66;
        const y = chartData[i];
        const prevX = (i - 1) * 26.66;
        const prevY = chartData[i - 1];
        const cpX1 = prevX + 13.33;
        const cpY1 = prevY;
        const cpX2 = x - 13.33;
        const cpY2 = y;
        d += ` C ${cpX1} ${cpY1}, ${cpX2} ${cpY2}, ${x} ${y}`;
    }
    
    strokePath.setAttribute('d', d);
    areaPath.setAttribute('d', `${d} L 240 60 L 0 60 Z`);
}

// Tab Switching for Right Column (Diagnostics / Settings Menu Bar)
function switchDiagTab(event, tabId) {
    if (event) event.preventDefault();
    
    // Hide all tab panes in diagnostics
    const panes = document.querySelectorAll('.diag-tab-pane');
    panes.forEach(pane => pane.classList.remove('active'));
    
    // Show selected pane
    const activePane = document.getElementById(tabId);
    if (activePane) activePane.classList.add('active');
    
    // Deactivate all buttons
    const buttons = document.querySelectorAll('.diag-menu-btn');
    buttons.forEach(btn => btn.classList.remove('active'));
    
    // Activate clicked button
    if (event && event.currentTarget) {
        event.currentTarget.classList.add('active');
    }
}

// System configuration state saving
async function saveSettingsState() {
    try {
        await fetch('/api/config', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                theme: currentTheme,
                language: currentLanguage,
                dashboard_language: dashboardLanguage,
                character_language: characterLanguage
            })
        });
    } catch (e) {}
}

// ==========================================================================
// DRAGGABLE & RESIZABLE WINDOW MANAGER ENGINE
// ==========================================================================
let activeDragWindow = null;
let dragOffsetX = 0;
let dragOffsetY = 0;
let activeResizeWindow = null;
let startWidth = 0;
let startHeight = 0;
let startMouseX = 0;
let startMouseY = 0;
let zIndexCounter = 100;

function initWindowManager() {
    const windows = document.querySelectorAll('.window');
    windows.forEach(win => {
        // Hide all windows by default, except chatbot and terminal
        if (win.id !== 'win-chatbot' && win.id !== 'win-terminal') {
            win.style.display = 'none';
        } else {
            win.style.display = 'flex';
        }
    });
    updateTaskbarPills();
}

function dragStart(e, windowId) {
    if (e.target.closest('.window-controls')) return;
    activeDragWindow = document.getElementById(windowId);
    bringToFront(activeDragWindow);
    
    const rect = activeDragWindow.getBoundingClientRect();
    dragOffsetX = e.clientX - rect.left;
    dragOffsetY = e.clientY - rect.top;
    
    document.addEventListener('mousemove', dragMove);
    document.addEventListener('mouseup', dragEnd);
}

function dragMove(e) {
    if (!activeDragWindow) return;
    if (activeDragWindow.classList.contains('maximized')) return;
    
    let left = e.clientX - dragOffsetX;
    let top = e.clientY - dragOffsetY;
    
    // Boundary check
    left = Math.max(0, Math.min(window.innerWidth - 100, left));
    top = Math.max(0, Math.min(window.innerHeight - 80, top));
    
    activeDragWindow.style.left = left + 'px';
    activeDragWindow.style.top = top + 'px';
}

function dragEnd() {
    activeDragWindow = null;
    document.removeEventListener('mousemove', dragMove);
    document.removeEventListener('mouseup', dragEnd);
}

function resizeStart(e, windowId) {
    e.stopPropagation();
    e.preventDefault();
    activeResizeWindow = document.getElementById(windowId);
    bringToFront(activeResizeWindow);
    
    const rect = activeResizeWindow.getBoundingClientRect();
    startWidth = rect.width;
    startHeight = rect.height;
    startMouseX = e.clientX;
    startMouseY = e.clientY;
    
    document.addEventListener('mousemove', resizeMove);
    document.addEventListener('mouseup', resizeEnd);
}

function resizeMove(e) {
    if (!activeResizeWindow) return;
    if (activeResizeWindow.classList.contains('maximized')) return;
    
    const newWidth = Math.max(280, startWidth + (e.clientX - startMouseX));
    const newHeight = Math.max(150, startHeight + (e.clientY - startMouseY));
    
    activeResizeWindow.style.width = newWidth + 'px';
    activeResizeWindow.style.height = newHeight + 'px';
}

function resizeEnd() {
    activeResizeWindow = null;
    document.removeEventListener('mousemove', resizeMove);
    document.removeEventListener('mouseup', resizeEnd);
}

function bringToFront(win) {
    zIndexCounter++;
    win.style.zIndex = zIndexCounter;
}

function openWindow(windowId) {
    const win = document.getElementById(windowId);
    if (!win) return;
    
    win.classList.remove('minimized');
    win.style.display = 'flex';
    bringToFront(win);
    updateTaskbarPills();
}

function closeWindow(windowId) {
    const win = document.getElementById(windowId);
    if (!win) return;
    win.style.display = 'none';
    updateTaskbarPills();
    
    if (windowId === 'win-nuclear') {
        stopNuclearAlarm();
    }
}

function minimizeWindow(windowId) {
    const win = document.getElementById(windowId);
    if (!win) return;
    win.classList.add('minimized');
    updateTaskbarPills();
}

function toggleMaximizeWindow(windowId) {
    const win = document.getElementById(windowId);
    if (!win) return;
    win.classList.toggle('maximized');
}

function updateTaskbarPills() {
    const container = document.getElementById('taskbarPills');
    if (!container) return;
    
    container.innerHTML = '';
    
    const programs = [
        { id: 'win-terminal', label: '💻 terminal.exe' },
        { id: 'win-chatbot', label: '🤖 roboboy_assistant' },
        { id: 'win-sysinfo', label: '📊 server_status' },
        { id: 'win-memories', label: '🧠 cognitive_logs.dat' },
        { id: 'win-miner', label: '⛏️ btc_miner.sh' },
        { id: 'win-cracker', label: '🔑 pass_brute.py' },
        { id: 'win-cctv', label: '📹 cctv_scanner' },
        { id: 'win-nuclear', label: '☢️ nuclear_core' },
        { id: 'win-interpol', label: '📂 interpol_db' },
        { id: 'win-remote', label: '🛰️ remote_tunnel' },
        { id: 'win-settings', label: '⚙️ sys_config.conf' }
    ];
    
    programs.forEach(prog => {
        const win = document.getElementById(prog.id);
        if (win && win.style.display !== 'none') {
            const pill = document.createElement('button');
            pill.className = 'taskbar-pill';
            if (win.classList.contains('minimized')) {
                pill.classList.add('minimized');
            } else {
                const allWindows = Array.from(document.querySelectorAll('.window')).filter(w => w.style.display !== 'none' && !w.classList.contains('minimized'));
                let isTop = false;
                if (allWindows.length > 0) {
                    const topWin = allWindows.reduce((prev, current) => {
                        return (parseInt(prev.style.zIndex) || 0) > (parseInt(current.style.zIndex) || 0) ? prev : current;
                    });
                    if (topWin === win) isTop = true;
                }
                if (isTop) pill.classList.add('active');
            }
            pill.innerHTML = prog.label;
            pill.onclick = () => {
                if (win.classList.contains('minimized')) {
                    win.classList.remove('minimized');
                    bringToFront(win);
                } else {
                    const allWindows = Array.from(document.querySelectorAll('.window')).filter(w => w.style.display !== 'none' && !w.classList.contains('minimized'));
                    let isTop = false;
                    if (allWindows.length > 0) {
                        const topWin = allWindows.reduce((prev, current) => {
                            return (parseInt(prev.style.zIndex) || 0) > (parseInt(current.style.zIndex) || 0) ? prev : current;
                        });
                        if (topWin === win) isTop = true;
                    }
                    if (isTop) {
                        win.classList.add('minimized');
                    } else {
                        bringToFront(win);
                    }
                }
                updateTaskbarPills();
            };
            container.appendChild(pill);
        }
    });
}

function toggleStartMenu() {
    const menu = document.getElementById('startMenu');
    if (menu) menu.classList.toggle('hidden');
}

// Close start menu on outside click
document.addEventListener('click', (e) => {
    if (!e.target.closest('#startMenu') && !e.target.closest('.start-btn')) {
        const menu = document.getElementById('startMenu');
        if (menu) menu.classList.add('hidden');
    }
});

// Tray Clock Updates
function updateClockTray() {
    const clock = document.getElementById('taskbarClock');
    if (!clock) return;
    const now = new Date();
    const timeStr = now.toTimeString().split(' ')[0];
    const dateStr = now.toISOString().slice(0, 10);
    clock.innerHTML = `${timeStr}<br>${dateStr}`;
}

// Fullscreen
function toggleFullScreen() {
    if (!document.fullscreenElement) {
        document.documentElement.requestFullscreen().catch(() => {});
    } else {
        if (document.exitFullscreen) {
            document.exitFullscreen();
        }
    }
}

// ==========================================================================
// BACKGROUND SOUND CONTROLLERS
// ==========================================================================
let soundMuted = true;

function toggleDesktopSound() {
    soundMuted = !soundMuted;
    const hum = document.getElementById('ambientHum');
    const volBtn = document.getElementById('volumeToggleBtn');
    
    if (volBtn) volBtn.innerText = soundMuted ? '🔇' : '🔊';
    if (!hum) return;
    
    if (soundMuted) {
        hum.pause();
        stopNuclearAlarmSound();
    } else {
        hum.src = 'https://assets.mixkit.co/active_storage/sfx/2568/2568-84.wav';
        hum.volume = 0.12;
        hum.play().catch(() => {});
        if (isNuclearCritical) {
            playNuclearAlarmSound();
        }
    }
}

function playAlertBeep() {
    if (soundMuted) return;
    try {
        const context = new (window.AudioContext || window.webkitAudioContext)();
        const osc = context.createOscillator();
        const gain = context.createGain();
        osc.connect(gain);
        gain.connect(context.destination);
        osc.frequency.value = 880;
        gain.gain.setValueAtTime(0.2, context.currentTime);
        osc.start();
        osc.stop(context.currentTime + 0.12);
    } catch (e) {}
}

// ==========================================================================
// MATRIX CODE RAIN EFFECT
// ==========================================================================
function initMatrixRain() {
    const canvas = document.getElementById('matrixRain');
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    
    let width = canvas.width = window.innerWidth;
    let height = canvas.height = window.innerHeight;
    
    window.addEventListener('resize', () => {
        width = canvas.width = window.innerWidth;
        height = canvas.height = window.innerHeight;
    });
    
    const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789$+-*/%=<>!&|^~?#@";
    const fontSize = 13;
    const columns = Math.floor(width / fontSize) + 1;
    
    const rainDrops = [];
    const upDrops = [];
    const colTypes = [];
    const snippetIndices = [];
    
    const codeSnippets = [
        "function hack_node(target) {",
        "  const sys = connect(target.ip);",
        "  sys.inject_payload(0x7F40);",
        "  return sys.bypass_auth();",
        "}",
        "COMPILING_CYBER_NODES...",
        "EXPLOIT_STATUS: INJECTED",
        "while(true) { scan_port(); }",
        "0x7FFF0042 ALLOCATING MEMORY...",
        "SSL_HANDSHAKE_OVERRIDE_OK",
        "import socket, ssl, sys, os",
        "if (access == GRANTED) run();",
        "DECRYPTING_AES256_KEY...",
        "SYSTEM_OVERRIDE_V9.8 ACTIVE",
        "const payload = crypto.cipher();",
        "ROOT_ACCESS_GRANTED = true;",
        "kernel.patch_memory_table();"
    ];

    for (let x = 0; x < columns; x++) {
        rainDrops[x] = Math.random() * -80;
        upDrops[x] = Math.floor(height / fontSize) + Math.random() * 80;
        
        const rand = Math.random();
        if (rand < 0.50) {
            colTypes[x] = 'down';
        } else if (rand < 0.75) {
            colTypes[x] = 'up_char';
        } else {
            colTypes[x] = 'up_code';
            snippetIndices[x] = {
                lineIdx: Math.floor(Math.random() * codeSnippets.length),
                charOffset: 0
            };
        }
    }
    
    function draw() {
        ctx.fillStyle = 'rgba(0, 0, 0, 0.05)';
        ctx.fillRect(0, 0, width, height);
        
        ctx.font = fontSize + 'px monospace';
        const totalRows = Math.floor(height / fontSize) + 1;
        
        for (let i = 0; i < columns; i++) {
            const xPos = i * fontSize;
            const type = colTypes[i];
            
            if (type === 'down') {
                // Downward matrix rain
                const text = alphabet.charAt(Math.floor(Math.random() * alphabet.length));
                ctx.fillStyle = '#00ff33';
                ctx.fillText(text, xPos, rainDrops[i] * fontSize);
                
                if (rainDrops[i] * fontSize > height && Math.random() > 0.975) {
                    rainDrops[i] = 0;
                }
                rainDrops[i]++;
            } 
            else if (type === 'up_char') {
                // Upward streaming matrix characters (Bottom to Top)
                const text = alphabet.charAt(Math.floor(Math.random() * alphabet.length));
                ctx.fillStyle = '#00ff66';
                ctx.fillText(text, xPos, upDrops[i] * fontSize);
                
                // Glowing head
                ctx.fillStyle = '#aaffcc';
                ctx.fillText(alphabet.charAt(Math.floor(Math.random() * alphabet.length)), xPos, (upDrops[i] - 1) * fontSize);
                
                if (upDrops[i] * fontSize < 0 && Math.random() > 0.975) {
                    upDrops[i] = totalRows + Math.random() * 20;
                }
                upDrops[i] -= 0.85;
            }
            else if (type === 'up_code') {
                // Upward streaming hacker code text
                const info = snippetIndices[i];
                const snippet = codeSnippets[info.lineIdx];
                const charChar = snippet.charAt(info.charOffset % snippet.length);
                
                ctx.fillStyle = '#33ffaa';
                ctx.fillText(charChar, xPos, upDrops[i] * fontSize);
                
                info.charOffset++;
                
                if (upDrops[i] * fontSize < 0 && Math.random() > 0.95) {
                    upDrops[i] = totalRows + Math.random() * 20;
                    info.lineIdx = Math.floor(Math.random() * codeSnippets.length);
                    info.charOffset = 0;
                }
                upDrops[i] -= 0.75;
            }
        }
    }
    setInterval(draw, 33);
}

// ==========================================================================
// CCTV SURVEILLANCE loop
// ==========================================================================
function initCCTVFeeds() {
    setInterval(() => {
        const cams = ['cctvCam1', 'cctvCam2', 'cctvCam3', 'cctvCam4'];
        cams.forEach((camId) => {
            const canvas = document.getElementById(camId);
            if (!canvas || canvas.offsetParent === null) return;
            const ctx = canvas.getContext('2d');
            
            const w = canvas.width = canvas.clientWidth;
            const h = canvas.height = canvas.clientHeight;
            
            const imgData = ctx.createImageData(w, h);
            const data = imgData.data;
            for (let i = 0; i < data.length; i += 4) {
                const val = Math.random() * 255;
                data[i] = val;
                data[i+1] = val;
                data[i+2] = val;
                data[i+3] = 18;
            }
            ctx.putImageData(imgData, 0, 0);
            
            ctx.strokeStyle = 'rgba(0, 255, 0, 0.12)';
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.moveTo(0, h/2); ctx.lineTo(w, h/2);
            ctx.moveTo(w/2, 0); ctx.lineTo(w/2, h);
            ctx.stroke();
            
            const scanTime = Date.now() / 1000;
            const scanY = (scanTime * 50) % h;
            ctx.fillStyle = 'rgba(0, 255, 0, 0.06)';
            ctx.fillRect(0, scanY - 8, w, 8);
            
            ctx.fillStyle = '#00ff00';
            ctx.font = '9px monospace';
            const dateStr = new Date().toISOString().replace('T', ' ').substring(0, 19);
            ctx.fillText(dateStr, 10, h - 10);
            
            if (Math.floor(scanTime) % 2 === 0) {
                ctx.fillStyle = '#ff0000';
                ctx.beginPath();
                ctx.arc(w - 15, 14, 3.5, 0, 2*Math.PI);
                ctx.fill();
                ctx.fillStyle = '#ff0000';
                ctx.fillText("REC", w - 40, 18);
            }
        });
    }, 50);
}

// ==========================================================================
// BITCOIN MINER SIMULATOR
// ==========================================================================
let minerBtcCount = 0.00041289;
let minerBlocksCount = 14;
let minerChartPoints = Array(20).fill(20);

function initMinerWidget() {
    setInterval(() => {
        const minerWin = document.getElementById('win-miner');
        if (!minerWin || minerWin.style.display === 'none') return;
        
        const hashrate = (21.0 + Math.random() * 8).toFixed(2);
        const hashrateEl = document.getElementById('minerHashrate');
        if (hashrateEl) hashrateEl.innerText = hashrate + ' MH/s';
        
        minerBtcCount += 0.00000003;
        const btcEl = document.getElementById('minerBtc');
        if (btcEl) btcEl.innerText = minerBtcCount.toFixed(8);
        
        if (Math.random() > 0.98) {
            minerBlocksCount++;
            const blocksEl = document.getElementById('minerBlocks');
            if (blocksEl) blocksEl.innerText = minerBlocksCount;
            appendMinerLog(`[ stratum ] Block solved! Block #${minerBlocksCount + 592819} verified. Wallet payout acknowledged.`);
        }
        
        if (Math.random() > 0.75) {
            const nonces = Math.floor(Math.random() * 800000);
            appendMinerLog(`[ worker_0 ] nonce: 0x${nonces.toString(16).toUpperCase()} ... Hash verified.`);
        }
        
        drawMinerChart();
    }, 1500);
}

function appendMinerLog(text) {
    const log = document.getElementById('minerLog');
    if (!log) return;
    log.innerHTML += `\n${text}`;
    log.scrollTop = log.scrollHeight;
}

function drawMinerChart() {
    const canvas = document.getElementById('minerCanvasChart');
    if (!canvas || canvas.offsetParent === null) return;
    const ctx = canvas.getContext('2d');
    const w = canvas.width = canvas.clientWidth;
    const h = canvas.height = canvas.clientHeight;
    
    minerChartPoints.shift();
    minerChartPoints.push(25 + Math.random() * 35);
    
    ctx.clearRect(0, 0, w, h);
    ctx.strokeStyle = '#33ff33';
    ctx.lineWidth = 1.2;
    ctx.beginPath();
    
    const step = w / (minerChartPoints.length - 1);
    ctx.moveTo(0, h - minerChartPoints[0]);
    for (let i = 1; i < minerChartPoints.length; i++) {
        ctx.lineTo(i * step, h - minerChartPoints[i]);
    }
    ctx.stroke();
    
    ctx.fillStyle = 'rgba(51, 255, 51, 0.05)';
    ctx.lineTo(w, h);
    ctx.lineTo(0, h);
    ctx.closePath();
    ctx.fill();
}

// ==========================================================================
// PASSWORD CRACKER / BRUTEFORCER
// ==========================================================================
let crackerPercentageVal = 0;

function initPasswordCracker() {
    const grid = document.getElementById('crackerHexGrid');
    if (grid) {
        let hexStr = "";
        for (let i = 0; i < 480; i++) {
            hexStr += Math.floor(Math.random()*16).toString(16).toUpperCase();
        }
        grid.innerText = hexStr;
    }
    
    setInterval(() => {
        const crackerWin = document.getElementById('win-cracker');
        if (!crackerWin || crackerWin.style.display === 'none' || crackerPercentageVal >= 100) return;
        
        if (grid) {
            let hexArr = grid.innerText.split('');
            for (let k = 0; k < 12; k++) {
                const idx = Math.floor(Math.random() * hexArr.length);
                hexArr[idx] = Math.floor(Math.random()*16).toString(16).toUpperCase();
            }
            grid.innerText = hexArr.join('');
        }
        
        const display = document.getElementById('crackerPasswordDisplay');
        if (display) {
            const alph = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*";
            let pass = "";
            for (let i = 0; i < 8; i++) {
                pass += alph.charAt(Math.floor(Math.random() * alph.length));
            }
            display.innerText = "TRYING: " + pass;
        }
    }, 100);
    
    setInterval(() => {
        const crackerWin = document.getElementById('win-cracker');
        if (!crackerWin || crackerWin.style.display === 'none') return;
        
        if (crackerPercentageVal < 100) {
            crackerPercentageVal += Math.floor(Math.random() * 4) + 1;
            if (crackerPercentageVal >= 100) {
                crackerPercentageVal = 100;
                showCrackerSuccess();
            }
            
            const pct = document.getElementById('crackerPercentage');
            const bar = document.getElementById('crackerBar');
            if (pct) pct.innerText = crackerPercentageVal + "%";
            if (bar) bar.style.width = crackerPercentageVal + "%";
        }
    }, 900);
}

function showCrackerSuccess() {
    const success = document.getElementById('crackerSuccess');
    if (success) {
        success.classList.remove('hidden');
        const keyEl = document.getElementById('crackedKey');
        if (keyEl) keyEl.innerText = "ADMIN_KEY: " + Math.random().toString(16).substring(2, 10).toUpperCase();
        playAlertBeep();
    }
}

function resetPasswordCracker() {
    crackerPercentageVal = 0;
    const pct = document.getElementById('crackerPercentage');
    const bar = document.getElementById('crackerBar');
    const success = document.getElementById('crackerSuccess');
    if (pct) pct.innerText = "0%";
    if (bar) bar.style.width = "0%";
    if (success) success.classList.add('hidden');
}

// ==========================================================================
// NUCLEAR FUSION CORE SIMULATOR
// ==========================================================================
let nuclearTemperatureVal = 324.5;
let nuclearPressureVal = 1.04;
let nuclearFlowVal = 85.4;
let isNuclearCritical = false;
let nuclearChartPoints = Array(30).fill(25);

function initNuclearReactor() {
    setInterval(() => {
        const nuclearWin = document.getElementById('win-nuclear');
        if (!nuclearWin || nuclearWin.style.display === 'none') return;
        
        let tempDiff = 0.4 + Math.random() * 0.7;
        const flowOffset = (nuclearFlowVal - 80) * 0.05;
        nuclearTemperatureVal += (tempDiff - flowOffset);
        
        if (nuclearTemperatureVal < 100) nuclearTemperatureVal = 100;
        nuclearPressureVal = (nuclearTemperatureVal / 310).toFixed(2);
        
        const tempEl = document.getElementById('nuclearTemp');
        const pressEl = document.getElementById('nuclearPressure');
        const flowEl = document.getElementById('nuclearFlow');
        
        if (tempEl) tempEl.innerText = nuclearTemperatureVal.toFixed(1) + " °C";
        if (pressEl) pressEl.innerText = nuclearPressureVal + " bar";
        if (flowEl) flowEl.innerText = nuclearFlowVal.toFixed(1) + " L/s";
        
        if (nuclearTemperatureVal > 600 && !isNuclearCritical) {
            triggerNuclearAlarm();
        } else if (nuclearTemperatureVal <= 600 && isNuclearCritical) {
            stopNuclearAlarm();
        }
        drawReactorCanvas();
    }, 1000);
}

function adjustNuclearCoolant(val) {
    nuclearFlowVal += val;
    if (nuclearFlowVal < 0) nuclearFlowVal = 0;
    if (nuclearFlowVal > 150) nuclearFlowVal = 150;
    showToast(`Coolant flow set to ${nuclearFlowVal.toFixed(1)} L/s.`, isNuclearCritical ? "error" : "success");
}

function triggerNuclearOverload() {
    nuclearTemperatureVal = 820.0;
    nuclearFlowVal = 0;
    showToast("CRITICAL COMMAND: Coolant loop override deactivated.", "error");
    triggerNuclearAlarm();
}

function resetNuclearReactor() {
    nuclearTemperatureVal = 324.5;
    nuclearFlowVal = 85.4;
    stopNuclearAlarm();
    showToast("Reactor baseline safety parameters restored.", "success");
}

function triggerNuclearAlarm() {
    isNuclearCritical = true;
    const box = document.getElementById('nuclearAlarmBox');
    const msg = document.getElementById('nuclearStatusMsg');
    
    if (box) box.className = 'nuclear-alert-panel critical-alert';
    if (msg) msg.innerText = "WARNING: CORE MELTDOWN IMMINENT!";
    
    document.body.classList.add('screen-shake');
    playNuclearAlarmSound();
}

function stopNuclearAlarm() {
    isNuclearCritical = false;
    const box = document.getElementById('nuclearAlarmBox');
    const msg = document.getElementById('nuclearStatusMsg');
    
    if (box) box.className = 'nuclear-alert-panel';
    if (msg) msg.innerText = "SYSTEM OPERATION: NORMAL";
    
    document.body.classList.remove('screen-shake');
    stopNuclearAlarmSound();
}

function playNuclearAlarmSound() {
    if (soundMuted) return;
    const siren = document.getElementById('alarmSiren');
    if (!siren) return;
    siren.src = 'https://assets.mixkit.co/active_storage/sfx/951/951-84.wav';
    siren.volume = 0.22;
    siren.play().catch(() => {});
}

function stopNuclearAlarmSound() {
    const siren = document.getElementById('alarmSiren');
    if (siren) siren.pause();
}

function drawReactorCanvas() {
    const canvas = document.getElementById('nuclearCanvas');
    if (!canvas || canvas.offsetParent === null) return;
    const ctx = canvas.getContext('2d');
    const w = canvas.width = canvas.clientWidth;
    const h = canvas.height = canvas.clientHeight;
    
    nuclearChartPoints.shift();
    const normalizedTemp = Math.min(h - 8, Math.max(8, (nuclearTemperatureVal / 900) * h));
    nuclearChartPoints.push(normalizedTemp);
    
    ctx.clearRect(0, 0, w, h);
    ctx.strokeStyle = isNuclearCritical ? '#ff3333' : '#33ff33';
    ctx.lineWidth = 1.8;
    ctx.beginPath();
    
    const step = w / (nuclearChartPoints.length - 1);
    ctx.moveTo(0, h - nuclearChartPoints[0]);
    for (let i = 1; i < nuclearChartPoints.length; i++) {
        ctx.lineTo(i * step, h - nuclearChartPoints[i]);
    }
    ctx.stroke();
}

// ==========================================================================
// INTERPOL WANTS NOTICE SEARCH DATABASE
// ==========================================================================
const interpolProfiles = [
    { name: "Kevin Mitnick", alias: "Condor", charges: "Computer bypass, systemic wire fraud, code compromise", origin: "United States", status: "CAPTURED", emoji: "🕵️" },
    { name: "Viktor Bout", alias: "Merchant of Death", charges: "Conspiracy armaments payload logistics", origin: "Russia", status: "CAPTURED", emoji: "💣" },
    { name: "Edward Snowden", alias: "Whistleblower", charges: "Unsanctioned disclosure of national security database logs", origin: "United States", status: "WANTED", emoji: "📄" },
    { name: "John Doe", alias: "Shadowman", charges: "SQL injector bank heist, ransomware syndicate leader", origin: "Unknown", status: "WANTED", emoji: "🎭" }
];

function initInterpolDatabase() {
    filterInterpolProfiles();
}

function filterInterpolProfiles() {
    const searchVal = document.getElementById('interpolSearch').value.toLowerCase();
    const container = document.getElementById('interpolList');
    if (!container) return;
    
    container.innerHTML = '';
    
    interpolProfiles.forEach((profile, index) => {
        if (profile.name.toLowerCase().includes(searchVal) || profile.alias.toLowerCase().includes(searchVal)) {
            const item = document.createElement('div');
            item.className = 'interpol-item';
            item.innerText = `${profile.emoji} ${profile.name} [${profile.alias}]`;
            item.onclick = () => selectInterpolProfile(index, item);
            container.appendChild(item);
        }
    });
}

function selectInterpolProfile(index, element) {
    const items = document.querySelectorAll('.interpol-item');
    items.forEach(item => item.classList.remove('active'));
    element.classList.add('active');
    
    const container = document.getElementById('interpolProfileDetail');
    if (!container) return;
    
    const profile = interpolProfiles[index];
    
    container.innerHTML = `
        <div style="text-align: center; padding: 25px;">
            <div>DECRYPTING ENCRYPTED FILE DATA...</div>
            <div class="progress-bar-wrap" style="width: 140px; margin: 8px auto;">
                <div class="progress-bar-fill" id="fingerprintBar" style="width: 0%; height: 100%;"></div>
            </div>
        </div>
    `;
    
    // Colorize scanning bar by active theme
    const bar = document.getElementById('fingerprintBar');
    if (bar) bar.style.backgroundColor = 'var(--text-primary)';
    
    let pct = 0;
    const scanInterval = setInterval(() => {
        if (pct < 100) {
            pct += 25;
            if (bar) bar.style.width = pct + '%';
            if (pct >= 100) {
                clearInterval(scanInterval);
                renderProfileDossier(profile);
            }
        }
    }, 150);
}

function renderProfileDossier(profile) {
    const container = document.getElementById('interpolProfileDetail');
    if (!container) return;
    
    container.innerHTML = `
        <div class="interpol-header-card">
            <div class="interpol-photo">${profile.emoji}</div>
            <div class="interpol-header-info">
                <h4>${profile.name}</h4>
                <div class="interpol-lbl">ALIAS: "${profile.alias.toUpperCase()}"</div>
                <span class="interpol-status-badge ${profile.status.toLowerCase()}">${profile.status}</span>
            </div>
        </div>
        <div class="interpol-details-grid">
            <span class="interpol-lbl">Charges:</span>
            <span>${profile.charges}</span>
            <span class="interpol-lbl">Origin:</span>
            <span>${profile.origin}</span>
            <span class="interpol-lbl">Threat:</span>
            <span class="text-red">LEVEL 9 (CRITICAL)</span>
            <span class="interpol-lbl">File logs:</span>
            <span>COMPROMISED (LOCKED)</span>
        </div>
    `;
    playAlertBeep();
}

// ==========================================================================
// REMOTE CONNECTION TUNNEL
// ==========================================================================
let remoteHopsCount = 0;
let radarAngle = 0;

function initRemoteTunnel() {
    const canvas = document.getElementById('remoteCanvas');
    if (canvas) {
        const ctx = canvas.getContext('2d');
        setInterval(() => {
            if (canvas.offsetParent === null) return;
            const w = canvas.width = canvas.clientWidth;
            const h = canvas.height = canvas.clientHeight;
            const cx = w / 2;
            const cy = h / 2;
            const radius = Math.min(cx, cy) - 8;
            
            ctx.clearRect(0, 0, w, h);
            ctx.strokeStyle = 'rgba(189, 0, 255, 0.16)';
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.arc(cx, cy, radius, 0, 2*Math.PI);
            ctx.stroke();
            ctx.beginPath();
            ctx.arc(cx, cy, radius * 0.6, 0, 2*Math.PI);
            ctx.stroke();
            
            ctx.beginPath();
            ctx.moveTo(cx - radius, cy); ctx.lineTo(cx + radius, cy);
            ctx.moveTo(cx, cy - radius); ctx.lineTo(cx, cy + radius);
            ctx.stroke();
            
            radarAngle += 0.04;
            const targetX = cx + Math.cos(radarAngle) * radius;
            const targetY = cy + Math.sin(radarAngle) * radius;
            
            ctx.strokeStyle = 'var(--text-primary)';
            ctx.lineWidth = 1.5;
            ctx.beginPath();
            ctx.moveTo(cx, cy);
            ctx.lineTo(targetX, targetY);
            ctx.stroke();
            
            ctx.fillStyle = 'var(--text-primary)';
            ctx.beginPath();
            ctx.arc(cx + 35, cy - 15, 2.5, 0, 2*Math.PI);
            ctx.fill();
            ctx.font = '8px monospace';
            ctx.fillText("NODE: 10.22.45.109", cx + 40, cy - 12);
        }, 45);
    }
    
    setInterval(() => {
        const remoteWin = document.getElementById('win-remote');
        if (!remoteWin || remoteWin.style.display === 'none') return;
        
        if (remoteHopsCount < 8) {
            remoteHopsCount++;
            const hopsEl = document.getElementById('remoteHops');
            const bar = document.getElementById('remoteBar');
            if (hopsEl) hopsEl.innerText = `${remoteHopsCount}/8 hops`;
            if (bar) bar.style.width = (remoteHopsCount / 8 * 100) + '%';
            
            const logs = [
                "Bouncing proxy parameters... resolving IP route.",
                "Hop 1: London, UK established (Ping: 45ms)",
                "Hop 2: Reykjavik, Iceland connected (Ping: 90ms)",
                "Hop 3: Vancouver, Canada encryption tunnel active",
                "Hop 4: Tokyo, Japan proxy redirect validated",
                "Hop 5: Beijing, China proxy bypass successful",
                "Hop 6: Moscow, Russia node connected (Ping: 140ms)",
                "Hop 7: Sydney, Australia re-routed due to lag",
                "Hop 8: Terminal connection node handshake established."
            ];
            appendRemoteConsole(`[TUNNEL] ${logs[remoteHopsCount]}`);
            
            if (remoteHopsCount === 8) {
                appendRemoteConsole(`[TUNNEL SUCCESS] Safe remote shell proxy connected. Port 22 decrypted.`);
                playAlertBeep();
            }
        }
    }, 2500);
}

function appendRemoteConsole(text) {
    const log = document.getElementById('remoteConsole');
    if (log) {
        log.innerHTML += `<br>${text}`;
        log.scrollTop = log.scrollHeight;
    }
}

function resetRemoteTunnel() {
    remoteHopsCount = 0;
    const hopsEl = document.getElementById('remoteHops');
    const bar = document.getElementById('remoteBar');
    if (hopsEl) hopsEl.innerText = "0/8 hops";
    if (bar) bar.style.width = "0%";
    const log = document.getElementById('remoteConsole');
    if (log) log.innerHTML = "[READY] Tunnel connection queue initialized.";
}

// ==========================================================================
// KEYBOARD SIMULATOR AUTO-TYPER & COMMAND INTEGRATION
// ==========================================================================
const hackerCodeSnippet = `
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>

int main(int argc, char** argv) {
    printf("Initializing kernel hijack...\\n");
    sleep(1);
    
    char* sysBuffer = (char*)malloc(1024 * sizeof(char));
    if (!sysBuffer) {
        fprintf(stderr, "Buffer leak fatal allocation.\\n");
        return 1;
    }
    
    int fd = connect_to_override_daemon("127.0.0.1", 4444);
    if (fd < 0) {
        printf("Override daemon mismatch. Injecting payload bypass...\\n");
        inject_binary_payload(sysBuffer);
    }
    
    int bytes = write(fd, "GET_SYSTEM_ACCESS", 17);
    if (bytes == 17) {
        printf("Payload signature verified. Root shell spawning...\\n");
    }
    
    printf("Access parameters override successful. Enjoy root command session.\\n");
    free(sysBuffer);
    return 0;
}
`;

let hackerCodeIndex = 0;

function handleKeyboardTyper(e) {
    if (document.activeElement.tagName === 'INPUT' || document.activeElement.tagName === 'TEXTAREA' || document.activeElement.tagName === 'SELECT') {
        return;
    }
    
    const terminalWin = document.getElementById('win-terminal');
    if (!terminalWin || terminalWin.style.display === 'none' || terminalWin.classList.contains('minimized')) {
        return;
    }
    
    const output = document.getElementById('terminalOutput');
    if (!output) return;
    
    const charsToAdd = hackerCodeSnippet.substring(hackerCodeIndex, hackerCodeIndex + 3);
    hackerCodeIndex += 3;
    if (hackerCodeIndex >= hackerCodeSnippet.length) {
        hackerCodeIndex = 0;
    }
    
    output.innerText += charsToAdd;
    output.scrollTop = output.scrollHeight;
}

async function submitTerminalPromptToAI(text) {
    const output = document.getElementById('terminalOutput');
    if (!output) return;
    
    output.innerHTML += `\n<div class="terminal-line"><span class="term-prompt">Lina // System response:</span> Analyzing query...</div>`;
    output.scrollTop = output.scrollHeight;
    
    try {
        const response = await fetch('/api/command', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                command: text,
                history: chatHistory
            })
        });
        
        const data = await response.json();
        chatHistory.push({ role: 'user', text: text });
        chatHistory.push({ role: 'model', text: data.response });
        
        output.innerHTML += `\n<div class="terminal-line"><span class="term-prompt">Lina // System response:</span> ${data.response}</div>`;
        speakText(data.response);
        updateSidebarBadges();
    } catch(e) {
        output.innerHTML += `\n<div class="terminal-line"><span class="term-prompt">Lina // System error:</span> Connection mismatch.</div>`;
    }
    output.scrollTop = output.scrollHeight;
}

function initHudCodeStream() {
    const streamContainer = document.getElementById('hudLeftCodeStream');
    if (!streamContainer) return;
    
    const linesPool = [
        "return _Selected;",
        "float m_BarHeight = GetBottomBarHeight();",
        "if (GetListFilterState() == Search) {",
        "    EditorGUI.kWindowTool.DrawHeader();",
        "}",
        "int count = node.children.Count;",
        "kernel.patch_memory_table();",
        "SSLHandshake.Override();",
        "system.inject_binary(0x7FFF0042);",
        "char* sysBuffer = (char*)malloc(1024);",
        "void* addr = mmap(NULL, 4096, PROT_READ|PROT_WRITE);",
        "if (addr == MAP_FAILED) return ERROR_MEM;",
        "socket.bind('127.0.0.1', 8080);",
        "payload.signature = verify_rsa_key();",
        "ROOT_ACCESS_GRANTED = true;",
        "while(status.active) { poll_events(); }"
    ];

    let currentLineNum = 112;

    setInterval(() => {
        const randomLine = linesPool[Math.floor(Math.random() * linesPool.length)];
        const lineEl = document.createElement('div');
        lineEl.className = 'hud-code-line';
        lineEl.innerHTML = `<span class="hud-line-num">${currentLineNum}</span><span class="hud-code-txt">${randomLine}</span>`;
        
        streamContainer.appendChild(lineEl);
        currentLineNum++;
        if (currentLineNum > 450) currentLineNum = 112;

        if (streamContainer.children.length > 25) {
            streamContainer.removeChild(streamContainer.firstChild);
        }
        streamContainer.scrollTop = streamContainer.scrollHeight;
    }, 180);
}

function initHudBpm() {
    const bpmEl = document.getElementById('hudBpm');
    if (!bpmEl) return;
    setInterval(() => {
        const bpm = 158 + Math.floor(Math.random() * 7);
        bpmEl.innerText = bpm;
    }, 1500);
}

function initCpuMonitor() {
    const cpuEl = document.getElementById('hudCpuPercent');
    const cpuBarsContainer = document.getElementById('hudCpuBars');
    if (!cpuEl || !cpuBarsContainer) return;
    
    setInterval(() => {
        const val = 65 + Math.floor(Math.random() * 25);
        cpuEl.innerText = val + '%';
        
        const bars = cpuBarsContainer.querySelectorAll('.cpu-bar');
        bars.forEach(bar => {
            const h = 40 + Math.floor(Math.random() * 55);
            bar.style.height = h + '%';
        });
    }, 1200);
}

// Global simulated loops registry initializer
function initSimulatedWidgets() {
    initCCTVFeeds();
    initMinerWidget();
    initPasswordCracker();
    initNuclearReactor();
    initInterpolDatabase();
    initRemoteTunnel();
    initHudCodeStream();
    initHudBpm();
    initCpuMonitor();
}

