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
        _statusMessage = "Please enter a valid phone number or email.";
      });
      return;
    }

    final state = Provider.of<AppState>(context, listen: false);
    final response = await state.triggerOTP(contact);
    
    if (response["status"] == "success") {
      setState(() {
        _otpSent = true;
        _statusMessage = "${response["message"]} (${response["dev_note"]})";
      });
    } else {
      setState(() {
        _statusMessage = response["message"] ?? "Failed to request OTP.";
      });
    }
  }

  void _handleVerifyOtp() async {
    final contact = _contactController.text.trim();
    final otp = _otpController.text.trim();
    
    if (otp.isEmpty) {
      setState(() {
        _statusMessage = "Please enter the OTP.";
      });
      return;
    }

    final state = Provider.of<AppState>(context, listen: false);
    final response = await state.verifyAndLogin(contact, otp);
    
    if (response["status"] == "success") {
      // Navigation is handled automatically since AppState updates isAuthenticated
    } else {
      setState(() {
        _statusMessage = response["message"] ?? "Incorrect OTP.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: state.isDarkTheme 
              ? [AadiTheme.darkBg, const Color(0xFF151225)]
              : [AadiTheme.lightBg, const Color(0xFFE8EEF9)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 8,
              color: theme.cardColor.withOpacity(0.9),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Brand Icon
                    Container(
                      height: 80,
                      width: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [AadiTheme.primarySaffron, AadiTheme.secondaryCyan],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AadiTheme.primarySaffron.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: const Icon(
                        Icons.insights,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Aadi AI",
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Offline-Capable Indian AI Assistant",
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Inputs Section
                    if (!_otpSent) ...[
                      TextField(
                        controller: _contactController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: "Phone Number or Email",
                          hintText: "e.g., +91 98765 43210 or name@gmail.com",
                          prefixIcon: Icon(Icons.contact_mail_outlined),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: state.isLoading ? null : _handleRequestOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AadiTheme.primarySaffron,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: state.isLoading 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Request OTP", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ] else ...[
                      Text(
                        "Entering verification code for:\n${_contactController.text}",
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          hintText: "------",
                          labelText: "Enter 6-Digit OTP",
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _otpSent = false;
                                _otpController.clear();
                                _statusMessage = "";
                              });
                            },
                            child: const Text("Edit Contact"),
                          ),
                          ElevatedButton(
                            onPressed: state.isLoading ? null : _handleVerifyOtp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AadiTheme.secondaryCyan,
                              foregroundColor: Colors.black87,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: state.isLoading 
                              ? const CircularProgressIndicator(color: Colors.black)
                              : const Text("Verify & Login", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],

                    if (_statusMessage.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _statusMessage.contains("successfully")
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _statusMessage.contains("successfully") 
                              ? Colors.green.withOpacity(0.5)
                              : Colors.red.withOpacity(0.5),
                          ),
                        ),
                        child: Text(
                          _statusMessage,
                          style: TextStyle(
                            color: _statusMessage.contains("successfully") ? Colors.green : Colors.red,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
