import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/app_state.dart';
import 'package:frontend/theme.dart';
import 'package:frontend/screens/auth_screen.dart'; // To use TerminalGridPainter

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _factController = TextEditingController();

  void _addFact() async {
    final fact = _factController.text.trim();
    if (fact.isEmpty) return;

    final state = Provider.of<AppState>(context, listen: false);
    final success = await state.addNewMemory(fact);
    if (success) {
      _factController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("SYS_SUCCESS: Context injected into memory registry.", style: const TextStyle(fontFamily: 'monospace')),
          backgroundColor: AadiTheme.hackerCard,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("SYS_ERR: Failed to write context data.", style: const TextStyle(fontFamily: 'monospace')),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _deleteFact(int id) async {
    final state = Provider.of<AppState>(context, listen: false);
    final success = await state.deleteOldMemory(id);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("SYS_SUCCESS: Registry key purged successfully.", style: const TextStyle(fontFamily: 'monospace')),
          backgroundColor: AadiTheme.hackerCard,
        ),
      );
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
    final Color terminalCard = isDark ? AadiTheme.hackerCard : AadiTheme.lightCard;

    // Extract user username prefix from contact email/phone
    String username = "AADI";
    if (state.phoneOrEmail.isNotEmpty) {
      final parts = state.phoneOrEmail.split('@');
      username = parts[0].toUpperCase();
    }

    return Scaffold(
      backgroundColor: terminalBg,
      appBar: AppBar(
        title: Text(
          isDark ? "AADI_AI // MEMORY_CORE_REGISTRY" : "Memory Core Registry",
          style: const TextStyle(fontFamily: 'monospace', fontSize: 16),
        ),
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
          if (isDark)
            Positioned.fill(
              child: CustomPaint(
                painter: TerminalGridPainter(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Indian-style personalized greeting card styled as diagnostics terminal
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: terminalCard.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? AadiTheme.hackerGreen.withOpacity(0.5) : Colors.orange.shade300,
                      width: 1.5,
                    ),
                    boxShadow: isDark ? [
                      BoxShadow(
                        color: AadiTheme.hackerGreen.withOpacity(0.05),
                        blurRadius: 10,
                      )
                    ] : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isDark ? "SYS_USER: $username" : "Namaste, $username!",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isDark 
                          ? "REGISTRY_PATH: sqlite:///aadi_ai.db/memory\n"
                            "STATUS: SECTORS_SYNCHRONIZED\n"
                            "TRAVERSAL MODE: READ_WRITE\n\n"
                            "Context registries allow Fugu and Odysseus to retain deep memory on custom constraints."
                          : "This panel stores persistent facts and memories that Aadi AI uses to contextualize your schedules, traffic warnings, and custom queries.",
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AadiTheme.hackerTextSecondary : Colors.black87,
                          fontFamily: 'monospace',
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Form to add a new memory
                Text(
                  isDark ? "WRITE_NEW_CONTEXT_KEY >" : "Add custom context facts",
                  style: isDark ? const TextStyle(color: AadiTheme.hackerCyan, fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 13) : theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _factController,
                        style: TextStyle(fontFamily: isDark ? 'monospace' : null, color: isDark ? AadiTheme.hackerGreen : null),
                        decoration: InputDecoration(
                          hintText: isDark ? "Enter custom context data..." : "Add details...",
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _addFact,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.transparent : AadiTheme.secondaryCyan,
                          border: isDark ? Border.all(color: AadiTheme.hackerGreen, width: 1.5) : null,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.add_to_photos_outlined,
                          color: isDark ? AadiTheme.hackerGreen : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Fact List Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isDark ? "ACTIVE_REGISTRY_KEYS" : "Remembered facts",
                      style: isDark ? const TextStyle(color: AadiTheme.hackerGreen, fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 13) : theme.textTheme.titleMedium,
                    ),
                    Text(
                      isDark ? "[TOTAL_KEYS: ${state.memories.length}]" : "${state.memories.length} facts in memory",
                      style: TextStyle(color: isDark ? AadiTheme.hackerCyan : Colors.grey, fontFamily: 'monospace', fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Fact List
                Expanded(
                  child: state.memories.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.query_stats_outlined, size: 48, color: primaryColor.withOpacity(0.5)),
                            const SizedBox(height: 12),
                            Text(
                              isDark ? "NO_MEMORY_REGISTRIES_FOUND" : "No persistent memories found.",
                              style: TextStyle(color: isDark ? AadiTheme.hackerTextSecondary : Colors.grey, fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: state.memories.length,
                        itemBuilder: (context, index) {
                          final item = state.memories[index];
                          final idText = index.toString().padLeft(3, '0');
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 6.0),
                            decoration: BoxDecoration(
                              color: terminalCard.withOpacity(0.8),
                              border: Border.all(color: isDark ? AadiTheme.hackerGreen.withOpacity(0.2) : Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: ListTile(
                              leading: Text(
                                "[REG_$idText]",
                                style: TextStyle(
                                  color: isDark ? AadiTheme.hackerCyan : AadiTheme.primarySaffron,
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold
                                ),
                              ),
                              title: Text(
                                item["fact"] ?? "",
                                style: TextStyle(
                                  color: isDark ? AadiTheme.hackerGreen : Colors.black87,
                                  fontFamily: isDark ? 'monospace' : null,
                                  fontSize: 13
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_forever_outlined, color: Colors.redAccent, size: 20),
                                tooltip: isDark ? "PURGE_KEY" : "Delete Memory",
                                onPressed: () => _deleteFact(item["id"]),
                              ),
                            ),
                          );
                        },
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
