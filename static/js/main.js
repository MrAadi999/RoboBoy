// ==========================================
// STATE MANAGEMENT
// ==========================================
let currentLanguage = 'hinglish';
let currentTheme = 'dark';
let ttsEnabled = true;
let chatHistory = []; // Tracks [{role: 'user'|'model', text: '...'}]
let speechRecognition = null;
let isListening = false;
let currentUserName = 'Aditya';
let currentAssistantName = 'Lina';
let setupLanguage = 'hinglish';

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
    
    // Start metric updates loop
    updateMetrics();
    setInterval(updateMetrics, 3000);
    
    // Initialize real-time dashboard telemetry graph (Pin 2 style)
    if (document.getElementById('activityChart')) {
        setInterval(updateTelemetryChart, 1500);
    }
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

    // Language switches
    const langButtons = document.querySelectorAll('#langToggle button');
    langButtons.forEach(btn => {
        btn.addEventListener('click', () => {
            const lang = btn.getAttribute('data-lang');
            setLanguage(lang);
            langButtons.forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
        });
    });

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
}

// ==========================================
// CONFIGURATIONS & API SYNC
// ==========================================
async function loadConfiguration() {
    try {
        const response = await fetch('/api/config');
        const config = await response.json();
        
        currentLanguage = config.language || 'hinglish';
        currentTheme = config.theme || 'dark';
        
        // Update toggles layout state
        document.querySelectorAll('#langToggle button').forEach(b => {
            b.classList.toggle('active', b.getAttribute('data-lang') === currentLanguage);
        });
        
        document.querySelectorAll('#themeToggle button').forEach(b => {
            b.classList.toggle('active', b.getAttribute('data-theme') === currentTheme);
        });
        
        // Apply theme classes
        document.body.className = `${currentTheme}-theme doer-workspace`;
        
        // Fill input key displays
        document.getElementById('geminiKey').value = config.gemini_key || '';
        document.getElementById('weatherKey').value = config.openweather_key || '';
        
        // Fill user & assistant name displays
        document.getElementById('userName').value = config.user_name || '';
        document.getElementById('assistantName').value = config.assistant_name || '';
        
        currentUserName = config.user_name || 'User';
        currentAssistantName = config.assistant_name || 'Lina';
        
        updateUIWithAssistantName();
        
        if (!config.is_configured) {
            document.getElementById('setupOverlay').classList.remove('hidden');
        }
        
        // Load memory items
        fetchMemoryLogs();
        updateSidebarBadges();
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

function setSetupLanguage(lang) {
    setupLanguage = lang;
    const buttons = document.querySelectorAll('#setupLangToggle button');
    buttons.forEach(btn => {
        btn.classList.toggle('active', btn.getAttribute('data-lang') === lang);
    });
}

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
                language: setupLanguage,
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

function setLanguage(lang) {
    currentLanguage = lang;
    if (speechRecognition) {
        speechRecognition.lang = (lang === 'hinglish') ? 'hi-IN' : 'en-US';
    }
    saveSettingsState();
}

async function saveSettingsState() {
    try {
        await fetch('/api/config', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                language: currentLanguage,
                theme: currentTheme
            })
        });
    } catch (e) {
        console.error("Failed to sync settings with server.");
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
// VOICE SYNTHESIS RESPONDER (Text to Speech)
// ==========================================
function speakText(text) {
    if (!ttsEnabled || !synth) return;
    
    synth.cancel();
    
    // Filter markdown codes out of voice
    let spokenText = text.replace(/```[\s\S]*?```/g, "[Code block]");
    spokenText = spokenText.replace(/[*#`_\-]/g, ""); 
    
    const utterance = new SpeechSynthesisUtterance(spokenText);
    const voices = synth.getVoices();
    let selectedVoice = null;
    
    if (currentLanguage === 'hinglish') {
        selectedVoice = voices.find(v => v.lang.includes('hi') || v.name.toLowerCase().includes('google hindi') || v.name.toLowerCase().includes('lekha'));
    }
    
    if (!selectedVoice) {
        selectedVoice = voices.find(v => v.lang.includes('en-GB') || v.name.toLowerCase().includes('google uk english')) ||
                        voices.find(v => v.lang.includes('en')) || 
                        voices[0];
    }
    
    if (selectedVoice) {
        utterance.voice = selectedVoice;
    }
    
    const speedEl = document.getElementById('voiceSpeed');
    const pitchEl = document.getElementById('voicePitch');
    const volumeEl = document.getElementById('voiceVolume');
    
    utterance.rate = speedEl ? parseFloat(speedEl.value) : 1.0;
    utterance.pitch = pitchEl ? parseFloat(pitchEl.value) : 1.05;
    utterance.volume = volumeEl ? parseFloat(volumeEl.value) / 100 : 1.0;
    
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
    
    const messagesCanvas = document.getElementById('chatMessages');
    messagesCanvas.innerHTML = `
        <div class="chat-bubble assistant animate-fade-in">
            <div class="bubble-avatar-img-container">
                <img src="/static/images/lina.png" class="bubble-avatar-img" alt="${currentAssistantName}">
            </div>
            <div class="bubble-body">
                <p>System initialized. I am <strong>${currentAssistantName}</strong> — your personal AI Workspace Assistant ⚡. How can I help you today, ${currentUserName}?</p>
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
        bubble.innerHTML = `
            <div class="bubble-avatar-img-container">
                <img src="/static/images/lina.png" class="bubble-avatar-img" alt="Lina">
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
    
    bubble.innerHTML = `
        <div class="bubble-avatar-img-container">
            <img src="/static/images/lina.png" class="bubble-avatar-img" alt="Lina">
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
