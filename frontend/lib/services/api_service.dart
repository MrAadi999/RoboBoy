import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  String _baseUrl = "http://localhost:8000";

  // Setter to dynamically adjust the backend base URL from Settings
  void updateBaseUrl(String newUrl) {
    if (newUrl.isNotEmpty) {
      // Remove trailing slash if present
      _baseUrl = newUrl.endsWith('/')
          ? newUrl.substring(0, newUrl.length - 1)
          : newUrl;
    }
  }

  String get baseUrl => _baseUrl;

  Future<Map<String, dynamic>> requestOTP(String phoneOrEmail) async {
    final url = Uri.parse("$_baseUrl/api/auth/request-otp");
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"phone_or_email": phoneOrEmail}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {"status": "error", "message": "Failed to connect to backend: $e"};
    }
  }

  Future<Map<String, dynamic>> verifyOTP(
    String phoneOrEmail,
    String otp,
  ) async {
    final url = Uri.parse("$_baseUrl/api/auth/verify-otp");
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"phone_or_email": phoneOrEmail, "otp": otp}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {"status": "success", "token": data["access_token"]};
      } else {
        final data = jsonDecode(response.body);
        return {
          "status": "error",
          "message": data["detail"] ?? "Verification failed",
        };
      }
    } catch (e) {
      return {"status": "error", "message": "Failed to connect to backend: $e"};
    }
  }

  Future<Map<String, dynamic>> sendChatMessage(
    String message,
    String modeOverride,
    String? token,
  ) async {
    final url = Uri.parse("$_baseUrl/api/chat/");
    final Map<String, String> headers = {"Content-Type": "application/json"};
    if (token != null && token.isNotEmpty) {
      headers["Authorization"] = "Bearer $token";
    }

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({"message": message, "mode_override": modeOverride}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          "response":
              "Error: Unable to get response from assistant (Status code: ${response.statusCode})",
          "mode_used": "odysseus",
          "is_fallback": true,
        };
      }
    } catch (e) {
      return {
        "response":
            "Could not connect to backend server at $_baseUrl. Please verify backend is running.",
        "mode_used": "odysseus",
        "is_fallback": true,
      };
    }
  }

  Future<List<dynamic>> getChatHistory(String? token) async {
    final url = Uri.parse("$_baseUrl/api/chat/history");
    final Map<String, String> headers = {};
    if (token != null && token.isNotEmpty) {
      headers["Authorization"] = "Bearer $token";
    }

    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("Error fetching chat history: $e");
    }
    return [];
  }

  Future<List<dynamic>> getMemories(String? token) async {
    final url = Uri.parse("$_baseUrl/api/memory/");
    final Map<String, String> headers = {};
    if (token != null && token.isNotEmpty) {
      headers["Authorization"] = "Bearer $token";
    }

    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("Error fetching memories: $e");
    }
    return [];
  }

  Future<Map<String, dynamic>?> addMemory(String fact, String? token) async {
    final url = Uri.parse("$_baseUrl/api/memory/");
    final Map<String, String> headers = {"Content-Type": "application/json"};
    if (token != null && token.isNotEmpty) {
      headers["Authorization"] = "Bearer $token";
    }

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({"fact": fact}),
      );
      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("Error adding memory: $e");
    }
    return null;
  }

  Future<bool> deleteMemory(int id, String? token) async {
    final url = Uri.parse("$_baseUrl/api/memory/$id");
    final Map<String, String> headers = {};
    if (token != null && token.isNotEmpty) {
      headers["Authorization"] = "Bearer $token";
    }

    try {
      final response = await http.delete(url, headers: headers);
      return response.statusCode == 204;
    } catch (e) {
      print("Error deleting memory: $e");
      return false;
    }
  }

  // Preferences & Permissions
  Future<Map<String, dynamic>> getPreferences(String? token) async {
    final url = Uri.parse("$_baseUrl/api/preferences/");
    final Map<String, String> headers = {};
    if (token != null && token.isNotEmpty) {
      headers["Authorization"] = "Bearer $token";
    }

    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("Error getting preferences: $e");
    }
    return {};
  }

  Future<Map<String, dynamic>> updatePreferences(
    Map<String, dynamic> body,
    String? token,
  ) async {
    final url = Uri.parse("$_baseUrl/api/preferences/");
    final Map<String, String> headers = {"Content-Type": "application/json"};
    if (token != null && token.isNotEmpty) {
      headers["Authorization"] = "Bearer $token";
    }

    try {
      final response = await http.put(
        url,
        headers: headers,
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("Error updating preferences: $e");
    }
    return {};
  }

  // Daily Briefings
  Future<Map<String, dynamic>> getDailyBriefing(String? token) async {
    final url = Uri.parse("$_baseUrl/api/proactive/daily-briefing");
    final Map<String, String> headers = {};
    if (token != null && token.isNotEmpty) {
      headers["Authorization"] = "Bearer $token";
    }

    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("Error fetching daily briefing: $e");
    }
    return {
      "status": "error",
      "briefing": "Unable to fetch daily briefing from server.",
    };
  }

  // Reminders
  Future<List<dynamic>> getReminders(String? token) async {
    final url = Uri.parse("$_baseUrl/api/proactive/reminders");
    final Map<String, String> headers = {};
    if (token != null && token.isNotEmpty) {
      headers["Authorization"] = "Bearer $token";
    }

    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["reminders"] ?? [];
      }
    } catch (e) {
      print("Error fetching reminders: $e");
    }
    return [];
  }

  // Activity/Audit Logs
  Future<List<dynamic>> getActivityLogs(String? token) async {
    final url = Uri.parse("$_baseUrl/api/planner/activity-log");
    final Map<String, String> headers = {};
    if (token != null && token.isNotEmpty) {
      headers["Authorization"] = "Bearer $token";
    }

    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("Error fetching activity logs: $e");
    }
    return [];
  }

  // Confirmation Gate Action Requests
  Future<List<dynamic>> getPendingConfirmations(String? token) async {
    final url = Uri.parse("$_baseUrl/api/planner/confirmations");
    final Map<String, String> headers = {};
    if (token != null && token.isNotEmpty) {
      headers["Authorization"] = "Bearer $token";
    }

    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("Error fetching pending confirmations: $e");
    }
    return [];
  }

  Future<Map<String, dynamic>> handleConfirmationAction(
    int actionId,
    bool approve,
    String? token,
  ) async {
    final url = Uri.parse("$_baseUrl/api/planner/confirmations/$actionId");
    final Map<String, String> headers = {"Content-Type": "application/json"};
    if (token != null && token.isNotEmpty) {
      headers["Authorization"] = "Bearer $token";
    }

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({"approve": approve}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      print("Error processing confirmation action: $e");
      return {"status": "error", "message": e.toString()};
    }
  }

  // Voice Processing
  Future<Map<String, dynamic>> uploadAudioForSTT(
    List<int> audioBytes,
    String filename,
    String? token,
  ) async {
    final url = Uri.parse("$_baseUrl/api/voice/stt");
    final request = http.MultipartRequest("POST", url);

    if (token != null && token.isNotEmpty) {
      request.headers["Authorization"] = "Bearer $token";
    }

    request.files.add(
      http.MultipartFile.fromBytes("file", audioBytes, filename: filename),
    );

    try {
      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        return jsonDecode(responseData);
      }
    } catch (e) {
      print("Error uploading audio for STT: $e");
    }
    return {"status": "error", "transcription": ""};
  }

  Future<List<int>?> textToSpeech(
    String text,
    String language,
    String? token,
  ) async {
    final url = Uri.parse("$_baseUrl/api/voice/tts");
    final Map<String, String> headers = {"Content-Type": "application/json"};
    if (token != null && token.isNotEmpty) {
      headers["Authorization"] = "Bearer $token";
    }

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({"text": text, "language": language}),
      );
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      print("Error in Text-to-Speech synthesis: $e");
    }
    return null;
  }
}

final apiService = ApiService();
