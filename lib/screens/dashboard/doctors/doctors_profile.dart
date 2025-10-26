import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';

class DoctorProfilePage extends StatefulWidget {
  final String doctorId;

  const DoctorProfilePage({super.key, required this.doctorId});

  @override
  State<DoctorProfilePage> createState() => _DoctorProfilePageState();

  // Static method to show the profile as a dialog
  static void show(BuildContext context, String doctorId) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => DoctorProfilePage(doctorId: doctorId),
    );
  }
}

class _DoctorProfilePageState extends State<DoctorProfilePage> {
  bool showSchedule = false; // Toggle between profile and schedule
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _appointmentsMap = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchAppointments();
  }

  Future<void> _fetchAppointments() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('appointments')
        .where('doctorId', isEqualTo: widget.doctorId)
        .where('status', isEqualTo: "confirmed")
        .get();

    final events = <DateTime, List<Map<String, dynamic>>>{};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final date = (data['date'] as Timestamp).toDate();
      final dayKey = DateTime(date.year, date.month, date.day);

      if (events.containsKey(dayKey)) {
        events[dayKey]!.add(data);
      } else {
        events[dayKey] = [data];
      }
    }

    setState(() {
      _appointmentsMap = events;
    });
  }

  List<Map<String, dynamic>> _getAppointmentsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _appointmentsMap[key] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    if (showSchedule) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: _buildScheduleView(context),
        ),
      );
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection("users").doc(widget.doctorId).get(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _buildErrorState(context);
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingState();
            }

            final data = snapshot.data!.data() as Map<String, dynamic>?;

            if (data == null) {
              return _buildNotFoundState(context);
            }

            return _buildProfileContent(context, data);
          },
        ),
      ),
    );
  }

  // Loading state
  Widget _buildLoadingState() => const Center(
    child: Padding(
      padding: EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading Doctor Profile...', style: TextStyle(fontSize: 16, color: Colors.grey)),
        ],
      ),
    ),
  );

  // Error state
  Widget _buildErrorState(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 60, color: Colors.red),
          const SizedBox(height: 16),
          const Text('Error Loading Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
          const SizedBox(height: 8),
          const Text('Please try again later', style: TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
        ],
      ),
    ),
  );

  // Not Found
  Widget _buildNotFoundState(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person_off, size: 60, color: Colors.orange),
          const SizedBox(height: 16),
          const Text('Profile Not Found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
          const SizedBox(height: 8),
          const Text('The doctor profile could not be found', style: TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
        ],
      ),
    ),
  );

  // Profile content
  Widget _buildProfileContent(BuildContext context, Map<String, dynamic> data) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text("Doctor Profile", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.blue),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildProfileHeader(data),
                const SizedBox(height: 20),
                _buildInfoSection(
                  title: "Professional Information",
                  icon: Icons.work,
                  color: Colors.blue,
                  children: [
                    _buildInfoRow(icon: Icons.star, label: "Rating", value: "${data["rating"] ?? 0} / 5"),
                    _buildInfoRow(icon: Icons.badge, label: "Experience", value: data["experience"] ?? "N/A"),
                  ],
                ),
                const SizedBox(height: 20),
                _buildInfoSection(
                  title: "Contact Information",
                  icon: Icons.contact_mail,
                  color: Colors.green,
                  children: [
                    _buildInfoRow(icon: Icons.email, label: "Email", value: data["email"] ?? "Not provided"),
                    _buildInfoRow(icon: Icons.phone, label: "Phone", value: data["phone"] ?? "Not provided"),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => setState(() => showSchedule = true),
                  icon: const Icon(Icons.schedule),
                  label: const Text("View Schedule"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Schedule view
  Widget _buildScheduleView(BuildContext context) {
    final appointments = _getAppointmentsForDay(_selectedDay ?? _focusedDay);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFFE3F2FD),
            borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
          ),
          child: Row(
            children: [
              const Expanded(child: Text("Doctor Schedule", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue))),
              IconButton(icon: const Icon(Icons.close, color: Colors.blue), onPressed: () => setState(() => showSchedule = false)),
            ],
          ),
        ),
        TableCalendar(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selectedDay, focusedDay) => setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          }),
          eventLoader: _getAppointmentsForDay,
        ),
        const SizedBox(height: 8),
        Text("Appointments: ${appointments.length}", style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Expanded(
          child: appointments.isEmpty
              ? const Center(child: Text("No appointments scheduled."))
              : ListView.builder(
            itemCount: appointments.length,
            itemBuilder: (context, index) {
              final data = appointments[index];
              final date = (data['date'] as Timestamp).toDate();
              final start = DateFormat('hh:mm a').format(date);
              final end = DateFormat('hh:mm a').format(date.add(const Duration(minutes: 30)));
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.access_time, color: Colors.blue),
                  title: Text(data['patientName'] ?? 'Unknown'),
                  subtitle: Text('$start - $end'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Helper widgets
  Widget _buildProfileHeader(Map<String, dynamic> data) => Column(
    children: [
      CircleAvatar(
        radius: 50,
        backgroundColor: Colors.blue.shade100,
        backgroundImage: data["avatar"] != null ? NetworkImage(data["avatar"]) : null,
        child: data["avatar"] == null ? const Icon(Icons.person, size: 50, color: Colors.blue) : null,
      ),
      const SizedBox(height: 12),
      Text(data["name"] ?? "Unknown Doctor", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      Text(data["specialty"] ?? "General Practitioner", style: TextStyle(color: Colors.blue.shade600)),
    ],
  );

  Widget _buildInfoSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: color), const SizedBox(width: 8), Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color))]),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow({required IconData icon, required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text("$label: $value", style: const TextStyle(fontSize: 14, color: Colors.black87)),
          ),
        ],
      ),
    );
  }
}
