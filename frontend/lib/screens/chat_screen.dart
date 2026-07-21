import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/app_state.dart';
import 'package:frontend/theme.dart';
import 'package:frontend/services/api_service.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

// Represents an attack route on the cyber map
class AttackRoute {
  final Offset start;
  final Offset end;
  final Color color;

  AttackRoute({
    required this.start,
    required this.end,
    required this.color,
  });
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // Audio state
  bool _isListening = false;
  late AnimationController _waveformController;
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Animation controller for attack lines & rotation
  late AnimationController _globalAnimationController;
  bool _isBriefCollapsed = false;

  // List of attack routes (percentages of screen size)
  final List<AttackRoute> _attackRoutes = [
    AttackRoute(start: const Offset(0.15, 0.35), end: const Offset(0.72, 0.54), color: AadiTheme.hackerGreen), // Seattle to Mumbai
    AttackRoute(start: const Offset(0.85, 0.42), end: const Offset(0.48, 0.32), color: AadiTheme.hackerCyan), // Tokyo to London
    AttackRoute(start: const Offset(0.52, 0.33), end: const Offset(0.35, 0.72), color: AadiTheme.hackerAmber), // Frankfurt to Sao Paulo
    AttackRoute(start: const Offset(0.62, 0.28), end: const Offset(0.9, 0.8), color: AadiTheme.hackerGreen), // Moscow to Sydney
    AttackRoute(start: const Offset(0.28, 0.38), end: const Offset(0.55, 0.78), color: Colors.redAccent), // NY to Cape Town
    AttackRoute(start: const Offset(0.22, 0.45), end: const Offset(0.85, 0.42), color: AadiTheme.hackerCyan), // LA to Tokyo
    AttackRoute(start: const Offset(0.78, 0.32), end: const Offset(0.72, 0.54), color: AadiTheme.hackerAmber), // Beijing to Mumbai
    AttackRoute(start: const Offset(0.55, 0.72), end: const Offset(0.52, 0.33), color: AadiTheme.hackerGreen), // Johannesburg to Frankfurt
    AttackRoute(start: const Offset(0.18, 0.32), end: const Offset(0.52, 0.33), color: Colors.redAccent), // Vancouver to London
    AttackRoute(start: const Offset(0.92, 0.82), end: const Offset(0.85, 0.42), color: AadiTheme.hackerCyan), // Melbourne to Tokyo
  ];

