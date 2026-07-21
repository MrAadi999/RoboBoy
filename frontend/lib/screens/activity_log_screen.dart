import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/app_state.dart';
import 'package:frontend/theme.dart';
import 'package:frontend/screens/auth_screen.dart'; // To use TerminalGridPainter

class ActivityLogScreen extends StatelessWidget {
  const ActivityLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final theme = Theme.of(context);
    final isDark = state.isDarkTheme;

    final Color primaryColor = isDark ? AadiTheme.hackerGreen : AadiTheme.primarySaffron;
    final Color secondaryColor = isDark ? AadiTheme.hackerCyan : AadiTheme.secondaryCyan;
    final Color terminalBg = isDark ? AadiTheme.hackerBg : AadiTheme.lightBg;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: terminalBg,
        appBar: AppBar(
          title: Text(
            isDark ? "AADI_AI // SYSTEM_SHELL_AUDIT" : "Audit Trail & Approvals",
            style: const TextStyle(fontFamily: 'monospace', fontSize: 16),
          ),
          bottom: TabBar(
            indicatorColor: primaryColor,
            labelColor: primaryColor,
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12),
            tabs: [
              Tab(
                icon: Icon(Icons.security, color: primaryColor),
                text: isDark ? "[GATE_LOCKS]" : "Confirmation Gate",
              ),
              Tab(
                icon: Icon(Icons.history_edu_outlined, color: primaryColor),
                text: isDark ? "[KERNEL_LOGS]" : "Activity Log",
              ),
            ],
          ),
          bottomOpacity: 1,
        ),
        body: Stack(
          children: [
            if (isDark)
              Positioned.fill(
                child: CustomPaint(
                  painter: TerminalGridPainter(),
                ),
              ),
            TabBarView(
              children: [
                _buildConfirmationGateTab(state, theme, context, isDark),
                _buildActivityLogTab(state, theme, isDark),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmationGateTab(AppState state, ThemeData theme, BuildContext context, bool isDark) {
    final Color primaryColor = isDark ? AadiTheme.hackerGreen : AadiTheme.primarySaffron;
    final Color terminalCard = isDark ? AadiTheme.hackerCard : AadiTheme.lightCard;

    if (state.pendingConfirmations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: isDark ? AadiTheme.hackerGreen : Colors.green),
            const SizedBox(height: 16),
            Text(
              isDark ? "[OK] SECURE: NO_PENDING_GATE_LOCKS" : "No pending confirmations!",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: isDark ? AadiTheme.hackerGreen : null),
            ),
            const SizedBox(height: 8),
            Text(
              isDark ? "SYS_THREAD: Sensitive background injections will queue here." : "Any sensitive actions will queue here for approval.",
              style: TextStyle(color: isDark ? AadiTheme.hackerTextSecondary : Colors.grey, fontFamily: 'monospace', fontSize: 12),
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

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: terminalCard.withOpacity(0.9),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isDark ? AadiTheme.hackerAmber.withOpacity(0.6) : AadiTheme.primarySaffron,
              width: 1.5,
            ),
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
                          actionType == "send_email" ? Icons.alternate_email : Icons.calendar_month,
                          color: isDark ? AadiTheme.hackerAmber : AadiTheme.primarySaffron,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          actionType == "send_email" 
                            ? (isDark ? "PENDING_EMAIL_INJECT" : "Pending Email Draft")
                            : (isDark ? "PENDING_CALENDAR_WRITE" : "Pending Calendar Event"),
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 14, 
                            fontFamily: 'monospace',
                            color: isDark ? AadiTheme.hackerAmber : Colors.black87
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? AadiTheme.hackerAmber.withOpacity(0.1) : AadiTheme.primarySaffron,
                        border: isDark ? Border.all(color: AadiTheme.hackerAmber) : null,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isDark ? "GATE_LOCKED" : "Gate Locked", 
                        style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'monospace')
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 12),

                // Payload details
                if (actionType == "send_email") ...[
                  Text(
                    "TO: ${payload['to'] ?? ''}", 
                    style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 12, color: isDark ? AadiTheme.hackerGreen : Colors.black87)
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "SUBJECT: ${payload['subject'] ?? ''}", 
                    style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 12, color: isDark ? AadiTheme.hackerGreen : Colors.black87)
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black38 : Colors.grey.shade100,
                      border: isDark ? Border.all(color: AadiTheme.hackerGreen.withOpacity(0.2)) : null,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      payload['body'] ?? '',
                      style: TextStyle(
                        fontSize: 12, 
                        height: 1.4, 
                        fontFamily: 'monospace',
                        color: isDark ? AadiTheme.hackerGreen : Colors.black87
                      ),
                    ),
                  ),
                ] else if (actionType == "add_calendar") ...[
                  Text(
                    "TITLE: ${payload['title'] ?? ''}", 
                    style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 12, color: isDark ? AadiTheme.hackerGreen : Colors.black87)
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "TIME: ${payload['time'] ?? ''} (${payload['date'] ?? ''})", 
                    style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 12, color: isDark ? AadiTheme.hackerGreen : Colors.black87)
                  ),
                ],
                const SizedBox(height: 16),

                // Explainability Trace
                if (explanation != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? AadiTheme.hackerCyan.withOpacity(0.05) : AadiTheme.secondaryCyan.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: isDark ? AadiTheme.hackerCyan.withOpacity(0.3) : AadiTheme.secondaryCyan.withOpacity(0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.psychology, size: 16, color: isDark ? AadiTheme.hackerCyan : AadiTheme.secondaryCyan),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isDark ? "DECISION_LOGIC: $explanation" : "Why Aadi did this: $explanation",
                            style: TextStyle(
                              fontSize: 11, 
                              color: isDark ? AadiTheme.hackerCyan : AadiTheme.secondaryCyan, 
                              fontStyle: FontStyle.italic,
                              fontFamily: 'monospace'
                            ),
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
                            SnackBar(
                              content: Text("SYS_INFO: Action aborted and deleted.", style: const TextStyle(fontFamily: 'monospace')),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.close, color: Colors.redAccent, size: 18),
                      label: Text(
                        isDark ? "< ABORT_INJECT >" : "Deny", 
                        style: const TextStyle(color: Colors.redAccent, fontFamily: 'monospace', fontWeight: FontWeight.bold)
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final success = await state.handleConfirmationGate(actionId, true);
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("SYS_INFO: Action approved and executed.", style: const TextStyle(fontFamily: 'monospace')),
                              backgroundColor: isDark ? AadiTheme.hackerCard : Colors.green,
                            ),
                          );
                        }
                      },
                      icon: Icon(Icons.check, color: isDark ? AadiTheme.hackerGreen : Colors.white, size: 18),
                      label: Text(
                        isDark ? "[ CONFIRM_EXECUTE ]" : "Approve", 
                        style: TextStyle(color: isDark ? AadiTheme.hackerGreen : Colors.white, fontFamily: 'monospace', fontWeight: FontWeight.bold)
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.transparent : Colors.green,
                        side: isDark ? const BorderSide(color: AadiTheme.hackerGreen, width: 1.5) : null,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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

  Widget _buildActivityLogTab(AppState state, ThemeData theme, bool isDark) {
    if (state.activityLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: isDark ? AadiTheme.hackerGreen.withOpacity(0.5) : Colors.grey),
            const SizedBox(height: 16),
            Text(
              isDark ? "[OK] NO_LOGS_YET_RECORDED" : "No logs available yet.",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: isDark ? AadiTheme.hackerGreen : null),
            ),
            const SizedBox(height: 8),
            Text(
              isDark ? "SYS_THREAD: Logging engine is listening on thread port..." : "Activity logs will update as you execute actions.",
              style: TextStyle(color: isDark ? AadiTheme.hackerTextSecondary : Colors.grey, fontFamily: 'monospace', fontSize: 12),
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
        String statusLabel = "INFO";
        if (status == "completed") {
          statusColor = isDark ? AadiTheme.hackerGreen : Colors.green;
          statusLabel = "SUCCESS";
        } else if (status == "failed") {
          statusColor = Colors.redAccent;
          statusLabel = "CRIT_FAIL";
        } else if (status == "denied") {
          statusColor = Colors.orangeAccent;
          statusLabel = "ABORTED";
        } else if (status == "pending_confirmation") {
          statusColor = isDark ? AadiTheme.hackerAmber : AadiTheme.primarySaffron;
          statusLabel = "GATE_LOCKED";
        }

        // Clean timestamp presentation
        String formattedTime = timeStr;
        try {
          final parsed = DateTime.parse(timeStr);
          formattedTime = "${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}:${parsed.second.toString().padLeft(2, '0')} - ${parsed.day}/${parsed.month}";
        } catch (_) {}

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14.0),
          decoration: BoxDecoration(
            color: isDark ? AadiTheme.hackerCard.withOpacity(0.8) : Colors.white,
            border: Border.all(
              color: isDark ? statusColor.withOpacity(0.3) : Colors.grey.shade300,
              width: 1.0,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: statusColor.withOpacity(0.4)),
                        ),
                        child: Text(
                          "[$statusLabel]",
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        type.toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 11, 
                          color: isDark ? AadiTheme.hackerGreen : Colors.black87,
                          fontFamily: 'monospace'
                        ),
                      ),
                    ],
                  ),
                  Text(
                    formattedTime,
                    style: const TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'monospace'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12, 
                  fontWeight: FontWeight.bold, 
                  fontFamily: 'monospace', 
                  color: isDark ? AadiTheme.hackerGreen.withOpacity(0.9) : Colors.black87
                ),
              ),
              if (explanation != null && explanation.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  "SYS_TRACE: $explanation",
                  style: TextStyle(
                    fontSize: 11, 
                    color: isDark ? AadiTheme.hackerCyan : Colors.grey.shade600, 
                    fontStyle: FontStyle.italic,
                    fontFamily: 'monospace'
                  ),
                ),
              ]
            ],
          ),
        );
      },
    );
  }
}
