import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/services/api_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class AppState extends ChangeNotifier {
  bool _isAuthenticated = false;
  String? _token;
  String _phoneOrEmail = "";
  
  // Settings & Preferences
  String _currentModeOverride = "auto"; // "auto", "fugu", "odysseus"
  String _backendUrl = "http://localhost:8000";
  bool _isDarkTheme = true;

  // Explicit Settings & Permissions (Phase 2)
  String _tone = "formal";
  String _language = "hinglish";
  String _dashboardLanguage = "english";
  String _characterLanguage = "hinglish";
  double _hinglishRatio = 0.5;
  String _preferredLength = "medium";
  bool _permissionCalendar = false;
  bool _permissionEmail = false;
  bool _permissionLocation = false;
  bool _permissionBusiness = false;
  String _userName = "Aditya";
  String _assistantName = "Aadi AI";

  // Proactive & Task Automation Data (Phase 2)
  String _dailyBriefingText = "";
  List<dynamic> _reminders = [];
  List<dynamic> _activityLogs = [];
  List<dynamic> _pendingConfirmations = [];

  // Local message logs and memories
  List<Map<String, dynamic>> _chatMessages = [];
  List<dynamic> _memories = [];
  bool _isLoading = false;

  // Getters
  bool get isAuthenticated => _isAuthenticated;
  String? get token => _token;
  String get phoneOrEmail => _phoneOrEmail;
  String get currentModeOverride => _currentModeOverride;
  String get backendUrl => _backendUrl;
  bool get isDarkTheme => _isDarkTheme;
  List<Map<String, dynamic>> get chatMessages => _chatMessages;
  List<dynamic> get memories => _memories;
  bool get isLoading => _isLoading;

  // Phase 2 getters
  String get tone => _tone;
  String get language => _language;
  String get dashboardLanguage => _dashboardLanguage;
  String get characterLanguage => _characterLanguage;
  double get hinglishRatio => _hinglishRatio;
  String get preferredLength => _preferredLength;
  bool get permissionCalendar => _permissionCalendar;
  bool get permissionEmail => _permissionEmail;
  bool get permissionLocation => _permissionLocation;
  bool get permissionBusiness => _permissionBusiness;
  String get userName => _userName;
  String get assistantName => _assistantName;
  String get dailyBriefingText => _dailyBriefingText;
  List<dynamic> get reminders => _reminders;
  List<dynamic> get activityLogs => _activityLogs;
  List<dynamic> get pendingConfirmations => _pendingConfirmations;

  AppState() {
    _loadFromPreferences();
  }

  WebSocketChannel? _wsChannel;

  void connectWebSocket() {
    if (!_isAuthenticated || _token == null) return;
    try {
      _wsChannel?.sink.close();
      
      // Map http/https base URL to ws/wss protocols
      final wsUri = _backendUrl.replaceAll("http://", "ws://").replaceAll("https://", "wss://");
      final url = "$wsUri/api/proactive/ws?token=$_token";
      
      _wsChannel = WebSocketChannel.connect(Uri.parse(url));
      _wsChannel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            if (data["type"] == "daily_briefing") {
              _dailyBriefingText = data["briefing"] ?? "";
              notifyListeners();
            } else if (data["type"] == "traffic_warnings" || data["type"] == "traffic_warning") {
              _reminders = data["reminders"] ?? [];
              notifyListeners();
            }
          } catch (e) {
            print("Error parsing WebSocket message: $e");
          }
        },
        onError: (err) {
          print("WebSocket error: $err");
          Future.delayed(const Duration(seconds: 10), connectWebSocket);
        },
        onDone: () {
          print("WebSocket connection closed.");
          if (_isAuthenticated) {
            Future.delayed(const Duration(seconds: 10), connectWebSocket);
          }
        }
      );
    } catch (e) {
      print("WebSocket connect exception: $e");
    }
  }

  void disconnectWebSocket() {
    _wsChannel?.sink.close();
    _wsChannel = null;
  }

  Future<void> fetchChatHistory() async {
    final history = await apiService.getChatHistory(_token);
    if (history.isNotEmpty) {
      _chatMessages = List<Map<String, dynamic>>.from(history.map((m) => {
        "role": m["role"],
        "content": m["content"],
        "mode_used": m["mode_used"],
        "is_fallback": m["is_fallback"] ?? false,
        "timestamp": m["timestamp"] != null ? DateTime.parse(m["timestamp"]) : DateTime.now()
      }));
      notifyListeners();
    }
  }

  // Load state from local storage on startup
  Future<void> _loadFromPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString("token");
    _isAuthenticated = _token != null && _token!.isNotEmpty;
    _phoneOrEmail = prefs.getString("phoneOrEmail") ?? "";
    _currentModeOverride = prefs.getString("currentModeOverride") ?? "auto";
    _backendUrl = prefs.getString("backendUrl") ?? "http://localhost:8000";
    _isDarkTheme = prefs.getBool("isDarkTheme") ?? true;

    // Configure the ApiService base URL
    apiService.updateBaseUrl(_backendUrl);

    if (_isAuthenticated) {
      refreshUserData();
      connectWebSocket();
    }
    notifyListeners();
  }

  // Reloads all user data from API
  Future<void> refreshUserData() async {
    if (!_isAuthenticated) return;
    await fetchChatHistory();
    await fetchMemories();
    await fetchPreferences();
    await fetchDailyBriefing();
    await fetchReminders();
    await fetchActivityLogs();
    await fetchPendingConfirmations();
  }

  // Save specific configurations
  Future<void> setBackendUrl(String url) async {
    _backendUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("backendUrl", url);
    apiService.updateBaseUrl(url);
    notifyListeners();
  }

  Future<void> setModeOverride(String mode) async {
    _currentModeOverride = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("currentModeOverride", mode);
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkTheme = !_isDarkTheme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("isDarkTheme", _isDarkTheme);
    notifyListeners();
  }

  // Fetch Preferences
  Future<void> fetchPreferences() async {
    final data = await apiService.getPreferences(_token);
    if (data.isNotEmpty) {
      _tone = data["tone"] ?? "formal";
      _language = data["language"] ?? "hinglish";
      _dashboardLanguage = data["dashboard_language"] ?? "english";
      _characterLanguage = data["character_language"] ?? "hinglish";
      _hinglishRatio = (data["hinglish_ratio"] ?? 0.5).toDouble();
      _preferredLength = data["preferred_length"] ?? "medium";
      _permissionCalendar = data["permission_calendar"] ?? false;
      _permissionEmail = data["permission_email"] ?? false;
      _permissionLocation = data["permission_location"] ?? false;
      _permissionBusiness = data["permission_business"] ?? false;
      _userName = data["user_name"] ?? "Aditya";
      _assistantName = data["assistant_name"] ?? "Aadi AI";
      notifyListeners();
    }
  }

  // Update Preferences
  Future<void> updatePreferenceSetting({
    String? toneSetting,
    String? langSetting,
    String? dashboardLangSetting,
    String? characterLangSetting,
    bool? permCalendar,
    bool? permEmail,
    bool? permLocation,
    bool? permBusiness,
    String? userNameSetting,
    String? assistantNameSetting,
  }) async {
    final Map<String, dynamic> body = {};
    if (toneSetting != null) body["tone"] = toneSetting;
    if (langSetting != null) body["language"] = langSetting;
    if (dashboardLangSetting != null) body["dashboard_language"] = dashboardLangSetting;
    if (characterLangSetting != null) body["character_language"] = characterLangSetting;
    if (permCalendar != null) body["permission_calendar"] = permCalendar;
    if (permEmail != null) body["permission_email"] = permEmail;
    if (permLocation != null) body["permission_location"] = permLocation;
    if (permBusiness != null) body["permission_business"] = permBusiness;
    if (userNameSetting != null) body["user_name"] = userNameSetting;
    if (assistantNameSetting != null) body["assistant_name"] = assistantNameSetting;

    final data = await apiService.updatePreferences(body, _token);
    if (data.isNotEmpty) {
      _tone = data["tone"] ?? _tone;
      _language = data["language"] ?? _language;
      _dashboardLanguage = data["dashboard_language"] ?? _dashboardLanguage;
      _characterLanguage = data["character_language"] ?? _characterLanguage;
      _hinglishRatio = (data["hinglish_ratio"] ?? _hinglishRatio).toDouble();
      _preferredLength = data["preferred_length"] ?? _preferredLength;
      _permissionCalendar = data["permission_calendar"] ?? _permissionCalendar;
      _permissionEmail = data["permission_email"] ?? _permissionEmail;
      _permissionLocation = data["permission_location"] ?? _permissionLocation;
      _permissionBusiness = data["permission_business"] ?? _permissionBusiness;
      _userName = data["user_name"] ?? _userName;
      _assistantName = data["assistant_name"] ?? _assistantName;
      notifyListeners();
    }
  }

  // Fetch Daily Briefing
  Future<void> fetchDailyBriefing() async {
    final response = await apiService.getDailyBriefing(_token);
    if (response["status"] == "success") {
      _dailyBriefingText = response["briefing"] ?? "";
    } else {
      _dailyBriefingText = response["briefing"] ?? "Daily brief failed.";
    }
    notifyListeners();
  }

  // Fetch Reminders
  Future<void> fetchReminders() async {
    _reminders = await apiService.getReminders(_token);
    notifyListeners();
  }

  // Fetch Activity Log
  Future<void> fetchActivityLogs() async {
    _activityLogs = await apiService.getActivityLogs(_token);
    notifyListeners();
  }

  // Fetch Pending Confirmations
  Future<void> fetchPendingConfirmations() async {
    _pendingConfirmations = await apiService.getPendingConfirmations(_token);
    notifyListeners();
  }

  // Approve/Deny Confirmation Gate item
  Future<bool> handleConfirmationGate(int actionId, bool approve) async {
    _isLoading = true;
    notifyListeners();
    final result = await apiService.handleConfirmationAction(actionId, approve, _token);
    _isLoading = false;
    
    if (result["status"] == "success") {
      _pendingConfirmations.removeWhere((item) => item["id"] == actionId);
      await fetchActivityLogs();
      await fetchReminders();
      notifyListeners();
      return true;
    }
    notifyListeners();
    return false;
  }

  // Auth operations
  Future<Map<String, dynamic>> triggerOTP(String phoneOrEmail) async {
    _isLoading = true;
    notifyListeners();
    final result = await apiService.requestOTP(phoneOrEmail);
    _isLoading = false;
    notifyListeners();
    return result;
  }

  Future<Map<String, dynamic>> verifyAndLogin(String phoneOrEmail, String otp) async {
    _isLoading = true;
    notifyListeners();
    final result = await apiService.verifyOTP(phoneOrEmail, otp);
    _isLoading = false;
    
    if (result["status"] == "success") {
      _token = result["token"];
      _isAuthenticated = true;
      _phoneOrEmail = phoneOrEmail;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("token", _token!);
      await prefs.setString("phoneOrEmail", phoneOrEmail);
      
      // Load user specifics
      await refreshUserData();
      connectWebSocket();
      
      // Add welcome greeting message to local chat log
      _chatMessages.add({
        "role": "assistant",
        "content": translate("welcome_back"),
        "mode_used": "odysseus",
        "is_fallback": false,
        "timestamp": DateTime.now()
      });
    }
    notifyListeners();
    return result;
  }

  Future<void> logout() async {
    disconnectWebSocket();
    _token = null;
    _isAuthenticated = false;
    _phoneOrEmail = "";
    _chatMessages.clear();
    _memories.clear();
    _dailyBriefingText = "";
    _reminders.clear();
    _activityLogs.clear();
    _pendingConfirmations.clear();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("token");
    await prefs.remove("phoneOrEmail");
    notifyListeners();
  }

  // Chat interaction
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // 1. Add user message locally
    final userMsg = {
      "role": "user",
      "content": text,
      "timestamp": DateTime.now()
    };
    _chatMessages.add(userMsg);
    _isLoading = true;
    notifyListeners();

    // 2. Transmit to backend
    final response = await apiService.sendChatMessage(text, _currentModeOverride, _token);
    
    // 3. Add assistant response locally
    _chatMessages.add({
      "role": "assistant",
      "content": response["response"] ?? "Something went wrong.",
      "mode_used": response["mode_used"] ?? "odysseus",
      "is_fallback": response["is_fallback"] ?? false,
      "timestamp": DateTime.now()
    });

    // 4. Refresh activity log, briefings, and confirmations in background (Phase 2 sync)
    await fetchPendingConfirmations();
    await fetchActivityLogs();
    await fetchReminders();

    _isLoading = false;
    notifyListeners();
  }

  // Memory operations
  Future<void> fetchMemories() async {
    _memories = await apiService.getMemories(_token);
    notifyListeners();
  }

  Future<bool> addNewMemory(String fact) async {
    final result = await apiService.addMemory(fact, _token);
    if (result != null) {
      _memories.add(result);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> deleteOldMemory(int id) async {
    final success = await apiService.deleteMemory(id, _token);
    if (success) {
      _memories.removeWhere((item) => item["id"] == id);
      notifyListeners();
      return true;
    }
    return false;
  }

  // Localization dictionary for the 7 languages
  static const Map<String, Map<String, String>> _localizedStrings = {
    "english": {
      "settings_title": "Settings & Controls",
      "routing_modes": "Assistant Routing Modes",
      "smart_router": "Smart Router (Auto)",
      "smart_router_sub": "Automatically routes based on query complexity and internet speed.",
      "fugu_mode": "Fugu Mode Only (Cloud)",
      "fugu_mode_sub": "Forces all reasoning to Claude API (Requires internet).",
      "odysseus_mode": "Odysseus Mode Only (Local)",
      "odysseus_mode_sub": "Forces all queries to local Ollama. Private and offline.",
      "profile_header": "Profile & Assistant Personalization",
      "your_name": "Your Name",
      "your_name_hint": "What should the assistant call you?",
      "assistant_name": "Assistant Name",
      "assistant_name_hint": "What would you like to name the assistant?",
      "save_names": "Save Custom Names",
      "ai_style_header": "Explicit AI Personality & Style",
      "assistant_tone": "Assistant Tone",
      "char_lang": "3D Character Language",
      "dash_lang": "Dashboard UI Language",
      "implicit_ratio": "Hinglish Implicit Ratio",
      "implicit_ratio_sub": "Learned Hinglish speech pattern mix",
      "security_header": "Granular Security Toggles",
      "cal_sync": "Google Calendar Sync",
      "cal_sync_sub": "Allow Aadi to view and schedule calendar events.",
      "gmail_access": "Gmail Access",
      "gmail_access_sub": "Allow Aadi to draft email replies and read inbox.",
      "loc_alerts": "Real-time Location Alerts",
      "loc_alerts_sub": "Allow location access for traffic adjusted reminders.",
      "business_sync": "Business Orders Sync",
      "business_sync_sub": "Allow accessing e-commerce shipment and logistics data.",
      "backend_header": "FastAPI Backend Connection",
      "backend_url": "Backend Base URL",
      "save_url": "Save URL",
      "pref_header": "Preferences",
      "dark_mode": "Dark Theme Mode",
      "memory_profile": "User Memory Profile",
      "logout": "Logout Session",
      "facts_count": "facts remembered",
      "facts_total": "facts total",
      "memory_title": "Memory Profile",
      "namaste": "Namaste",
      "memory_desc": "I remember all your preferences and details to make my replies personalized.",
      "add_details": "Add details about yourself:",
      "add_details_hint": "e.g., I live in New Delhi or I prefer coffee",
      "remembered_facts": "Remembered Facts",
      "no_memory": "No memory data found.",
      "tell_aadi": "Tell Aadi your preferences to start saving context!",
      "new_context_saved": "New context saved to memory.",
      "failed_save_memory": "Failed to save memory. Check backend.",
      "memory_deleted": "Memory deleted.",
      "url_updated": "Backend URL updated to:",
      "names_updated": "Names updated successfully!",
      "mic_recording": "🎙️ Recording started... Speak now!",
      "mic_denied": "⚠️ Microphone permission denied.",
      "transcribing": "⚡ Transcribing audio pipeline...",
      "daily_brief_card": "DAILY INTEL BRIEFING",
      "refresh_brief": "Refresh Brief",
      "listening_mic": "Listening... Speak now",
      "actions_card": "PENDING AUTOMATIONS",
      "confirm_action": "Needs Confirmation",
      "approve_btn": "Approve",
      "deny_btn": "Deny",
      "no_brief": "Daily Briefing not compiled yet.",
      "no_actions": "No pending actions requiring approval.",
      "activity_log_btn": "Audit Logs",
      "activity_log_title": "System Activity & Audit Logs",
      "no_logs": "No activity logs recorded.",
      "status": "Status",
      "explanation": "Explanation",
      "system_audit": "System Audit",
      "welcome_back": "Welcome back! Main aapka assistant Aadi AI hoon. How can I help you today?"
    },
    "hinglish": {
      "settings_title": "Settings & Controls",
      "routing_modes": "Assistant Routing Modes",
      "smart_router": "Smart Router (Auto)",
      "smart_router_sub": "Query complexity ke basis par auto-route karega.",
      "fugu_mode": "Fugu Mode Only (Cloud)",
      "fugu_mode_sub": "Saare queries cloud AI ko bhejega (Internet chahiye).",
      "odysseus_mode": "Odysseus Mode Only (Local)",
      "odysseus_mode_sub": "Local mind use karega (Offline & Private).",
      "profile_header": "Profile & Assistant Personalization",
      "your_name": "Aapka Naam",
      "your_name_hint": "Assistant aapko kya kehkar bulaye?",
      "assistant_name": "Assistant Ka Naam",
      "assistant_name_hint": "Aap assistant ko kya naam dena chahte hain?",
      "save_names": "Custom Names Save Karein",
      "ai_style_header": "Explicit AI Personality & Style",
      "assistant_tone": "Assistant Ka Tone",
      "char_lang": "3D Character Ki Language",
      "dash_lang": "Dashboard Ki Language",
      "implicit_ratio": "Hinglish Ka Implicit Ratio",
      "implicit_ratio_sub": "Aapke bolne ke style ka mix ratio",
      "security_header": "Granular Security Toggles",
      "cal_sync": "Google Calendar Sync",
      "cal_sync_sub": "Aadi ko calendar events check aur schedule karne dein.",
      "gmail_access": "Gmail Access",
      "gmail_access_sub": "Aadi ko emails read aur draft karne dein.",
      "loc_alerts": "Real-time Location Alerts",
      "loc_alerts_sub": "Traffic aur location warnings ke liye access dein.",
      "business_sync": "Business Orders Sync",
      "business_sync_sub": "Flipkart aur Amazon packages trace karne dein.",
      "backend_header": "FastAPI Backend Connection",
      "backend_url": "Backend Base URL",
      "save_url": "URL Save Karein",
      "pref_header": "Preferences",
      "dark_mode": "Dark Theme Mode",
      "memory_profile": "User Memory Profile",
      "logout": "Session Logout Karein",
      "facts_count": "baatein yaad hain",
      "facts_total": "baatein total",
      "memory_title": "Memory Profile",
      "namaste": "Namaste",
      "memory_desc": "Main aapki saari preferences yaad rakhta hoon taaki replies personalized hon.",
      "add_details": "Apne baare me details add karein:",
      "add_details_hint": "Jaise, Main New Delhi me rehta hoon ya Mujhe chai pasand hai",
      "remembered_facts": "Yaad Rakhi Gayi Baatein",
      "no_memory": "Koyi memory data nahi mila.",
      "tell_aadi": "Aadi ko apni preferences batana shuru karein!",
      "new_context_saved": "Nayi baat memory me save ho gayi.",
      "failed_save_memory": "Memory save nahi ho payi. Backend check karein.",
      "memory_deleted": "Memory delete ho gayi.",
      "url_updated": "Backend URL update ho gaya:",
      "names_updated": "Naam successfully update ho gaye!",
      "mic_recording": "🎙️ Recording chalu hai... Boliye!",
      "mic_denied": "⚠️ Microphone permission nahi mili.",
      "transcribing": "⚡ Voice recognize ho rahi hai...",
      "daily_brief_card": "DAILY INTEL BRIEFING",
      "refresh_brief": "Brief Refresh Karein",
      "listening_mic": "Suno, main sun raha hoon... Speak now",
      "actions_card": "PENDING AUTOMATIONS",
      "confirm_action": "Confirmation Chahiye",
      "approve_btn": "Approve",
      "deny_btn": "Deny",
      "no_brief": "Daily Briefing abhi tak compile nahi hui.",
      "no_actions": "Approval ke liye koyi pending action nahi hai.",
      "activity_log_btn": "Audit Logs",
      "activity_log_title": "System Activity & Audit Logs",
      "no_logs": "Koyi activity log nahi hai.",
      "status": "Status",
      "explanation": "Explanation",
      "system_audit": "System Audit",
      "welcome_back": "Welcome back! Main aapka assistant Aadi AI hoon. Main aapki kya help kar sakta hoon?"
    },
    "hindi": {
      "settings_title": "सेटिंग्स और नियंत्रण",
      "routing_modes": "असिस्टेंट राउटिंग मोड",
      "smart_router": "स्मार्ट राउटर (स्वचालित)",
      "smart_router_sub": "जटिलता और इंटरनेट स्पीड के आधार पर ऑटो-रूट करता है।",
      "fugu_mode": "केवल फुगु मोड (क्लाउड)",
      "fugu_mode_sub": "सभी प्रश्नों को क्लाउड एआई पर भेजता है (इंटरनेट आवश्यक)।",
      "odysseus_mode": "केवल ओडिसियस मोड (स्थानीय)",
      "odysseus_mode_sub": "स्थानीय सर्वर का उपयोग करता है (ऑफ़लाइन और निजी)।",
      "profile_header": "प्रोफ़ाइल और असिस्टेंट वैयक्तिकरण",
      "your_name": "आपका नाम",
      "your_name_hint": "असिस्टेंट आपको क्या कहकर बुलाए?",
      "assistant_name": "असिस्टेंट का नाम",
      "assistant_name_hint": "आप असिस्टेंट को क्या नाम देना चाहेंगे?",
      "save_names": "कस्टम नाम सहेजें",
      "ai_style_header": "एआई व्यक्तित्व और शैली",
      "assistant_tone": "असिस्टेंट का टोन",
      "char_lang": "3D कैरेक्टर की भाषा",
      "dash_lang": "डैशबोर्ड की भाषा",
      "implicit_ratio": "हिंग्लिश का अनुपात",
      "implicit_ratio_sub": "सीखा हुआ हिंग्लिश भाषण पैटर्न मिश्रण",
      "security_header": "सुरक्षा सेटिंग्स",
      "cal_sync": "गूगल कैलेंडर सिंक",
      "cal_sync_sub": "आदि को कैलेंडर देखने और शेड्यूल करने की अनुमति दें।",
      "gmail_access": "जीमेल एक्सेस",
      "gmail_access_sub": "आदि को ईमेल ड्राफ्ट करने और पढ़ने की अनुमति दें।",
      "loc_alerts": "वास्तविक समय स्थान अलर्ट",
      "loc_alerts_sub": "यातायात अलर्ट के लिए स्थान की अनुमति दें।",
      "business_sync": "व्यावसायिक ऑर्डर सिंक",
      "business_sync_sub": "ई-कॉमर्स शिपमेंट डेटा देखने की अनुमति दें।",
      "backend_header": "FastAPI बैकएंड कनेक्शन",
      "backend_url": "बैकएंड बेस यूआरएल",
      "save_url": "यूआरएल सहेजें",
      "pref_header": "प्राथमिकताएं",
      "dark_mode": "डार्क थीम मोड",
      "memory_profile": "उपयोगकर्ता मेमोरी प्रोफ़ाइल",
      "logout": "सत्र लॉग आउट करें",
      "facts_count": "तथ्य याद रखे गए",
      "facts_total": "कुल तथ्य",
      "memory_title": "मेमोरी प्रोफ़ाइल",
      "namaste": "नमस्ते",
      "memory_desc": "मैं आपकी सभी प्राथमिकताओं को याद रखता हूं ताकि उत्तर व्यक्तिगत हों।",
      "add_details": "अपने बारे में विवरण जोड़ें:",
      "add_details_hint": "उदा. मैं नई दिल्ली में रहता हूँ या मुझे कॉफ़ी पसंद है",
      "remembered_facts": "याद रखे गए तथ्य",
      "no_memory": "कोई मेमोरी डेटा नहीं मिला।",
      "tell_aadi": "मेमोरी सहेजने के लिए आदि को अपनी प्राथमिकताएं बताएं!",
      "new_context_saved": "नया तथ्य मेमोरी में सहेजा गया।",
      "failed_save_memory": "मेमोरी सहेजने में विफल। बैकएंड जांचें।",
      "memory_deleted": "मेमोरी हटा दी गई।",
      "url_updated": "बैकएंड यूआरएल अपडेट किया गया:",
      "names_updated": "नाम सफलतापूर्वक अपडेट किए गए!",
      "mic_recording": "🎙️ रिकॉर्डिंग चालू है... बोलिए!",
      "mic_denied": "⚠️ माइक्रोफ़ोन की अनुमति नहीं दी गई।",
      "transcribing": "⚡ आवाज़ पहचानी जा रही है...",
      "daily_brief_card": "दैनिक ब्रीफिंग",
      "refresh_brief": "ब्रीफ रीफ्रेश करें",
      "listening_mic": "सुन रहा हूँ... बोलिए",
      "actions_card": "लंबित कार्य",
      "confirm_action": "पुष्टि की आवश्यकता है",
      "approve_btn": "स्वीकार करें",
      "deny_btn": "अस्वीकार करें",
      "no_brief": "दैनिक ब्रीफिंग अभी उपलब्ध नहीं है।",
      "no_actions": "स्वीकृति के लिए कोई लंबित कार्य नहीं है।",
      "activity_log_btn": "ऑडिट लॉग्स",
      "activity_log_title": "सिस्टम गतिविधि और ऑडिट लॉग",
      "no_logs": "कोई गतिविधि दर्ज नहीं की गई।",
      "status": "स्थिति",
      "explanation": "स्पष्टीकरण",
      "system_audit": "सिस्टम ऑडिट",
      "welcome_back": "स्वागत है! मैं आपका सहायक आदि एआई हूँ। मैं आज आपकी क्या सहायता कर सकता हूँ?"
    },
    "german": {
      "settings_title": "Einstellungen & Steuerung",
      "routing_modes": "Assistenten-Routing-Modi",
      "smart_router": "Intelligenter Router (Auto)",
      "smart_router_sub": "Routet automatisch basierend auf Abfragekomplexität und Geschwindigkeit.",
      "fugu_mode": "Nur Fugu-Modus (Cloud)",
      "fugu_mode_sub": "Leitet alle Anfragen an die Claude API weiter (Internet erforderlich).",
      "odysseus_mode": "Nur Odysseus-Modus (Lokal)",
      "odysseus_mode_sub": "Nutzt lokales Ollama. Privat und offline.",
      "profile_header": "Profil- & Assistenten-Personalisierung",
      "your_name": "Ihr Name",
      "your_name_hint": "Wie soll der Assistent Sie nennen?",
      "assistant_name": "Name des Assistenten",
      "assistant_name_hint": "Wie möchten Sie den Assistenten nennen?",
      "save_names": "Namen speichern",
      "ai_style_header": "KI-Persönlichkeit & Stil",
      "assistant_tone": "Assistenten-Ton",
      "char_lang": "3D-Charaktersprache",
      "dash_lang": "Dashboard-Sprache",
      "implicit_ratio": "Implizites Hinglish-Verhältnis",
      "implicit_ratio_sub": "Erlernter Sprachmuster-Mix",
      "security_header": "Sicherheitseinstellungen",
      "cal_sync": "Google Kalender Synchronisierung",
      "cal_sync_sub": "Erlaubt Aadi Kalendertermine zu lesen und zu planen.",
      "gmail_access": "Gmail-Zugriff",
      "gmail_access_sub": "Erlaubt Aadi E-Mail-Entwürfe zu schreiben und zu lesen.",
      "loc_alerts": "Echtzeit-Standortwarnungen",
      "loc_alerts_sub": "Standortzugriff für verkehrsabhängige Erinnerungen erlauben.",
      "business_sync": "Bestellungen Synchronisieren",
      "business_sync_sub": "Zugriff auf Paket- und E-Commerce-Logistikdaten erlauben.",
      "backend_header": "FastAPI-Backend-Verbindung",
      "backend_url": "Backend-Basis-URL",
      "save_url": "URL speichern",
      "pref_header": "Präferenzen",
      "dark_mode": "Dunkler Modus",
      "memory_profile": "Speicherprofil",
      "logout": "Abmelden",
      "facts_count": "Fakten gemerkt",
      "facts_total": "Fakten insgesamt",
      "memory_title": "Speicherprofil",
      "namaste": "Hallo",
      "memory_desc": "Ich merke mir Ihre Vorlieben, um meine Antworten zu personalisieren.",
      "add_details": "Fügen Sie Details über sich hinzu:",
      "add_details_hint": "z.B. Ich wohne in Berlin oder Ich mag Kaffee",
      "remembered_facts": "Gemerktes Wissen",
      "no_memory": "Keine gespeicherten Daten gefunden.",
      "tell_aadi": "Teilen Sie Aadi Ihre Vorlieben mit, um Daten zu speichern!",
      "new_context_saved": "Neuer Kontext im Speicher abgelegt.",
      "failed_save_memory": "Fehler beim Speichern. Backend prüfen.",
      "memory_deleted": "Wissen gelöscht.",
      "url_updated": "Backend-URL aktualisiert auf:",
      "names_updated": "Namen erfolgreich aktualisiert!",
      "mic_recording": "🎙️ Aufnahme läuft... Sprechen Sie jetzt!",
      "mic_denied": "⚠️ Mikrofonberechtigung verweigert.",
      "transcribing": "⚡ Sprache wird transkribiert...",
      "daily_brief_card": "TÄGLICHER BERICHT",
      "refresh_brief": "Bericht aktualisieren",
      "listening_mic": "Ich höre zu... Bitte sprechen",
      "actions_card": "AUSSTEHENDE AUTOMATIONEN",
      "confirm_action": "Bestätigung erforderlich",
      "approve_btn": "Erlauben",
      "deny_btn": "Ablehnen",
      "no_brief": "Täglicher Bericht noch nicht erstellt.",
      "no_actions": "Keine ausstehenden Aktionen.",
      "activity_log_btn": "Aktivitätsprotokoll",
      "activity_log_title": "System- & Aktivitätsprotokolle",
      "no_logs": "Keine Protokolle vorhanden.",
      "status": "Status",
      "explanation": "Erklärung",
      "system_audit": "System-Audit",
      "welcome_back": "Willkommen zurück! Ich bin dein Assistent Aadi AI. Wie kann ich dir heute helfen?"
    },
    "chinese": {
      "settings_title": "系统设置与控制",
      "routing_modes": "助理路由模式",
      "smart_router": "智能路由器 (自动)",
      "smart_router_sub": "根据网络和复杂度自动选择路由方式。",
      "fugu_mode": "仅限 Fugu 模式 (云端)",
      "fugu_mode_sub": "强制所有问题提交给 Claude API (需要网络)。",
      "odysseus_mode": "仅限 Odysseus 模式 (本地)",
      "odysseus_mode_sub": "强制使用本地 Ollama。私密且可离线使用。",
      "profile_header": "个人资料与助理个性化",
      "your_name": "您的名字",
      "your_name_hint": "助理应该如何称呼您？",
      "assistant_name": "助理名字",
      "assistant_name_hint": "您想给助理起什么名字？",
      "save_names": "保存自定义名字",
      "ai_style_header": "AI 个性与风格",
      "assistant_tone": "助理语气",
      "char_lang": "3D 角色语言",
      "dash_lang": "仪表盘 UI 语言",
      "implicit_ratio": "Hinglish 隐含比例",
      "implicit_ratio_sub": "已学习的混合语言说话模式比例",
      "security_header": "细粒度安全开关",
      "cal_sync": "谷歌日历同步",
      "cal_sync_sub": "允许 Aadi 查看并安排日历日程。",
      "gmail_access": "Gmail 访问权限",
      "gmail_access_sub": "允许 Aadi 起草邮件并读取收件箱。",
      "loc_alerts": "实时位置警报",
      "loc_alerts_sub": "允许为了交通延误提醒而获取位置。",
      "business_sync": "商业订单同步",
      "business_sync_sub": "允许读取电商包裹及零售物流数据。",
      "backend_header": "FastAPI 后端连接",
      "backend_url": "后端基准 URL",
      "save_url": "保存 URL",
      "pref_header": "偏好设置",
      "dark_mode": "深色主题模式",
      "memory_profile": "记忆中心",
      "logout": "退出当前登录",
      "facts_count": "条记忆已保存",
      "facts_total": "总事实数",
      "memory_title": "记忆中心",
      "namaste": "你好",
      "memory_desc": "我会记住您所有的偏好和细节，让回复更具个性化。",
      "add_details": "添加关于您的细节：",
      "add_details_hint": "例如：我住在新德里，或者我喜欢喝咖啡",
      "remembered_facts": "已保存的事实",
      "no_memory": "未发现记忆数据。",
      "tell_aadi": "开始告诉 Aadi 您的偏好吧！",
      "new_context_saved": "新事实已保存至记忆。",
      "failed_save_memory": "保存记忆失败。请检查后端。",
      "memory_deleted": "记忆已删除。",
      "url_updated": "后端 URL 已更新为：",
      "names_updated": "名字更新成功！",
      "mic_recording": "🎙️ 正在录音... 请开始说话！",
      "mic_denied": "⚠️ 麦克风权限被拒绝。",
      "transcribing": "⚡ 正在语音转写...",
      "daily_brief_card": "每日资讯简报",
      "refresh_brief": "刷新简报",
      "listening_mic": "正在倾听... 请说话",
      "actions_card": "待处理自动任务",
      "confirm_action": "需要确认",
      "approve_btn": "批准",
      "deny_btn": "拒绝",
      "no_brief": "每日简报尚未生成。",
      "no_actions": "没有需要批准的待处理任务。",
      "activity_log_btn": "审计日志",
      "activity_log_title": "系统活动与审计日志",
      "no_logs": "无记录的活动日志。",
      "status": "状态",
      "explanation": "详细解释",
      "system_audit": "系统审计",
      "welcome_back": "欢迎回来！我是您的助理 Aadi AI。今天有什么我可以帮您的？"
    },
    "bhojpuri": {
      "settings_title": "सेटिंग अउर नियंत्रण",
      "routing_modes": "असिस्टेंट राउटिंग मोड",
      "smart_router": "स्मार्ट राउटर (अपने से)",
      "smart_router_sub": "काम के हिसाब से राउटर अपने से रस्ता चुनी।",
      "fugu_mode": "सिर्फ फुगु मोड (क्लाउड)",
      "fugu_mode_sub": "सभ सवाल क्लाउड एआई के भेजल जाई (नेट चाही)।",
      "odysseus_mode": "सिर्फ ओडिसियस मोड (लोकल)",
      "odysseus_mode_sub": "लोकल कंप्यूटर पर काम करी (ऑफ़लाइन अउर प्राइवेट)।",
      "profile_header": "प्रोफाइल अउर असिस्टेंट निजीकरण",
      "your_name": "रउआ नाम",
      "your_name_hint": "असिस्टेंट रउआ का कह के बुलाई?",
      "assistant_name": "असिस्टेंट के नाम",
      "assistant_name_hint": "रउआ असिस्टेंट के का नाम रखल चाहत बानी?",
      "save_names": "कस्टम नाम सहेजें",
      "ai_style_header": "एआई के बोली अउर विचार",
      "assistant_tone": "असिस्टेंट के टोन",
      "char_lang": "3D कैरेक्टर के भाषा",
      "dash_lang": "डैशबोर्ड के भाषा",
      "implicit_ratio": "हिंग्लिश के अनुपात",
      "implicit_ratio_sub": "हिंग्लिश बोले के तरीका के मेल",
      "security_header": "सुरक्षा सेटिंग्स",
      "cal_sync": "गूगल कैलेंडर सिंक",
      "cal_sync_sub": "आदि के कैलेंडर देखे अउर मीटिंग तय करे के अनुमति दीं।",
      "gmail_access": "जीमेल एक्सेस",
      "gmail_access_sub": "आदि के ईमेल लिखे अउर पढ़े के अनुमति दीं।",
      "loc_alerts": "तुरंत के स्थान अलर्ट",
      "loc_alerts_sub": "जाम के अलर्ट खातिर स्थान के अनुमति दीं।",
      "business_sync": "बिज़नेस ऑर्डर सिंक",
      "business_sync_sub": "ऑनलाइन ऑर्डर के जानकारी देखे के अनुमति दीं।",
      "backend_header": "FastAPI बैकएंड कनेक्शन",
      "backend_url": "बैकएंड बेस यूआरएल",
      "save_url": "यूआरएल सहेजीं",
      "pref_header": "पसंद-नापसंद",
      "dark_mode": "अँजोर-अँधेरिया मोड",
      "memory_profile": "याददाश्त प्रोफाइल",
      "logout": "सत्र बंद करीं",
      "facts_count": "बात याद बा",
      "facts_total": "कुल बात",
      "memory_title": "याददाश्त प्रोफाइल",
      "namaste": "प्रणाम",
      "memory_desc": "हम रउआ सभ बात याद रखिला जेसे रउआ नीक जबाव मिल सके।",
      "add_details": "अपने बारे में जानकारी जोड़ीं:",
      "add_details_hint": "जैसे: हम नई दिल्ली में रहिला चाहे हमरा कॉफी पसंद बा",
      "remembered_facts": "याद रखल गईल बात",
      "no_memory": "कवनो याददाश्त के डेटा ना मिलल।",
      "tell_aadi": "बात सहेजे खातिर आदि के अपनी पसंद बताईं!",
      "new_context_saved": "नया जानकारी याददाश्त में सहेज लिहल गइल।",
      "failed_save_memory": "जानकारी सहेजे में दिक्कत भइल। बैकएंड जांची।",
      "memory_deleted": "जानकारी हटा देवल गइल।",
      "url_updated": "बैकएंड यूआरएल बदल गइल बा:",
      "names_updated": "नाम सफलता से बदल गइल!",
      "mic_recording": "🎙️ रिकॉर्डिंग चालू बा... बोलीं!",
      "mic_denied": "⚠️ माइक्रोफोन के अनुमति ना मिलल।",
      "transcribing": "⚡ आवाज़ पहिचानल जात बा...",
      "daily_brief_card": "आजु के समाचार",
      "refresh_brief": "समाचार ताजा करीं",
      "listening_mic": "सुनात बानी... बोलीं",
      "actions_card": "बाकी काम",
      "confirm_action": "मंजूरी चाही",
      "approve_btn": "मंजूर करीं",
      "deny_btn": "मना करीं",
      "no_brief": "आजु के समाचार अभी तैयार नईखे।",
      "no_actions": "मंजूरी खातिर कवनो काम बाकी नईखे।",
      "activity_log_btn": "ऑडिट लॉग",
      "activity_log_title": "सिस्टम के काम अउर ऑडिट लॉग",
      "no_logs": "कवनो काम के रिकॉर्ड नईखे।",
      "status": "हाल",
      "explanation": "विवरण",
      "system_audit": "सिस्टम ऑडिट",
      "welcome_back": "प्रणाम! हम रउआ सहायक आदि एआई हईं। आज रउआ का मदद करीं?"
    },
    "maithili": {
      "settings_title": "सेटिंग आ नियंत्रण",
      "routing_modes": "असिस्टेंट राउटिंग मोड",
      "smart_router": "स्मार्ट राउटर (स्वचालित)",
      "smart_router_sub": "कमजोरी आ गति के हिसाब सँ राउटर अपने काज करत।",
      "fugu_mode": "सिर्फ फुगु मोड (क्लाउड)",
      "fugu_mode_sub": "सभ काज क्लाउड एआई के भेजल जाएत (इंटरनेट आवश्यक)।",
      "odysseus_mode": "सिर्फ ओडिसियस मोड (स्थानीय)",
      "odysseus_mode_sub": "स्थानीय सर्वर पर काज करी (गोपनीय आ ऑफ़लाइन)।",
      "profile_header": "प्रोफाइल आ असिस्टेंट वैयक्तिकरण",
      "your_name": "अहाँक नाम",
      "your_name_hint": "असिस्टेंट अहाँ के की कहि क' बाजत?",
      "assistant_name": "असिस्टेंटक नाम",
      "assistant_name_hint": "अहाँ असिस्टेंट के की नाम देबऽ चाहैत छी?",
      "save_names": "नाम सुरक्षित करू",
      "ai_style_header": "एआई व्यक्तित्व आ शैली",
      "assistant_tone": "असिस्टेंटक टोन",
      "char_lang": "3D पात्रक भाषा",
      "dash_lang": "डैशबोर्डक भाषा",
      "implicit_ratio": "हिंग्लिशक अनुपात",
      "implicit_ratio_sub": "सीखल हिंग्लिश बोलीक अनुपात",
      "security_header": "सुरक्षा सेटिंग्स",
      "cal_sync": "गूगल कैलेंडर सिंक",
      "cal_sync_sub": "आदि के कैलेंडर देखबाक आ बैठक तय करबाक अनुमति दियौक।",
      "gmail_access": "जीमेलक पहुँच",
      "gmail_access_sub": "आदि के ईमेल लिखबाक आ पढ़बाक अनुमति दियौक।",
      "loc_alerts": "तुरंतक स्थान अलर्ट",
      "loc_alerts_sub": "जामक जानकारी लेल स्थानक अनुमति दियौक।",
      "business_sync": "व्यावसायिक ऑर्डर सिंक",
      "business_sync_sub": "ऑर्डरक स्थिति देखबाक अनुमति दियौक।",
      "backend_header": "FastAPI बैकएंड कनेक्शन",
      "backend_url": "बैकएंड बेस यूआरएल",
      "save_url": "यूआरएल सुरक्षित करू",
      "pref_header": "प्राथमिकता सभ",
      "dark_mode": "डार्क थीम मोड",
      "memory_profile": "याददाश्त प्रोफाइल",
      "logout": "सत्र बंद करू",
      "facts_count": "तथ्य याद अछि",
      "facts_total": "कुल तथ्य",
      "memory_title": "याददाश्त प्रोफाइल",
      "namaste": "प्रणाम",
      "memory_desc": "हम अहाँक सभ पसंद याद रखैत छी जाहि सँ उत्तर व्यक्तिगत होय।",
      "add_details": "अपनेक बारे में जानकारी जोड़ू:",
      "add_details_hint": "जैसे: हम दिल्ली में रहैत छी वा हमरा काफी नीक लगैत अछि",
      "remembered_facts": "याद रखल गेल तथ्य सभ",
      "no_memory": "कोनो याददाश्तक डेटा नै भेटल।",
      "tell_aadi": "बात सुरक्षित करबाक लेल आदि के प्राथमिकता बताओ!",
      "new_context_saved": "नूतन तथ्य याददाश्त में सुरक्षित कयल गेल।",
      "failed_save_memory": "तथ्य सुरक्षित करबा में असफल। बैकएंड जाँकू।",
      "memory_deleted": "तथ्य हटा देल गेल।",
      "url_updated": "बैकएंड यूआरएल बदलल गेल:",
      "names_updated": "नाम सफलतापूर्वक बदलल गेल!",
      "mic_recording": "🎙️ रिकॉर्डिंग चालू अछि... बाजू!",
      "mic_denied": "⚠️ माइक्रोफोनक अनुमति नै भेटल।",
      "transcribing": "⚡ आवाज़ चिनहल जा रहल अछि...",
      "daily_brief_card": "दैनिक समाचार",
      "refresh_brief": "विवरण रीफ्रेश करू",
      "listening_mic": "सुनि रहल छी... बाजू",
      "actions_card": "बाकी काज सभ",
      "confirm_action": "मंजूरीक आवश्यकता अछि",
      "approve_btn": "मंजूर करू",
      "deny_btn": "मना करू",
      "no_brief": "दैनिक समाचार अखन उपलब्ध नै अछि।",
      "no_actions": "मंजूरी लेल कोनो काज लंबित नै अछि।",
      "activity_log_btn": "ऑडिट लॉग",
      "activity_log_title": "सिस्टमक काज आ ऑडिट लॉग",
      "no_logs": "कोनो काजक रिकॉर्ड नै अछि।",
      "status": "हाल",
      "explanation": "विवरण",
      "system_audit": "सिस्टम ऑडिट",
      "welcome_back": "प्रणाम! हम अपनेक सहायक आदि एआई छी। आजु हम अहाँक की सहायता करी?"
    }
  };

  // Translation function
  String translate(String key) {
    final lang = _dashboardLanguage.toLowerCase();
    if (_localizedStrings.containsKey(lang) && _localizedStrings[lang]!.containsKey(key)) {
      return _localizedStrings[lang]![key]!;
    }
    // Fallback to English
    if (_localizedStrings["english"]!.containsKey(key)) {
      return _localizedStrings["english"]![key]!;
    }
    return key;
  }
}
