import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/app_state.dart';
import 'package:frontend/theme.dart';

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
        const SnackBar(content: Text("New context saved to memory.")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to save memory. Check backend.")),
      );
    }
  }

  void _deleteFact(int id) async {
    final state = Provider.of<AppState>(context, listen: false);
    final success = await state.deleteOldMemory(id);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Memory deleted.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final theme = Theme.of(context);

    // Extract user username prefix from contact email/phone
    String username = "Aadi";
    if (state.phoneOrEmail.isNotEmpty) {
      final parts = state.phoneOrEmail.split('@');
      username = parts[0];
      // Capitalize first letter
      username = username[0].toUpperCase() + username.substring(1);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Memory Profile"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Indian-style personalized greeting card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AadiTheme.primarySaffron, Color(0xFFC75200)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AadiTheme.primarySaffron.withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Namaste, $username!",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Main aapki saari preferences aur details yaad rakhta hoon taaki mere replies personalized hon.",
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFFE5E7EB), // Soft white/grey
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Form to add a new memory
            Text(
              "Add details about yourself:",
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _factController,
                    decoration: const InputDecoration(
                      hintText: "e.g., I live in New Delhi or I prefer coffee",
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _addFact,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AadiTheme.secondaryCyan,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Colors.black87,
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
                  "Remembered Facts",
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  "${state.memories.length} facts total",
                  style: theme.textTheme.bodyMedium,
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
                      children: const [
                        Icon(Icons.psychology_outlined, size: 48, color: Colors.grey),
                        SizedBox(height: 12),
                        Text(
                          "No memory data found.",
                          style: TextStyle(color: Colors.grey),
                        ),
                        Text(
                          "Tell Aadi your preferences to start saving context!",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: state.memories.length,
                    itemBuilder: (context, index) {
                      final item = state.memories[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6.0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: const Icon(Icons.star_border, color: AadiTheme.primarySaffron),
                          title: Text(item["fact"] ?? ""),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
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
    );
  }
}
