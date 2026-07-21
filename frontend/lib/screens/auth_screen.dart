import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/app_state.dart';
import 'package:frontend/theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  
  bool _otpSent = false;
  String _statusMessage = "";

  void _handleRequestOtp() async {
    final contact = _contactController.text.trim();
    if (contact.isEmpty) {
      setState(() {
        _statusMessage = "SYS_ERR: Invalid identification key entered.";
      });
      return;
    }

    setState(() {
      _statusMessage = "SYS_CONNECT: Decrypting handshake protocol...";
    });

    final state = Provider.of<AppState>(context, listen: false);
    final response = await state.triggerOTP(contact);
    
    if (response["status"] == "success") {
      setState(() {
        _otpSent = true;
        _statusMessage = "SYS_SUCCESS: Bypass code dispatched. Bypass Key: ${response["dev_note"]}";
      });
    } else {
      setState(() {
        _statusMessage = "SYS_ALERT: Handshake refused. ${response["message"]}";
      });
    }
  }

  void _handleVerifyOtp() async {
    final contact = _contactController.text.trim();
    final otp = _otpController.text.trim();
    
    if (otp.isEmpty) {
      setState(() {
        _statusMessage = "SYS_ERR: Missing decryption verification code.";
      });
      return;
    }

    setState(() {
      _statusMessage = "SYS_CONNECT: Authorizing security credentials...";
    });

    final state = Provider.of<AppState>(context, listen: false);
    final response = await state.verifyAndLogin(contact, otp);
    
    if (response["status"] == "success") {
      // Navigation is handled automatically since AppState updates isAuthenticated
    } else {
      setState(() {
        _statusMessage = "SYS_ALERT: Access Denied. Decryption key mismatched.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final theme = Theme.of(context);
    final isDark = state.isDarkTheme;

    // Hacker theme terminal colors
    final Color terminalText = isDark ? AadiTheme.hackerGreen : AadiTheme.lightText;
    final Color terminalCyan = isDark ? AadiTheme.hackerCyan : AadiTheme.primarySaffron;
    final Color terminalBg = isDark ? AadiTheme.hackerBg : AadiTheme.lightBg;
    final Color terminalCard = isDark ? AadiTheme.hackerCard : AadiTheme.lightCard;

    return Scaffold(
      backgroundColor: terminalBg,
      body: Container(
        decoration: BoxDecoration(
          border: isDark 
            ? Border.all(color: AadiTheme.hackerGreen.withOpacity(0.15), width: 10) 
            : null,
        ),
        child: Stack(
          children: [
            // Retro Grid Overlay
            if (isDark)
              Positioned.fill(
                child: CustomPaint(
                  painter: TerminalGridPainter(),
                ),
              ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Container(
                  width: 500, // Fixed width on web for premium centered card layout
                  decoration: BoxDecoration(
                    color: terminalCard.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AadiTheme.hackerGreen.withOpacity(0.4) : Colors.grey.shade300,
                      width: 1.5,
                    ),
                    boxShadow: isDark ? [
                      BoxShadow(
                        color: AadiTheme.hackerGreen.withOpacity(0.15),
                        blurRadius: 20,
                        spreadRadius: 2,
                      )
                    ] : [
                      const BoxShadow(color: Colors.black12, blurRadius: 10)
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Terminal Status Badge
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? AadiTheme.hackerGreen.withOpacity(0.1) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: isDark ? AadiTheme.hackerGreen.withOpacity(0.3) : Colors.grey),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: isDark ? AadiTheme.hackerCyan : Colors.orange,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isDark ? "TERMINAL_SECURE: ACTIVE" : "SECURE SHELL",
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 9,
                                    color: isDark ? AadiTheme.hackerGreen : Colors.grey.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // HACKER ASCII Logo or Icon Header
                        Center(
                          child: isDark 
                            ? Column(
                                children: [
                                  const Text(
                                    " █████╗  █████╗ ██████╗ ██╗\n"
                                    "██╔══██╗██╔══██╗██╔══██╗██║\n"
                                    "███████║███████║██║  ██║██║\n"
                                    "██╔══██║██╔══██║██║  ██║██║\n"
                                    "██║  ██║██║  ██║██████╔╝██║\n"
                                    "╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ ╚═╝",
                                    style: TextStyle(
                                      color: AadiTheme.hackerGreen,
                                      fontFamily: 'monospace',
                                      fontSize: 10,
                                      height: 1.1,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "===============================\n"
                                    "   SYSTEM SECURITY DECRYPTOR   \n"
                                    "===============================",
                                    style: TextStyle(
                                      color: AadiTheme.hackerCyan.withOpacity(0.8),
                                      fontFamily: 'monospace',
                                      fontSize: 10,
                                      height: 1.2,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  Icon(Icons.security, size: 48, color: AadiTheme.primarySaffron),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Aadi AI Assistant",
                                    style: theme.textTheme.headlineMedium,
                                  ),
                                ],
                              ),
                        ),
                        const SizedBox(height: 32),

                        // Inputs Section
                        if (!_otpSent) ...[
                          TextField(
                            controller: _contactController,
                            keyboardType: TextInputType.emailAddress,
                            style: TextStyle(color: terminalText, fontFamily: 'monospace'),
                            decoration: InputDecoration(
                              labelText: isDark ? "IDENT_KEY (EMAIL / PHONE)" : "Phone Number or Email",
                              hintText: isDark ? "root@aadi.core or +91..." : "name@gmail.com",
                              prefixIcon: Icon(Icons.vpn_key_outlined, color: terminalText),
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: state.isLoading ? null : _handleRequestOtp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? Colors.transparent : AadiTheme.primarySaffron,
                              foregroundColor: terminalText,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                                side: BorderSide(
                                  color: isDark ? AadiTheme.hackerGreen : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              elevation: 0,
                              shadowColor: Colors.transparent,
                            ),
                            child: state.isLoading 
                              ? CircularProgressIndicator(color: terminalText)
                              : Text(
                                  isDark ? "[ INITIATE HANDSHAKE ]" : "Request OTP", 
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                                ),
                          ),
                        ] else ...[
                          Text(
                            isDark ? "INPUT DECRYPTION KEY FOR:\n${_contactController.text}" : "Entering verification code for:\n${_contactController.text}",
                            style: TextStyle(color: terminalText, fontFamily: 'monospace', fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          TextField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24, 
                              letterSpacing: 8, 
                              color: terminalCyan, 
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace'
                            ),
                            decoration: InputDecoration(
                              hintText: "------",
                              labelText: isDark ? "ENTER 6-DIGIT BYPASS_OTP" : "Enter 6-Digit OTP",
                              prefixIcon: Icon(Icons.lock_open_outlined, color: terminalText),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _otpSent = false;
                                      _otpController.clear();
                                      _statusMessage = "";
                                    });
                                  },
                                  child: Text(
                                    isDark ? "< ABORT >" : "Edit Contact",
                                    style: TextStyle(color: Colors.redAccent, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton(
                                  onPressed: state.isLoading ? null : _handleVerifyOtp,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDark ? AadiTheme.hackerGreen.withOpacity(0.2) : AadiTheme.secondaryCyan,
                                    foregroundColor: isDark ? AadiTheme.hackerGreen : Colors.black87,
                                    padding: const EdgeInsets.symmetric(vertical: 18),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      side: BorderSide(
                                        color: isDark ? AadiTheme.hackerGreen : Colors.transparent,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                  child: state.isLoading 
                                    ? CircularProgressIndicator(color: isDark ? AadiTheme.hackerGreen : Colors.black)
                                    : Text(
                                        isDark ? "[ VERIFY & LOGIN ]" : "Verify & Login", 
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        if (_statusMessage.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark 
                                ? AadiTheme.hackerGreen.withOpacity(0.05) 
                                : (_statusMessage.contains("SUCCESS") ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1)),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isDark 
                                  ? (_statusMessage.contains("ERR") || _statusMessage.contains("ALERT") ? Colors.redAccent.withOpacity(0.5) : AadiTheme.hackerGreen.withOpacity(0.5))
                                  : (_statusMessage.contains("SUCCESS") ? Colors.green.withOpacity(0.5) : Colors.red.withOpacity(0.5)),
                              ),
                            ),
                            child: Text(
                              _statusMessage,
                              style: TextStyle(
                                color: isDark 
                                  ? (_statusMessage.contains("ERR") || _statusMessage.contains("ALERT") ? Colors.redAccent : AadiTheme.hackerGreen)
                                  : (_statusMessage.contains("SUCCESS") ? Colors.green : Colors.red),
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Background Grid Painter for Hacker Mode
class TerminalGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint linePaint = Paint()
      ..color = AadiTheme.hackerGreen.withOpacity(0.03)
      ..strokeWidth = 0.5;

    const double step = 25.0;

    // Draw horizontal lines
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Draw vertical lines
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
