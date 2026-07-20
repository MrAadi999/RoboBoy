import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/app_state.dart';
import 'package:frontend/theme.dart';

class ActivityLogScreen extends StatelessWidget {
  const ActivityLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Audit Trail & Approvals"),
          bottom: const TabBar(
            indicatorColor: AadiTheme.primarySaffron,
            labelColor: AadiTheme.primarySaffron,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(
                icon: Icon(Icons.security),
                text: "Confirmation Gate",
              ),
              Tab(
                icon: Icon(Icons.history),
                text: "Activity Log",
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildConfirmationGateTab(state, theme, context),
            _buildActivityLogTab(state, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmationGateTab(AppState state, ThemeData theme, BuildContext context) {
    if (state.pendingConfirmations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text(
              "No pending confirmations!",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              "Any sensitive actions will queue here for approval.",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.pendingConfirmations.length,
      itemBuilder: (context, index) {
        final item = state.pendingConfirmations[index];
        final actionId = item["id"] as int;
        final actionType = item["action_type"] as String;
        final explanation = item["explanation"] as String?;
        
        Map<String, dynamic> payload = {};
        try {
          payload = jsonDecode(item["payload"]);
        } catch (_) {}

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AadiTheme.primarySaffron, width: 0.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          actionType == "send_email" ? Icons.email_outlined : Icons.calendar_today_outlined,
                          color: AadiTheme.primarySaffron,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          actionType == "send_email" ? "Pending Email Draft" : "Pending Calendar Event",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    const Chip(
                      label: Text("Gate Locked", style: TextStyle(fontSize: 10, color: Colors.white)),
                      backgroundColor: AadiTheme.primarySaffron,
                    )
                  ],
                ),
                const SizedBox(height: 12),

                // Payload details
                if (actionType == "send_email") ...[
                  Text("To: ${payload['to'] ?? ''}", style: const TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text("Subject: ${payload['subject'] ?? ''}", style: const TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.dark ? Colors.black26 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      payload['body'] ?? '',
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ),
                ] else if (actionType == "add_calendar") ...[
                  Text("Title: ${payload['title'] ?? ''}", style: const TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text("Time: ${payload['time'] ?? ''} (${payload['date'] ?? ''})", style: const TextStyle(fontWeight: FontWeight.w500)),
                ],
                const SizedBox(height: 16),

                // Explainability Trace
                if (explanation != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AadiTheme.secondaryCyan.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AadiTheme.secondaryCyan.withOpacity(0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.psychology, size: 18, color: AadiTheme.secondaryCyan),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Why Aadi did this: $explanation",
                            style: const TextStyle(fontSize: 12, color: AadiTheme.secondaryCyan, fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        final success = await state.handleConfirmationGate(actionId, false);
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Action rejected and cancelled.")),
                          );
                        }
                      },
                      icon: const Icon(Icons.close, color: Colors.red),
                      label: const Text("Deny", style: TextStyle(color: Colors.red)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final success = await state.handleConfirmationGate(actionId, true);
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Action approved and executed.")),
                          );
                        }
                      },
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: const Text("Approve", style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActivityLogTab(AppState state, ThemeData theme) {
    if (state.activityLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              "No logs available yet.",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              "Activity logs will update as you execute actions.",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.activityLogs.length,
      itemBuilder: (context, index) {
        final item = state.activityLogs[index];
        final type = item["action_type"] as String;
        final description = item["description"] as String;
        final status = item["status"] as String;
        final explanation = item["explanation"] as String?;
        final timeStr = item["timestamp"] as String;

        Color statusColor = Colors.grey;
        IconData statusIcon = Icons.info_outline;
        if (status == "completed") {
          statusColor = Colors.green;
          statusIcon = Icons.check;
        } else if (status == "failed") {
          statusColor = Colors.red;
          statusIcon = Icons.error_outline;
        } else if (status == "denied") {
          statusColor = Colors.orange;
          statusIcon = Icons.block;
        } else if (status == "pending_confirmation") {
          statusColor = AadiTheme.primarySaffron;
          statusIcon = Icons.lock_clock;
        }

        // Clean timestamp presentation
        String formattedTime = timeStr;
        try {
          final parsed = DateTime.parse(timeStr);
          formattedTime = "${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')} - ${parsed.day}/${parsed.month}";
        } catch (_) {}

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(statusIcon, color: statusColor, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          type.toUpperCase(),
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: statusColor),
                        ),
                      ],
                    ),
                    Text(
                      formattedTime,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                if (explanation != null && explanation.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    "Trace: $explanation",
                    style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7), fontStyle: FontStyle.italic),
                  ),
                ]
              ],
            ),
          ),
        );
      },
    );
  }
}
