import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/app_state.dart';
import 'package:frontend/theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _assistantNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final state = Provider.of<AppState>(context, listen: false);
    _urlController.text = state.backendUrl;
    _userNameController.text = state.userName;
    _assistantNameController.text = state.assistantName;
  }

  @override
  void dispose() {
    _urlController.dispose();
    _userNameController.dispose();
    _assistantNameController.dispose();
    super.dispose();
  }

  void _saveUrl() {
    final url = _urlController.text.trim();
    if (url.isNotEmpty) {
      Provider.of<AppState>(context, listen: false).setBackendUrl(url);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Backend URL updated to: $url")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings & Controls"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Section: Routing Settings
          _buildSectionHeader(theme, "Assistant Routing Modes"),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                RadioListTile<String>(
                  title: const Text("Smart Router (Auto)"),
                  subtitle: const Text("Automatically routes based on query complexity and internet speed."),
                  value: "auto",
                  groupValue: state.currentModeOverride,
                  activeColor: AadiTheme.primarySaffron,
                  onChanged: (val) => state.setModeOverride(val!),
                ),
                const Divider(height: 1),
                RadioListTile<String>(
                  title: const Text("Fugu Mode Only (Cloud)"),
                  subtitle: const Text("Forces all reasoning to Claude API (Requires internet)."),
                  value: "fugu",
                  groupValue: state.currentModeOverride,
                  activeColor: AadiTheme.primarySaffron,
                  onChanged: (val) => state.setModeOverride(val!),
                ),
                const Divider(height: 1),
                RadioListTile<String>(
                  title: const Text("Odysseus Mode Only (Local)"),
                  subtitle: const Text("Forces all queries to local Ollama. Private and offline."),
                  value: "odysseus",
                  groupValue: state.currentModeOverride,
                  activeColor: AadiTheme.primarySaffron,
                  onChanged: (val) => state.setModeOverride(val!),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section: Personalization Settings
          _buildSectionHeader(theme, "Profile & Assistant Personalization"),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _userNameController,
                    decoration: const InputDecoration(
                      labelText: "Your Name",
                      hintText: "What should the assistant call you?",
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _assistantNameController,
                    decoration: const InputDecoration(
                      labelText: "Assistant Name",
                      hintText: "What would you like to name the assistant?",
                      prefixIcon: Icon(Icons.smart_toy),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AadiTheme.primarySaffron,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      final uName = _userNameController.text.trim();
                      final aName = _assistantNameController.text.trim();
                      if (uName.isNotEmpty && aName.isNotEmpty) {
                        state.updatePreferenceSetting(
                          userNameSetting: uName,
                          assistantNameSetting: aName,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Names updated successfully!")),
                        );
                      }
                    },
                    child: const Text("Save Custom Names"),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Section: Explicit Tone & Language Preference (Phase 2)
          _buildSectionHeader(theme, "Explicit AI Personality & Style"),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                children: [
                  ListTile(
                    title: const Text("Assistant Tone"),
                    subtitle: Text("Current: ${state.tone.toUpperCase()}"),
                    trailing: DropdownButton<String>(
                      value: state.tone,
                      items: const [
                        DropdownMenuItem(value: "formal", child: Text("Formal")),
                        DropdownMenuItem(value: "casual", child: Text("Casual")),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          state.updatePreferenceSetting(toneSetting: val);
                        }
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text("Primary Language"),
                    subtitle: Text("Current: ${state.language.toUpperCase()}"),
                    trailing: DropdownButton<String>(
                      value: state.language,
                      items: const [
                        DropdownMenuItem(value: "hinglish", child: Text("Hinglish (Hindi-English)")),
                        DropdownMenuItem(value: "english", child: Text("English")),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          state.updatePreferenceSetting(langSetting: val);
                        }
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text("Hinglish Implicit Ratio"),
                    subtitle: const Text("Learned Hinglish speech pattern mix"),
                    trailing: Text(
                      "${(state.hinglishRatio * 100).toStringAsFixed(0)}%",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AadiTheme.primarySaffron),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Section: Granular Permissions (Phase 2 Hardening)
          _buildSectionHeader(theme, "Granular Security Toggles"),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text("Google Calendar Sync"),
                  subtitle: const Text("Allow Aadi to view and schedule calendar events."),
                  value: state.permissionCalendar,
                  activeColor: AadiTheme.primarySaffron,
                  onChanged: (val) => state.updatePreferenceSetting(permCalendar: val),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text("Gmail Access"),
                  subtitle: const Text("Allow Aadi to draft email replies and read inbox."),
                  value: state.permissionEmail,
                  activeColor: AadiTheme.primarySaffron,
                  onChanged: (val) => state.updatePreferenceSetting(permEmail: val),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text("Real-time Location Alerts"),
                  subtitle: const Text("Allow location access for traffic adjusted reminders."),
                  value: state.permissionLocation,
                  activeColor: AadiTheme.primarySaffron,
                  onChanged: (val) => state.updatePreferenceSetting(permLocation: val),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text("Business Orders Sync"),
                  subtitle: const Text("Allow accessing e-commerce shipment and retail logistics data."),
                  value: state.permissionBusiness,
                  activeColor: AadiTheme.primarySaffron,
                  onChanged: (val) => state.updatePreferenceSetting(permBusiness: val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section: Server Configuration
          _buildSectionHeader(theme, "FastAPI Backend Connection"),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: "Backend Base URL",
                      hintText: "e.g., http://localhost:8000 or http://10.0.2.2:8000",
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _saveUrl,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text("Save URL"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AadiTheme.primarySaffron,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Section: Display & Profile
          _buildSectionHeader(theme, "Preferences"),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text("Dark Theme Mode"),
                  value: state.isDarkTheme,
                  activeColor: AadiTheme.primarySaffron,
                  onChanged: (val) => state.toggleTheme(),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text("User Memory Profile"),
                  subtitle: Text("${state.memories.length} facts remembered"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pushNamed(context, '/dashboard');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Log out Button
          ElevatedButton.icon(
            onPressed: () async {
              await state.logout();
              Navigator.pop(context); // Go back (AuthScreen handles screen swap)
            },
            icon: const Icon(Icons.logout),
            label: const Text("Logout Session"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: theme.brightness == Brightness.dark ? AadiTheme.secondaryCyan : AadiTheme.primarySaffron,
        ),
      ),
    );
  }
}