  @override
  void initState() {
    super.initState();
    _waveformController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // Loop animation for mapping exploit packet pulses
    _globalAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

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
    _globalAnimationController.dispose();
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
      if (await _audioRecorder.hasPermission()) {
        try {
          setState(() {
            _isListening = true;
          });
          _waveformController.repeat(reverse: true);
          
          final tempDir = Directory.systemTemp;
          final filepath = '${tempDir.path}/recording.wav';
          final file = File(filepath);
          if (await file.exists()) {
            await file.delete();
          }
          
          await _audioRecorder.start(
            const RecordConfig(encoder: AudioEncoder.wav),
            path: filepath,
          );
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                "SYS_MIC: Recording audio stream... [TALK NOW]",
                style: TextStyle(fontFamily: 'monospace'),
              ),
              backgroundColor: AadiTheme.hackerCard,
              duration: const Duration(seconds: 2)
            ),
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
          const SnackBar(
            content: Text("SYS_ERR: Microphone hardware access refused.", style: TextStyle(fontFamily: 'monospace')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } else {
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
              SnackBar(
                content: const Text("SYS_STT: Transcribing speech payload...", style: TextStyle(fontFamily: 'monospace')),
                backgroundColor: AadiTheme.hackerCard,
                duration: const Duration(seconds: 1)
              ),
            );
            
            final sttResult = await apiService.uploadAudioForSTT(audioBytes, "recording.wav", state.token);
            final spokenText = sttResult["transcription"] ?? "";
            
            if (spokenText.trim().isNotEmpty) {
              _messageController.text = spokenText;
              _sendMessage();
              
              Future.delayed(const Duration(milliseconds: 2000), () async {
                if (!mounted) return;
                if (state.chatMessages.isNotEmpty) {
                  final lastMsg = state.chatMessages.last;
                  if (lastMsg["role"] == "assistant") {
                    final responseText = lastMsg["content"] ?? "";
                    
                    final ttsAudio = await apiService.textToSpeech(responseText, state.language, state.token);
                    if (ttsAudio != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("SYS_TTS: Streaming audio synthesis...", style: TextStyle(fontFamily: 'monospace')),
                          duration: Duration(seconds: 1)
                        ),
                      );
                      await _audioPlayer.play(BytesSource(Uint8List.fromList(ttsAudio)));
                    }
                  }
                }
              });
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("SYS_WARN: Audio frame empty. Could not hear anything.", style: TextStyle(fontFamily: 'monospace')),
                  backgroundColor: Colors.amber,
                ),
              );
            }
          }
        }
      } catch (e) {
        print("Voice pipeline error: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("SYS_ERR: Voice pipeline breakdown: $e", style: const TextStyle(fontFamily: 'monospace')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final theme = Theme.of(context);
    final isDark = state.isDarkTheme;

    final Color primaryColor = isDark ? AadiTheme.hackerGreen : AadiTheme.primarySaffron;
    final Color secondaryColor = isDark ? AadiTheme.hackerCyan : AadiTheme.secondaryCyan;
    final Color terminalBg = isDark ? AadiTheme.hackerBg : AadiTheme.lightBg;

    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 950;

    return Scaffold(
      backgroundColor: terminalBg,
      appBar: AppBar(
        title: Text(
          isDark ? "AADI_AI // SHADOW_HACKER_OPERATIONS" : "Aadi AI Assistant",
          style: const TextStyle(fontFamily: 'monospace', fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: state.pendingConfirmations.isNotEmpty,
              backgroundColor: Colors.redAccent,
              label: Text(
                state.pendingConfirmations.length.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 9, fontFamily: 'monospace'),
              ),
              child: Icon(Icons.security, color: primaryColor),
            ),
            tooltip: isDark ? "CONFIRMATION_GATE" : "Audit Trail",
            onPressed: () {
              Navigator.pushNamed(context, '/activity-log');
            },
          ),
          IconButton(
            icon: Icon(state.isDarkTheme ? Icons.light_mode : Icons.dark_mode, color: primaryColor),
            onPressed: state.toggleTheme,
          ),
          IconButton(
            icon: Icon(Icons.storage, color: primaryColor),
            tooltip: isDark ? "MEMORY_CORE" : "Memory Registry",
            onPressed: () {
              Navigator.pushNamed(context, '/dashboard');
            },
          ),
          IconButton(
            icon: Icon(Icons.settings_input_component, color: primaryColor),
            tooltip: isDark ? "SYS_SETTINGS" : "Settings",
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: isDark ? AadiTheme.hackerGreen.withOpacity(0.3) : theme.dividerColor,
            height: 1.0,
          ),
        ),
      ),
      body: Stack(
        children: [
          // 1. Live Cyber Attack Dotted World Map Background (same-to-same Shadow Hacker)
          if (isDark)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _globalAnimationController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: CyberAttackMapPainter(
                      progress: _globalAnimationController.value,
                      routes: _attackRoutes,
                    ),
                  );
                },
              ),
            ),

          // 2. Main Cockpit panels
          if (isDesktop)
            Row(
              children: [
                // Left monitor screen - tilted Y
                Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0012)
                    ..rotateY(0.12),
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: 340,
                    margin: const EdgeInsets.only(left: 16, top: 20, bottom: 20),
                    child: _buildGlassMonitor(
                      child: _buildLeftMonitorPanel(isDark, primaryColor, secondaryColor),
                      isDark: isDark,
                      borderGlowColor: primaryColor,
                    ),
                  ),
                ),
                
                // Center Area: Dotted world map attack visual + Hooded Hacker Silhouette
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            // 3. Glowing Hooded Hacker silhouette in the center
                            if (isDark)
                              Positioned(
                                bottom: 0,
                                child: Image.asset(
                                  "assets/hacker.png",
                                  height: 430,
                                  fit: BoxFit.contain,
                                ),
                              ),

                            // Floating diagnostic details on left & right of hacker
                            if (isDark) ...[
                              Positioned(
                                left: 20,
                                bottom: 110,
                                child: _buildMiniConsole("DECRYPT_CORE", [
                                  "ADDR: 0x7FFF5",
                                  "SEC: SECTOR_09",
                                  "DECRYPT: 94.2%",
                                ], isDark, primaryColor),
                              ),
                              Positioned(
                                right: 20,
                                bottom: 110,
                                child: _buildMiniConsole("PORT_SCANNER", [
                                  "PORT: 443 OPEN",
                                  "PORT: 8080 SCAN",
                                  "IP: 192.168.1.1",
                                ], isDark, primaryColor),
                              ),
                            ],
                            
                            // 4. Rotating 3D holographic orb centered
                            Positioned(
                              bottom: 240,
                              child: SizedBox(
                                width: 180,
                                height: 180,
                                child: AnimatedBuilder(
                                  animation: _globalAnimationController,
                                  builder: (context, child) {
                                    return CustomPaint(
                                      painter: HologramPainter(
                                        angle: _globalAnimationController.value * 2 * math.pi,
                                        color: isDark ? AadiTheme.hackerCyan : AadiTheme.primarySaffron,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            
                            // Bottom Action overlay
                            Positioned(
                              bottom: 24,
                              child: Column(
                                children: [
                                  Text(
                                    isDark ? "3D_CHARACTER_SLOT: INITIALIZED" : "Holographic Avatar Core",
                                    style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: secondaryColor),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      _buildQuickQuestionChip(isDark ? "run identity_bypass" : "Who is Aadi?", "Namaste Aadi, tum kaun ho?", isDark),
                                      _buildQuickQuestionChip(isDark ? "query flipkart --status" : "Flipkart Orders", "Check my Flipkart orders status", isDark),
                                    ],
                                  )
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                      if (_isListening) _buildVoiceWaveform(theme, state),
                    ],
                  ),
                ),
                
                // Right monitor screen - tilted Y
                Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0012)
                    ..rotateY(-0.12),
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 440,
                    margin: const EdgeInsets.only(right: 16, top: 20, bottom: 20),
                    child: _buildGlassMonitor(
                      child: _buildRightMonitorPanel(state, theme, isDark, primaryColor),
                      isDark: isDark,
                      borderGlowColor: secondaryColor,
                    ),
                  ),
                ),
              ],
            )
          else
            // Responsive mobile stacking layout
            Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildLeftMonitorPanel(isDark, primaryColor, secondaryColor),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 380,
                          child: Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              if (isDark)
                                Positioned(
                                  bottom: 0,
                                  child: Image.asset(
                                    "assets/hacker.png",
                                    height: 300,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              Positioned(
                                bottom: 150,
                                child: SizedBox(
                                  width: 130,
                                  height: 130,
                                  child: AnimatedBuilder(
                                    animation: _globalAnimationController,
                                    builder: (context, child) {
                                      return CustomPaint(
                                        painter: HologramPainter(
                                          angle: _globalAnimationController.value * 2 * math.pi,
                                          color: isDark ? AadiTheme.hackerCyan : AadiTheme.primarySaffron,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_isListening) _buildVoiceWaveform(theme, state),
                        const SizedBox(height: 16),
                        _buildRightMonitorPanel(state, theme, isDark, primaryColor),
                      ],
                    ),
                  ),
                ),
              ],
            )
        ],
      ),
    );
  }

  Widget _buildMiniConsole(String title, List<String> lines, bool isDark, Color primary) {
    return Container(
      padding: const EdgeInsets.all(8),
      width: 140,
      decoration: BoxDecoration(
        color: isDark ? AadiTheme.hackerCard.withOpacity(0.7) : Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: isDark ? primary.withOpacity(0.3) : Colors.grey, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: isDark ? AadiTheme.hackerCyan : Colors.black87,
            ),
          ),
          const Divider(height: 8, color: Colors.grey),
          ...lines.map((l) => Text(
            l,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 8),
          )),
        ],
      ),
    );
  }

  // --- GLASSMORPHIC MONITOR CONTAINER WRAPPER ---
  Widget _buildGlassMonitor({required Widget child, required bool isDark, required Color borderGlowColor}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AadiTheme.hackerCard.withOpacity(0.85) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? borderGlowColor.withOpacity(0.4) : Colors.grey.shade400,
              width: 2.0, // Thicker monitor bezels
            ),
            boxShadow: isDark ? [
              BoxShadow(
                color: borderGlowColor.withOpacity(0.12),
                blurRadius: 15,
                spreadRadius: 1,
              )
            ] : null,
          ),
          child: child,
        ),
      ),
    );
  }

  // --- COLUMN 1: Diagnostics monitor pane ---
  Widget _buildLeftMonitorPanel(bool isDark, Color primary, Color secondary) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bio diagnostic indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "✚ BIO_DIAGNOSTIC",
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AadiTheme.hackerCyan : Colors.redAccent,
                  shadows: isDark ? [Shadow(color: AadiTheme.hackerCyan, blurRadius: 3)] : null,
                ),
              ),
              Text(
                "DC.945",
                style: TextStyle(fontSize: 8, fontFamily: 'monospace', color: primary),
              ),
            ],
          ),
          const Divider(height: 16, color: Colors.grey),

          // Guy Fawkes watermark background grid
          Expanded(
            child: Stack(
              children: [
                if (isDark)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Opacity(
                      opacity: 0.04,
                      child: Icon(Icons.masks, size: 140, color: primary),
                    ),
                  ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ECG pulse rate section
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        border: Border.all(color: primary.withOpacity(0.15)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("HEART_RATE", style: TextStyle(fontFamily: 'monospace', fontSize: 9, fontWeight: FontWeight.bold)),
                              Text(
                                "157 BPM",
                                style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: primary, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 36,
                            width: double.infinity,
                            child: AnimatedBuilder(
                              animation: _globalAnimationController,
                              builder: (context, child) {
                                return CustomPaint(
                                  painter: HeartRateWaveformPainter(
                                    progress: _globalAnimationController.value,
                                    color: isDark ? AadiTheme.hackerCyan : Colors.red,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Diagnostic status lists
                    const Text(
                      "ZONE_A   ● ZONE_B   ● ZONE_C\n"
                      "BODY_TEMP: 37.2°C\n"
                      "OXYGEN: 99% [SECURE]\n"
                      "RAM_LOAD: 48% [OK]\n"
                      "THREAT_LEVEL: NONE",
                      style: TextStyle(fontFamily: 'monospace', fontSize: 10, height: 1.5),
                    ),
                    const SizedBox(height: 16),

                    // Bouncing matrix diagnostic logs
                    const Text("CLUSTER_ACTIVITIES:", style: TextStyle(fontFamily: 'monospace', fontSize: 9, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Expanded(
                      child: AnimatedBuilder(
                        animation: _globalAnimationController,
                        builder: (context, child) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(8, (index) {
                              final h = (math.sin(_globalAnimationController.value * 25 + index) + 1.2) * 20 + 5;
                              return Container(
                                width: 8,
                                height: h,
                                decoration: BoxDecoration(
                                  color: primary.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              );
                            }),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- COLUMN 3: Hacking chat console monitor pane ---
  Widget _buildRightMonitorPanel(AppState state, ThemeData theme, bool isDark, Color primary) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "⚡ CHAT_CONSOLE_SHELL",
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: primary,
                  shadows: isDark ? [Shadow(color: primary, blurRadius: 3)] : null,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: const Text(
                  "SYS_ACTIVE",
                  style: TextStyle(fontSize: 8, fontFamily: 'monospace', color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const Divider(height: 12, color: Colors.grey),

          // Daily briefing panel
          if (state.dailyBriefingText.isNotEmpty && !_isBriefCollapsed)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black45,
                border: Border.all(color: primary.withOpacity(0.2)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "CAT DAILY_BRIEF.LOG",
                        style: TextStyle(fontFamily: 'monospace', fontSize: 9, fontWeight: FontWeight.bold, color: primary),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _isBriefCollapsed = true),
                        child: const Icon(Icons.close, size: 10, color: Colors.grey),
                      )
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    state.dailyBriefingText.length > 120 
                      ? "${state.dailyBriefingText.substring(0, 120)}..."
                      : state.dailyBriefingText,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 9, height: 1.3),
                  ),
                ],
              ),
            ),

          // Chat message list
          Expanded(
            child: state.chatMessages.isEmpty
              ? const Center(
                  child: Text(
                    "[SHELL THREAD EMPTY - AWAITING USER COMMANDS]",
                    style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: state.chatMessages.length,
                  itemBuilder: (context, index) {
                    final msg = state.chatMessages[index];
                    final isUser = msg["role"] == "user";
                    return _buildMessageBubble(msg, isUser, theme, isDark);
                  },
                ),
          ),

          // Command line input
          _buildInputBar(theme, isDark),
        ],
      ),
    );
  }

  Widget _buildQuickQuestionChip(String displayLabel, String actualCommand, bool isDark) {
    return ActionChip(
      backgroundColor: isDark ? AadiTheme.hackerCard : Colors.white,
      label: Text(
        displayLabel, 
        style: TextStyle(
          fontSize: 9, 
          fontFamily: 'monospace',
          color: isDark ? AadiTheme.hackerGreen : Colors.black87,
        )
      ),
      side: BorderSide(color: isDark ? AadiTheme.hackerGreen.withOpacity(0.4) : Colors.grey.shade300),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      onPressed: () {
        _messageController.text = actualCommand;
        _sendMessage();
      },
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isUser, ThemeData theme, bool isDark) {
    final mode = msg["routing_mode"];
    final Color textColor = isDark 
      ? (isUser ? AadiTheme.hackerCyan : AadiTheme.hackerGreen)
      : (isUser ? Colors.white : Colors.black87);
    final Color cardBg = isDark 
      ? AadiTheme.hackerCard.withOpacity(0.3)
      : (isUser ? AadiTheme.primarySaffron : Colors.white);
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isUser ? "[USER@LOCAL]:~\$ " : "[AADI_AI]:~# ",
                style: TextStyle(
                  fontSize: 9, 
                  fontFamily: 'monospace', 
                  fontWeight: FontWeight.bold,
                  color: isUser ? (isDark ? AadiTheme.hackerCyan : AadiTheme.secondaryCyan) : (isDark ? AadiTheme.hackerGreen : AadiTheme.primarySaffron),
                ),
              ),
              if (!isUser && mode != null)
                Text(
                  "[THREAD: ${mode.toString().toUpperCase()}]",
                  style: const TextStyle(fontSize: 8, fontFamily: 'monospace', color: Colors.grey),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cardBg,
              border: isDark ? Border.all(color: textColor.withOpacity(0.12)) : null,
              borderRadius: BorderRadius.circular(4),
            ),
            child: isDark 
              ? MarkdownBody(
                  data: msg["content"] ?? "",
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(color: textColor, fontFamily: 'monospace', fontSize: 10, height: 1.3),
                    code: TextStyle(color: Colors.white, backgroundColor: Colors.grey.shade900, fontFamily: 'monospace', fontSize: 9),
                    listBullet: TextStyle(color: textColor, fontFamily: 'monospace'),
                    strong: TextStyle(color: AadiTheme.hackerCyan, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                  ),
                )
              : MarkdownBody(
                  data: msg["content"] ?? "",
                  styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                    p: TextStyle(color: textColor, fontSize: 11, height: 1.3),
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceWaveform(ThemeData theme, AppState state) {
    final isDark = state.isDarkTheme;
    final primaryColor = isDark ? AadiTheme.hackerGreen : AadiTheme.primarySaffron;

    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: primaryColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mic, color: primaryColor, size: 14),
          const SizedBox(width: 8),
          Text(
            isDark ? "SYS_MIC: CAPTURING AUDIO..." : "Listening...", 
            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 9)
          ),
          const SizedBox(width: 12),
          AnimatedBuilder(
            animation: _waveformController,
            builder: (context, child) {
              return Row(
                children: List.generate(4, (index) {
                  double height = 4 + (16 * _waveformController.value * (1 - (index - 1.5).abs() / 2));
                  return Container(
                    width: 2,
                    height: height,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    color: primaryColor,
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(ThemeData theme, bool isDark) {
    final Color primaryColor = isDark ? AadiTheme.hackerGreen : AadiTheme.primarySaffron;
    return Container(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          // Voice Toggle Button
          GestureDetector(
            onTap: _toggleVoice,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isListening ? Colors.redAccent : (isDark ? AadiTheme.hackerCard : Colors.grey.shade300),
                border: isDark ? Border.all(color: _isListening ? Colors.red : AadiTheme.hackerGreen.withOpacity(0.5)) : null,
              ),
              child: Icon(
                _isListening ? Icons.stop : Icons.mic,
                color: _isListening ? Colors.white : primaryColor,
                size: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (isDark)
            const Text(
              "\$ ",
              style: TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold, color: AadiTheme.hackerGreen),
            ),
          // Text Input Box
          Expanded(
            child: TextField(
              controller: _messageController,
              onSubmitted: (_) => _sendMessage(),
              style: TextStyle(fontFamily: isDark ? 'monospace' : null, color: isDark ? AadiTheme.hackerGreen : null, fontSize: 11),
              decoration: InputDecoration(
                hintText: isDark ? "Enter query shell command..." : "Ask Aadi...",
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Send Button
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? Colors.transparent : AadiTheme.primarySaffron,
                border: isDark ? Border.all(color: AadiTheme.hackerGreen, width: 1.5) : null,
              ),
              child: Icon(
                Icons.subdirectory_arrow_left,
                color: isDark ? AadiTheme.hackerGreen : Colors.white,
                size: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 1. Dotted World Map custom painter with pulsing active exploit arc lines
class CyberAttackMapPainter extends CustomPainter {
  final double progress;
  final List<AttackRoute> routes;

  CyberAttackMapPainter({required this.progress, required this.routes});

  // Approximates world map continents using a lightweight coordinates math
  bool _isLand(double x, double y) {
    // North America
    if (x > 0.08 && x < 0.32 && y > 0.20 && y < 0.50) return true;
    // South America
    if (x > 0.26 && x < 0.38 && y > 0.50 && y < 0.85) return true;
    // Greenland
    if (x > 0.32 && x < 0.42 && y > 0.08 && y < 0.20) return true;
    // Europe
    if (x > 0.44 && x < 0.58 && y > 0.20 && y < 0.42) return true;
    // Africa
    if (x > 0.46 && x < 0.60 && y > 0.42 && y < 0.80) return true;
    // Asia
    if (x > 0.58 && x < 0.88 && y > 0.12 && y < 0.65) return true;
    // Australia
    if (x > 0.78 && x < 0.92 && y > 0.66 && y < 0.85) return true;
    return false;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Draw background tech grid
    final Paint gridPaint = Paint()
      ..color = AadiTheme.hackerCyan.withOpacity(0.015)
      ..strokeWidth = 0.5;
    const double step = 30.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final Paint dotPaint = Paint()
      ..color = AadiTheme.hackerGreen.withOpacity(0.24)
      ..strokeWidth = 1.5;

    // Draw the dotted world map grid (procedural generation scaling)
    for (double x = 0; x < 1.0; x += 0.02) {
      for (double y = 0; y < 1.0; y += 0.03) {
        if (_isLand(x, y)) {
          canvas.drawCircle(Offset(x * size.width, y * size.height), 1.8, dotPaint);
        }
      }
    }

    // Draw active attack route bezier curves
    for (var route in routes) {
      final Offset startPoint = Offset(route.start.dx * size.width, route.start.dy * size.height);
      final Offset endPoint = Offset(route.end.dx * size.width, route.end.dy * size.height);

      final Paint linePaint = Paint()
        ..color = route.color.withOpacity(0.15)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      // Draw bezier arc to look like global paths
      final Path path = Path();
      path.moveTo(startPoint.dx, startPoint.dy);
      
      // Control point makes it bend upward
      final Offset controlPoint = Offset(
        (startPoint.dx + endPoint.dx) / 2,
        math.min(startPoint.dy, endPoint.dy) - 120,
      );
      path.quadraticBezierTo(controlPoint.dx, controlPoint.dy, endPoint.dx, endPoint.dy);
      canvas.drawPath(path, linePaint);

      // Draw animated pulsing packet along the curve
      // Quadratic Bezier interpolation: B(t) = (1-t)^2 * P0 + 2*(1-t)*t * P1 + t^2 * P2
      final double t = progress;
      final double x = (1 - t) * (1 - t) * startPoint.dx + 2 * (1 - t) * t * controlPoint.dx + t * t * endPoint.dx;
      final double y = (1 - t) * (1 - t) * startPoint.dy + 2 * (1 - t) * t * controlPoint.dy + t * t * endPoint.dy;

      final Paint pulsePaint = Paint()
        ..color = route.color
        ..style = PaintingStyle.fill;
      
      // Draw glowing pulse dot
      canvas.drawCircle(Offset(x, y), 3.5, pulsePaint);
      canvas.drawCircle(Offset(x, y), 8.0, Paint()..color = route.color.withOpacity(0.2)); // glow ring
    }
  }

  @override
  bool shouldRepaint(covariant CyberAttackMapPainter oldDelegate) => true;
}

// 2. Vector Hooded Hacker silhouette custom painter
class HoodedHackerSilhouettePainter extends CustomPainter {
  final Color color;

  HoodedHackerSilhouettePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Draw hacker hooded silhouette gradient fill
    final Paint fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(w * 0.5, h * 0.3),
        Offset(w * 0.5, h),
        [
          AadiTheme.hackerCard.withOpacity(0.85),
          AadiTheme.hackerBg.withOpacity(0.95),
        ],
      )
      ..style = PaintingStyle.fill;

    final Paint borderPaint = Paint()
      ..color = color.withOpacity(0.25)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    final Path path = Path();
    // Shoulder & Hood trace
    path.moveTo(w * 0.18, h);
    path.quadraticBezierTo(w * 0.22, h * 0.68, w * 0.34, h * 0.62); // Left shoulder
    path.quadraticBezierTo(w * 0.36, h * 0.28, w * 0.5, h * 0.22); // Left hood curve
    path.quadraticBezierTo(w * 0.64, h * 0.28, w * 0.66, h * 0.62); // Right hood curve
    path.quadraticBezierTo(w * 0.78, h * 0.68, w * 0.82, h); // Right shoulder
    path.lineTo(w * 0.18, h);
    path.close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);

    // Draw inner hood void (face region - dark/empty)
    final Path faceVoid = Path();
    faceVoid.moveTo(w * 0.42, h * 0.6);
    faceVoid.quadraticBezierTo(w * 0.40, h * 0.38, w * 0.5, h * 0.34);
    faceVoid.quadraticBezierTo(w * 0.60, h * 0.38, w * 0.58, h * 0.6);
    faceVoid.close();

    canvas.drawPath(
      faceVoid, 
      Paint()
        ..color = AadiTheme.hackerBg
        ..style = PaintingStyle.fill
    );
    canvas.drawPath(
      faceVoid, 
      Paint()
        ..color = color.withOpacity(0.12)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke
    );
    
    // Laptop screen / keyboard glow frame in front
    final Paint screenGlow = Paint()
      ..color = color.withOpacity(0.06)
      ..style = PaintingStyle.fill;
    
    final Path screenPath = Path();
    screenPath.moveTo(w * 0.32, h);
    screenPath.lineTo(w * 0.38, h * 0.82);
    screenPath.lineTo(w * 0.62, h * 0.82);
    screenPath.lineTo(w * 0.68, h);
    screenPath.close();
    
    canvas.drawPath(screenPath, screenGlow);
    canvas.drawPath(
      screenPath, 
      Paint()
        ..color = color.withOpacity(0.2)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke
    );
  }

  @override
  bool shouldRepaint(covariant HoodedHackerSilhouettePainter oldDelegate) => false;
}

// 3. Draw ECG Heart Rate waveform
class HeartRateWaveformPainter extends CustomPainter {
  final double progress;
  final Color color;

  HeartRateWaveformPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    final double step = size.width / 50.0;
    
    path.moveTo(0, size.height / 2);

    for (int i = 0; i <= 50; i++) {
      final double x = i * step;
      double y = size.height / 2;
      
      final double localProgress = (progress * 50) % 50;
      final double distToProgress = (i - localProgress).abs();
      
      if (distToProgress < 3) {
        if (distToProgress < 1) {
          y -= 14; 
        } else if (distToProgress < 2) {
          y += 8; 
        } else {
          y -= 4;  
        }
      } else {
        y += math.sin(i * 1.5 + progress * 20) * 0.8;
      }
      
      path.lineTo(x, y);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant HeartRateWaveformPainter oldDelegate) => true;
}

// 4. 3D Wireframe Orbit rotating mesh sphere
class HologramPainter extends CustomPainter {
  final double angle;
  final Color color;

  HologramPainter({required this.angle, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint linePaint = Paint()
      ..color = color.withOpacity(0.18)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final Paint corePaint = Paint()
      ..color = color.withOpacity(0.04)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.35;

    canvas.drawCircle(center, radius, corePaint);

    for (int i = -3; i <= 3; i++) {
      final double latRatio = i / 4.0;
      final double latRadius = radius * math.cos(latRatio * math.pi / 2);
      final double yOffset = radius * math.sin(latRatio * math.pi / 2) * math.sin(angle * 0.3);
      
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy + yOffset), 
          width: latRadius * 2, 
          height: latRadius * 0.4 * math.cos(angle * 0.3),
        ),
        linePaint,
      );
    }

    for (int j = 0; j < 4; j++) {
      final double rotAngle = angle + (j * math.pi / 4);
      final double w = radius * 2 * (math.cos(rotAngle)).abs();
      final double h = radius * 2;
      
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(math.sin(angle * 0.1) * 0.2); 
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: w, height: h),
        linePaint,
      );
      canvas.restore();
    }

    final Paint outerHudPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    
    canvas.drawCircle(center, radius * 1.15, outerHudPaint);
    
    canvas.drawLine(Offset(center.dx - radius * 1.25, center.dy), Offset(center.dx - radius * 1.1, center.dy), outerHudPaint);
    canvas.drawLine(Offset(center.dx + radius * 1.1, center.dy), Offset(center.dx + radius * 1.25, center.dy), outerHudPaint);
    canvas.drawLine(Offset(center.dx, center.dy - radius * 1.25), Offset(center.dx, center.dy - radius * 1.1), outerHudPaint);
    canvas.drawLine(Offset(center.dx, center.dy + radius * 1.1), Offset(center.dx, center.dy + radius * 1.25), outerHudPaint);
  }

  @override
  bool shouldRepaint(covariant HologramPainter oldDelegate) => true;
}
