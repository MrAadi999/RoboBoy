import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/app_state.dart';
import 'package:frontend/theme.dart';
import 'package:frontend/services/api_service.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // Voice state
  bool _isListening = false;
  late AnimationController _waveformController;
  bool _isBriefCollapsed = false;

  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _waveformController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    // Refresh user settings/daily briefing on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppState>(context, listen: false).refreshUserData();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _waveformController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    final state = Provider.of<AppState>(context, listen: false);
    await state.sendMessage(text);
    _scrollToBottom();
  }

  void _toggleVoice() async {
    final state = Provider.of<AppState>(context, listen: false);
    
    if (!_isListening) {
      // Start recording voice input
      if (await _audioRecorder.hasPermission()) {
        try {
          setState(() {
            _isListening = true;
          });
          _waveformController.repeat(reverse: true);
          
          final tempDir = Directory.systemTemp;
          final filepath = '${tempDir.path}/recording.wav';
          
          // Delete existing recording file if exists
          final file = File(filepath);
          if (await file.exists()) {
            await file.delete();
          }
          
          await _audioRecorder.start(
            const RecordConfig(encoder: AudioEncoder.wav),
            path: filepath,
          );
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.translate("mic_recording")), duration: const Duration(seconds: 2)),
          );
        } catch (e) {
          print("Failed to start voice recorder: $e");
          setState(() {
            _isListening = false;
            _waveformController.stop();
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.translate("mic_denied"))),
        );
      }
    } else {
      // Stop recording and process pipeline
      setState(() {
        _isListening = false;
        _waveformController.stop();
      });
      
      try {
        final path = await _audioRecorder.stop();
        if (path != null) {
          final file = File(path);
          if (await file.exists()) {
            final audioBytes = await file.readAsBytes();
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.translate("transcribing")), duration: const Duration(seconds: 1)),
            );
            
            // 1. Upload audio to STT service
            final sttResult = await apiService.uploadAudioForSTT(audioBytes, "recording.wav", state.token);
            final spokenText = sttResult["transcription"] ?? "";
            
            if (spokenText.trim().isNotEmpty) {
              // 2. Insert message and generate assistant response
              _messageController.text = spokenText;
              _sendMessage();
              
              // 3. Synthesize the response back to speech (TTS)
              Future.delayed(const Duration(milliseconds: 2000), () async {
                if (!mounted) return;
                if (state.chatMessages.isNotEmpty) {
                  final lastMsg = state.chatMessages.last;
                  if (lastMsg["role"] == "assistant") {
                    final responseText = lastMsg["content"] ?? "";
                    
                    // Fetch Text-to-Speech audio bytes from FastAPI voice service
                    final ttsAudio = await apiService.textToSpeech(responseText, state.language, state.token);
                    if (ttsAudio != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("🔈 Playing speech response..."), duration: Duration(seconds: 1)),
                      );
                      // Play synthesized audio bytes directly via audioplayers Source
                      await _audioPlayer.play(BytesSource(Uint8List.fromList(ttsAudio)));
                    }
                  }
                }
              });
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("⚠️ Could not hear anything. Please try again.")),
              );
            }
          }
        }
      } catch (e) {
        print("Voice pipeline error: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("⚠️ Voice error: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final theme = Theme.of(context);

    // Dynamic routing mode badge info
    String activeRoutingMode = "Auto Router";
    if (state.currentModeOverride == "fugu") {
      activeRoutingMode = "Forced Cloud (Fugu)";
    } else if (state.currentModeOverride == "odysseus") {
      activeRoutingMode = "Forced Local (Odysseus)";
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Aadi AI"),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      activeRoutingMode,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: Colors.grey),
                    ),
                  ],
                )
              ],
            ),
          ],
        ),
        actions: [
          // Confirmation Gate audit trail router (Phase 2)
          IconButton(
            icon: Badge(
              isLabelVisible: state.pendingConfirmations.isNotEmpty,
              label: Text(
                state.pendingConfirmations.length.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
              child: const Icon(Icons.security),
            ),
            tooltip: "Audit Trail & Confirmation Gate",
            onPressed: () {
              Navigator.pushNamed(context, '/activity-log');
            },
          ),
          IconButton(
            icon: Icon(state.isDarkTheme ? Icons.light_mode : Icons.dark_mode),
            onPressed: state.toggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Proactive Daily Briefing Card (Phase 2 Proactive Engine)
          if (state.dailyBriefingText.isNotEmpty && !_isBriefCollapsed)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AadiTheme.primarySaffron, Color(0xFFC75200)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))
                ]
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ExpansionTile(
                  initiallyExpanded: true,
                  title: Row(
                    children: const [
                      Icon(Icons.wb_sunny_outlined, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        "${state.userName}'s ${state.translate("daily_brief_card")}",
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.expand_more, color: Colors.white),
                  childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                  expandedAlignment: Alignment.topLeft,
                  children: [
                    Text(
                      state.dailyBriefingText,
                      style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (state.reminders.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  "${state.reminders.length} Traffic Alerts",
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          )
                        else
                          const SizedBox(),
                        GestureDetector(
                          onTap: () {
                            state.refreshUserData();
                          },
                          child: Row(
                            children: const [
                              Icon(Icons.refresh, color: Colors.white, size: 12),
                              SizedBox(width: 4),
                              Text(state.translate("refresh_brief"), style: const TextStyle(color: Colors.white, fontSize: 11)),
                            ],
                          ),
                        )
                      ],
                    )
                  ],
                ),
              ),
            ),

          // 2. Traffic adjustment notification panel (Phase 2 Proactive warnings)
          if (state.reminders.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: state.reminders.map<Widget>((r) {
                  final isWarning = r["status"] == "warning";
                  if (!isWarning) return const SizedBox();
                  return Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.directions_car_outlined, color: Colors.redAccent, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            r["alert_message"] ?? "",
                            style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

          // Message List
          Expanded(
            child: state.chatMessages.isEmpty
              ? _buildWelcomeSplash(theme)
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: state.chatMessages.length,
                  itemBuilder: (context, index) {
                    final msg = state.chatMessages[index];
                    final isUser = msg["role"] == "user";
                    return _buildMessageBubble(msg, isUser, theme);
                  },
                ),
          ),

          // Voice waveform overlay when listening
          if (_isListening) _buildVoiceWaveform(theme),

          // Loading indicator
          if (state.isLoading && !_isListening)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AadiTheme.primarySaffron),
              ),
            ),

          // Input field row
          _buildInputBar(theme),
        ],
      ),
    );
  }

  Widget _buildWelcomeSplash(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.forum_outlined, size: 72, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              "Start a conversation with Aadi",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              "Ask me anything! Complex tasks route to Fugu (Cloud LLM) and offline tasks execute via Odysseus (Local Ollama). Try asking in Hinglish!",
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildQuickQuestionChip("Namaste Aadi, tum kaun ho?"),
                _buildQuickQuestionChip("Check my Flipkart orders status"),
                _buildQuickQuestionChip("What is my schedule for today?"),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildQuickQuestionChip(String text) {
    return ActionChip(
      label: Text(text, style: const TextStyle(fontSize: 12)),
      onPressed: () {
        _messageController.text = text;
        _sendMessage();
      },
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isUser, ThemeData theme) {
    final isFallback = msg["is_fallback"] == true;
    final mode = msg["mode_used"] as String?;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6.0),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.all(14.0),
        decoration: BoxDecoration(
          color: isUser
            ? AadiTheme.primarySaffron
            : (theme.brightness == Brightness.dark ? AadiTheme.darkCard : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isUser)
              Text(
                msg["content"] ?? "",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                ),
              )
            else
              MarkdownBody(
                data: msg["content"] ?? "",
                styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                  p: TextStyle(
                    color: theme.textTheme.bodyLarge?.color,
                    fontSize: 15,
                  ),
                ),
              ),
            if (!isUser && mode != null) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: mode == "fugu" 
                        ? AadiTheme.primarySaffron.withOpacity(0.15)
                        : AadiTheme.secondaryCyan.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: mode == "fugu" ? AadiTheme.primarySaffron : AadiTheme.secondaryCyan,
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      mode == "fugu" ? "☁️ Fugu Mode" : "💻 Odysseus Mode",
                      style: TextStyle(
                        fontSize: 9,
                        color: mode == "fugu" ? AadiTheme.primarySaffron : AadiTheme.secondaryCyan,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isFallback) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        "⚠️ Fallback Active",
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ]
                ],
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceWaveform(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AadiTheme.primarySaffron.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AadiTheme.primarySaffron.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.mic, color: AadiTheme.primarySaffron),
          const SizedBox(width: 12),
          Text(state.translate("listening_mic"), style: const TextStyle(color: AadiTheme.primarySaffron, fontWeight: FontWeight.bold)),
          const SizedBox(width: 16),
          // Pulsing waveform graphics
          AnimatedBuilder(
            animation: _waveformController,
            builder: (context, child) {
              return Row(
                children: List.generate(5, (index) {
                  double height = 5 + (30 * _waveformController.value * (1 - (index - 2).abs() / 3));
                  return Container(
                    width: 3,
                    height: height,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    color: AadiTheme.primarySaffron,
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24, top: 12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: theme.dividerColor, width: 0.5)),
      ),
      child: Row(
        children: [
          // Voice Toggle Button
          GestureDetector(
            onTap: _toggleVoice,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isListening 
                  ? AadiTheme.primarySaffron 
                  : (theme.brightness == Brightness.dark ? AadiTheme.darkCard : Colors.grey.shade300),
              ),
              child: Icon(
                _isListening ? Icons.stop : Icons.mic,
                color: _isListening ? Colors.white : AadiTheme.primarySaffron,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Text Input Box
          Expanded(
            child: TextField(
              controller: _messageController,
              onSubmitted: (_) => _sendMessage(),
              decoration: const InputDecoration(
                hintText: "Ask Aadi in English or Hinglish...",
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Send Button
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AadiTheme.primarySaffron,
              ),
              child: const Icon(
                Icons.send,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Extension to read raw bytes from string
extension SpeechBytes on String {
  static List<int> b(String data) {
    return utf8.encode(data);
  }
}
List<int> b(String data) => utf8.encode(data);
