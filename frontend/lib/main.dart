import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/app_state.dart';
import 'package:frontend/theme.dart';
import 'package:frontend/screens/auth_screen.dart';
import 'package:frontend/screens/chat_screen.dart';
import 'package:frontend/screens/settings_screen.dart';
import 'package:frontend/screens/dashboard_screen.dart';
import 'package:frontend/screens/activity_log_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => AppState(),
      child: const AadiApp(),
    ),
  );
}

class AadiApp extends StatelessWidget {
  const AadiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, child) {
        return MaterialApp(
          title: 'Aadi AI',
          debugShowCheckedModeBanner: false,
          themeMode: state.isDarkTheme ? ThemeMode.dark : ThemeMode.light,
          theme: AadiTheme.getLightTheme(),
          darkTheme: AadiTheme.getDarkTheme(),
          home: state.isAuthenticated ? const ChatScreen() : const AuthScreen(),
          routes: {
            '/settings': (context) => const SettingsScreen(),
            '/dashboard': (context) => const DashboardScreen(),
            '/activity-log': (context) => const ActivityLogScreen(),
          },
        );
      },
    );
  }
}
