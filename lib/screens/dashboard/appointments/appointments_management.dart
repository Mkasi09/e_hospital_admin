import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key});

  String getStatusText(String status) {
    switch (status) {
      case "confirmed":
        return "Confirmed";
      case "pending":
        return "Pending";
      case "completed":
        return "Completed";
      case "in-progress":
        return "In Progress";
      case "cancelled":
        return "Cancelled";
      default:
        return "Unknown";
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case "confirmed":
        return Colors.green;
      case "pending":
        return Colors.orange;
      case "completed":
        return Colors.grey;
      case "in-progress":
        return Colors.blue;
      case "cancelled":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// 🔹 Update status in Firestore
  Future<void> updateStatus(String docId, String newStatus) async {
    await FirebaseFirestore.instance
        .collection("appointments")
        .doc(docId)
        .update({"status": newStatus});
  }

  /// 🔹 Show dialog with status options
  void showManageDialog(
    BuildContext context,
    String docId,
    String currentStatus,
  ) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text("Manage Appointment"),
            content: const Text("Select a new status for this appointment:"),
            actions: [
              TextButton(
                onPressed: () {
                  updateStatus(docId, "confirmed");
                  Navigator.pop(ctx);
                },
                child: const Text("Confirm"),
              ),
              TextButton(
                onPressed: () {
                  updateStatus(docId, "completed");
                  Navigator.pop(ctx);
                },
                child: const Text("Complete"),
              ),
              TextButton(
                onPressed: () {
                  updateStatus(docId, "cancelled");
                  Navigator.pop(ctx);
                },
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Close"),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Appointments"),
        actions: [
          TextButton.icon(
            onPressed: () {
              // TODO: Open appointment scheduling screen
            },
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              "Schedule",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection("appointments")
                .orderBy("date") // using timestamp field for sorting
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No appointments found."));
          }

          final appointments = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: appointments.length,
            itemBuilder: (context, index) {
              final doc = appointments[index];
              final appt = doc.data() as Map<String, dynamic>;
              final docId = doc.id;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 🔹 Time + Details
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appt["time"] ?? "",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "${appt["date"].toDate()}".split(
                                ".",
                              )[0], // show readable date
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${appt["patientName"]} (${appt["appointmentType"]})",
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              "${appt["doctor"]} • ${appt["hospital"]}",
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // 🔹 Status + Manage button
                    Column(
                      children: [
                        Chip(
                          label: Text(getStatusText(appt["status"] ?? "")),
                          backgroundColor: getStatusColor(
                            appt["status"] ?? "",
                          ).withOpacity(0.2),
                          labelStyle: TextStyle(
                            color: getStatusColor(appt["status"] ?? ""),
                          ),
                        ),
                        const SizedBox(height: 6),
                        OutlinedButton(
                          onPressed:
                              () => showManageDialog(
                                context,
                                docId,
                                appt["status"] ?? "",
                              ),
                          child: const Text("Manage"),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
