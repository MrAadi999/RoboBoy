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
        "content": "Welcome back! Main aapka assistant Aadi AI hoon. How can I help you today?",
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
}
