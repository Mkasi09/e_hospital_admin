import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  String? selectedDoctor;
  String? selectedStatus;
  DateTime? startDate;
  DateTime? endDate;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<String> doctors = [];

  @override
  void initState() {
    super.initState();
    _fetchDoctors();
  }

  Map<String, String> doctorMap = {}; // name -> id

  Future<void> _fetchDoctors() async {
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'doctor')
        .get();

    setState(() {
      doctorMap = {
        for (var doc in query.docs) doc['name']: doc.id
      };
      doctors = doctorMap.keys.toList();
    });
  }


  void _updateStatus(DocumentReference docRef, String newStatus, BuildContext context) async {
    Navigator.pop(context); // Close sheet
    await docRef.update({'status': newStatus});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Updated to "$newStatus"')));
  }

  Stream<QuerySnapshot> _getFilteredStream() {
    Query query = FirebaseFirestore.instance.collection('appointments');

    if (selectedDoctor != null && selectedDoctor!.isNotEmpty) {
      final selectedDoctorId = doctorMap[selectedDoctor];
      query = query.where('doctorId', isEqualTo: selectedDoctorId);
    }

    if (selectedStatus != null && selectedStatus!.isNotEmpty) {
      query = query.where('status', isEqualTo: selectedStatus);
    }
    if (startDate != null) {
      query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate!));
    }
    if (endDate != null) {
      query = query.where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate!));
    }

    return query.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: Drawer(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Filters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedDoctor,
              decoration: const InputDecoration(labelText: 'Doctor'),
              items: doctors.map((docName) {
                return DropdownMenuItem(value: docName, child: Text(docName));
              }).toList(),
              onChanged: (val) => setState(() => selectedDoctor = val),
            ),

            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedStatus,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(value: 'confirmed', child: Text('Confirmed')),
                DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
              ],
              onChanged: (val) => setState(() => selectedStatus = val),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Start Date'),
              subtitle: Text(startDate?.toLocal().toString().split(' ')[0] ?? 'Select'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: startDate ?? DateTime.now(),
                  firstDate: DateTime(2023),
                  lastDate: DateTime(2026),
                );
                if (picked != null) setState(() => startDate = picked);
              },
            ),
            ListTile(
              title: const Text('End Date'),
              subtitle: Text(endDate?.toLocal().toString().split(' ')[0] ?? 'Select'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: endDate ?? DateTime.now(),
                  firstDate: DateTime(2023),
                  lastDate: DateTime(2026),
                );
                if (picked != null) setState(() => endDate = picked);
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context), // close drawer
              child: const Text('Apply Filters'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  selectedDoctor = null;
                  selectedStatus = null;
                  startDate = null;
                  endDate = null;
                });
                Navigator.pop(context);
              },
              child: const Text('Clear Filters'),
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: const Text('Appointments (Admin)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt_outlined),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: _getFilteredStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('No appointments found.'));
            }

            final appointments = snapshot.data!.docs;

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: appointments.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final doc = appointments[index];
                final data = doc.data() as Map<String, dynamic>;

                final patient = data['patientName'] ?? 'Unknown';
                final doctor = data['doctor'] ?? 'Unknown';
                final time = data['time'] ?? '';
                final status = data['status'] ?? 'pending';

                final dateTimestamp = data['date'];
                final date = dateTimestamp is Timestamp
                    ? dateTimestamp.toDate()
                    : DateTime.tryParse(dateTimestamp.toString());

                final dateStr = date != null
                    ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
                    : 'Invalid date';

                return ListTile(
                  title: Text('$patient - $doctor'),
                  subtitle: Text('$dateStr at $time'),
                  leading: CircleAvatar(
                    backgroundColor: status == 'pending'
                        ? Colors.orange
                        : status == 'confirmed'
                        ? Colors.green
                        : Colors.grey,
                    radius: 6,
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'view') {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Appointment Details'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Patient: $patient'),
                                Text('Doctor: $doctor'),
                                Text('Date: $dateStr'),
                                Text('Time: $time'),
                                Text('Status: $status'),
                                Text('Reason: ${data['reason'] ?? "N/A"}'),
                                Text('Hospital: ${data['hospital'] ?? "N/A"}'),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        );
                      } else if (value == 'status') {
                        showModalBottomSheet(
                          context: context,
                          builder: (context) => Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('Update Status', style: TextStyle(fontSize: 18)),
                              ),
                              ListTile(
                                title: const Text('Pending'),
                                onTap: () => _updateStatus(doc.reference, 'pending', context),
                              ),
                              ListTile(
                                title: const Text('Confirmed'),
                                onTap: () => _updateStatus(doc.reference, 'confirmed', context),
                              ),
                              ListTile(
                                title: const Text('Cancelled'),
                                onTap: () => _updateStatus(doc.reference, 'cancelled', context),
                              ),
                            ],
                          ),
                        );
                      } else if (value == 'delete') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Delete Appointment'),
                            content: const Text('Are you sure you want to delete this appointment?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                            ],
                          ),
                        );
                        if (confirm == true) await doc.reference.delete();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'view', child: Text('View')),
                      PopupMenuItem(value: 'status', child: Text('Change Status')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
