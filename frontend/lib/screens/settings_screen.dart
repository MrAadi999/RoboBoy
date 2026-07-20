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
    final state = Provider.of<AppState>(context, listen: false);
    final url = _urlController.text.trim();
    if (url.isNotEmpty) {
      state.setBackendUrl(url);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${state.translate("url_updated")} $url")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(state.translate("settings_title")),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Section: Routing Settings
          _buildSectionHeader(theme, state.translate("routing_modes")),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                RadioListTile<String>(
                  title: Text(state.translate("smart_router")),
                  subtitle: Text(state.translate("smart_router_sub")),
                  value: "auto",
                  groupValue: state.currentModeOverride,
                  activeColor: AadiTheme.primarySaffron,
                  onChanged: (val) => state.setModeOverride(val!),
                ),
                const Divider(height: 1),
                RadioListTile<String>(
                  title: Text(state.translate("fugu_mode")),
                  subtitle: Text(state.translate("fugu_mode_sub")),
                  value: "fugu",
                  groupValue: state.currentModeOverride,
                  activeColor: AadiTheme.primarySaffron,
                  onChanged: (val) => state.setModeOverride(val!),
                ),
                const Divider(height: 1),
                RadioListTile<String>(
                  title: Text(state.translate("odysseus_mode")),
                  subtitle: Text(state.translate("odysseus_mode_sub")),
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
          _buildSectionHeader(theme, state.translate("profile_header")),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _userNameController,
                    decoration: InputDecoration(
                      labelText: state.translate("your_name"),
                      hintText: state.translate("your_name_hint"),
                      prefixIcon: const Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _assistantNameController,
                    decoration: InputDecoration(
                      labelText: state.translate("assistant_name"),
                      hintText: state.translate("assistant_name_hint"),
                      prefixIcon: const Icon(Icons.smart_toy),
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
                          SnackBar(content: Text(state.translate("names_updated"))),
                        );
                      }
                    },
                    child: Text(state.translate("save_names")),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Section: Explicit Tone & Language Preference (Phase 2)
          _buildSectionHeader(theme, state.translate("ai_style_header")),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                children: [
                  ListTile(
                    title: Text(state.translate("assistant_tone")),
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
                    title: Text(state.translate("dash_lang")),
                    subtitle: Text("Current: ${state.dashboardLanguage.toUpperCase()}"),
                    trailing: DropdownButton<String>(
                      value: state.dashboardLanguage.toLowerCase(),
                      items: const [
                        DropdownMenuItem(value: "english", child: Text("English")),
                        DropdownMenuItem(value: "hinglish", child: Text("Hinglish")),
                        DropdownMenuItem(value: "hindi", child: Text("Hindi (हिन्दी)")),
                        DropdownMenuItem(value: "german", child: Text("German (Deutsch)")),
                        DropdownMenuItem(value: "chinese", child: Text("Chinese (中文)")),
                        DropdownMenuItem(value: "bhojpuri", child: Text("Bhojpuri (भोजपुरी)")),
                        DropdownMenuItem(value: "maithili", child: Text("Maithili (मैथिली)")),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          state.updatePreferenceSetting(dashboardLangSetting: val);
                        }
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: Text(state.translate("char_lang")),
                    subtitle: Text("Current: ${state.characterLanguage.toUpperCase()}"),
                    trailing: DropdownButton<String>(
                      value: state.characterLanguage.toLowerCase(),
                      items: const [
                        DropdownMenuItem(value: "english", child: Text("English")),
                        DropdownMenuItem(value: "hinglish", child: Text("Hinglish")),
                        DropdownMenuItem(value: "hindi", child: Text("Hindi (हिन्दी)")),
                        DropdownMenuItem(value: "german", child: Text("German (Deutsch)")),
                        DropdownMenuItem(value: "chinese", child: Text("Chinese (中文)")),
                        DropdownMenuItem(value: "bhojpuri", child: Text("Bhojpuri (भोजपुरी)")),
                        DropdownMenuItem(value: "maithili", child: Text("Maithili (मैथिली)")),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          state.updatePreferenceSetting(characterLangSetting: val);
                        }
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: Text(state.translate("implicit_ratio")),
                    subtitle: Text(state.translate("implicit_ratio_sub")),
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
          _buildSectionHeader(theme, state.translate("security_header")),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(state.translate("cal_sync")),
                  subtitle: Text(state.translate("cal_sync_sub")),
                  value: state.permissionCalendar,
                  activeColor: AadiTheme.primarySaffron,
                  onChanged: (val) => state.updatePreferenceSetting(permCalendar: val),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: Text(state.translate("gmail_access")),
                  subtitle: Text(state.translate("gmail_access_sub")),
                  value: state.permissionEmail,
                  activeColor: AadiTheme.primarySaffron,
                  onChanged: (val) => state.updatePreferenceSetting(permEmail: val),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: Text(state.translate("loc_alerts")),
                  subtitle: Text(state.translate("loc_alerts_sub")),
                  value: state.permissionLocation,
                  activeColor: AadiTheme.primarySaffron,
                  onChanged: (val) => state.updatePreferenceSetting(permLocation: val),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: Text(state.translate("business_sync")),
                  subtitle: Text(state.translate("business_sync_sub")),
                  value: state.permissionBusiness,
                  activeColor: AadiTheme.primarySaffron,
                  onChanged: (val) => state.updatePreferenceSetting(permBusiness: val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section: Server Connection
          _buildSectionHeader(theme, state.translate("backend_header")),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      labelText: state.translate("backend_url"),
                      hintText: "e.g., http://localhost:8000 or http://10.0.2.2:8000",
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _saveUrl,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(state.translate("save_url")),
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
          _buildSectionHeader(theme, state.translate("pref_header")),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(state.translate("dark_mode")),
                  value: state.isDarkTheme,
                  activeColor: AadiTheme.primarySaffron,
                  onChanged: (val) => state.toggleTheme(),
                ),
                const Divider(height: 1),
                ListTile(
                  title: Text(state.translate("memory_profile")),
                  subtitle: Text("${state.memories.length} ${state.translate("facts_count")}"),
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
            label: Text(state.translate("logout")),
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
