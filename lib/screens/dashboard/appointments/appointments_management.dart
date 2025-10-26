import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'new_appointment.dart';

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
  String searchQuery = '';

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<String> doctors = [];
  Map<String, String> doctorIdMap = {}; // Map doctor names to their IDs

  @override
  void initState() {
    super.initState();
    _fetchDoctors();
  }

  Future<void> _fetchDoctors() async {
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'doctor')
        .get();

    setState(() {
      doctors = query.docs
          .map((doc) => doc['name'] as String)
          .toSet()
          .toList();

      // Create mapping for doctor names to IDs
      doctorIdMap = {
        for (var doc in query.docs)
          doc['name'] as String: doc.id
      };
    });
  }

  void _updateStatus(DocumentReference docRef, String newStatus, BuildContext context) async {
    Navigator.pop(context);
    await docRef.update({'status': newStatus});

    // Get appointment data for notification
    final doc = await docRef.get();
    final data = doc.data() as Map<String, dynamic>;

    // Create notification for patient
    await _createNotification(
      data['patientId'],
      'Appointment Status Updated',
      'Your appointment with ${data['doctor']} has been $newStatus',
    );

    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status updated to "$newStatus"'),
          backgroundColor: Colors.green,
        )
    );
  }

  Future<void> _createNotification(String patientId, String title, String message) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': patientId,
        'title': title,
        'message': message,
        'type': 'appointment',
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error creating notification: $e');
    }
  }

  Stream<QuerySnapshot> _getFilteredStream() {
    Query query = FirebaseFirestore.instance.collection('appointments');

    if (selectedDoctor != null && selectedDoctor!.isNotEmpty) {
      final doctorId = doctorIdMap[selectedDoctor];
      if (doctorId != null) {
        query = query.where('doctorId', isEqualTo: doctorId);
      }
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

    return query.orderBy('date').snapshots();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'confirmed':
        return 'Confirmed';
      case 'pending':
        return 'Pending';
      case 'cancelled':
        return 'Cancelled';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }

  Widget _buildAppointmentCard(DocumentSnapshot doc, Map<String, dynamic> data) {
    final patient = data['patientName'] ?? 'Unknown';
    final doctor = data['doctor'] ?? 'Unknown';
    final time = data['time'] ?? '';
    final status = data['status'] ?? 'pending';
    final reason = data['reason'] ?? 'No reason provided';
    final hospital = data['hospital'] ?? 'Not specified';

    final dateTimestamp = data['date'];
    final date = dateTimestamp is Timestamp
        ? dateTimestamp.toDate()
        : DateTime.tryParse(dateTimestamp.toString());

    final dateStr = date != null
        ? DateFormat('MMM dd, yyyy').format(date)
        : 'Invalid date';

    final isUpcoming = date != null && date.isAfter(DateTime.now());
    final isToday = date != null &&
        date.year == DateTime.now().year &&
        date.month == DateTime.now().month &&
        date.day == DateTime.now().day;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 8,
          decoration: BoxDecoration(
            color: _getStatusColor(status),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              patient,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'With Dr. $doctor',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  dateStr,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(width: 12),
                Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  time,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _getStatusColor(status)),
                  ),
                  child: Text(
                    _getStatusText(status),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: _getStatusColor(status),
                    ),
                  ),
                ),
                if (isToday) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue),
                    ),
                    child: const Text(
                      'TODAY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ] else if (isUpcoming) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green),
                    ),
                    child: const Text(
                      'UPCOMING',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) => _handleMenuAction(value, doc, data, context),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'view', child: Text('View Details')),
            const PopupMenuItem(value: 'status', child: Text('Change Status')),
            if (status != 'completed' && status != 'cancelled')
              const PopupMenuItem(value: 'complete', child: Text('Mark Complete')),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }

  void _handleMenuAction(String value, DocumentSnapshot doc, Map<String, dynamic> data, BuildContext context) {
    switch (value) {
      case 'view':
        _showAppointmentDetails(context, data);
        break;
      case 'status':
        _showStatusBottomSheet(doc.reference, context);
        break;
      case 'complete':
        _updateStatus(doc.reference, 'completed', context);
        break;
      case 'delete':
        _showDeleteConfirmation(doc.reference, context);
        break;
    }
  }

  void _showAppointmentDetails(BuildContext context, Map<String, dynamic> data) {
    final patient = data['patientName'] ?? 'Unknown';
    final doctor = data['doctor'] ?? 'Unknown';
    final time = data['time'] ?? '';
    final status = data['status'] ?? 'pending';
    final reason = data['reason'] ?? 'No reason provided';
    final hospital = data['hospital'] ?? 'Not specified';
    final patientId = data['patientId'];
    final doctorId = data['doctorId'];

    final dateTimestamp = data['date'];
    final date = dateTimestamp is Timestamp
        ? dateTimestamp.toDate()
        : DateTime.tryParse(dateTimestamp.toString());

    final dateStr = date != null
        ? DateFormat('MMMM dd, yyyy').format(date)
        : 'Invalid date';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Appointment Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Patient', patient),
              _buildDetailRow('Doctor', 'Dr. $doctor'),
              _buildDetailRow('Date', dateStr),
              _buildDetailRow('Time', time),
              _buildDetailRow('Status', _getStatusText(status)),
              _buildDetailRow('Hospital', hospital),
              _buildDetailRow('Reason', reason),
              if (patientId != null) _buildDetailRow('Patient ID', patientId),
              if (doctorId != null) _buildDetailRow('Doctor ID', doctorId),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _showStatusBottomSheet(DocumentReference docRef, BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Update Appointment Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          _buildStatusOption(context, docRef, 'pending', 'Pending', Colors.orange),
          _buildStatusOption(context, docRef, 'confirmed', 'Confirmed', Colors.green),
          _buildStatusOption(context, docRef, 'completed', 'Completed', Colors.blue),
          _buildStatusOption(context, docRef, 'cancelled', 'Cancelled', Colors.red),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStatusOption(BuildContext context, DocumentReference docRef, String status, String label, Color color) {
    return ListTile(
      leading: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
      title: Text(label),
      onTap: () => _updateStatus(docRef, status, context),
    );
  }

  Future<void> _showDeleteConfirmation(DocumentReference docRef, BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Appointment'),
        content: const Text('Are you sure you want to delete this appointment? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await docRef.delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: _buildFiltersDrawer(),
      appBar: AppBar(
        title: const Text('Appointments Management'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => showAdminCreateAppointment(context),
            tooltip: 'Create Appointment',
          ),
          IconButton(
            icon: const Icon(Icons.filter_alt_outlined),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            tooltip: 'Filters',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by patient name...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getFilteredStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No appointments found',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                final appointments = snapshot.data!.docs;

                // Filter by search query
                final filteredAppointments = appointments.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final patientName = (data['patientName'] ?? '').toString().toLowerCase();
                  return searchQuery.isEmpty || patientName.contains(searchQuery);
                }).toList();

                if (filteredAppointments.isEmpty) {
                  return const Center(
                    child: Text('No appointments match your search'),
                  );
                }

                return ListView.builder(
                  itemCount: filteredAppointments.length,
                  itemBuilder: (context, index) {
                    final doc = filteredAppointments[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildAppointmentCard(doc, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersDrawer() {
    return Drawer(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Filters',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // Doctor Filter
          DropdownButtonFormField<String>(
            value: selectedDoctor,
            decoration: const InputDecoration(
              labelText: 'Doctor',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Doctors')),
              ...doctors.map((docName) {
                return DropdownMenuItem(value: docName, child: Text(docName));
              }).toList(),
            ],
            onChanged: (val) => setState(() => selectedDoctor = val),
          ),

          const SizedBox(height: 16),

          // Status Filter
          DropdownButtonFormField<String>(
            value: selectedStatus,
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: null, child: Text('All Statuses')),
              DropdownMenuItem(value: 'pending', child: Text('Pending')),
              DropdownMenuItem(value: 'confirmed', child: Text('Confirmed')),
              DropdownMenuItem(value: 'completed', child: Text('Completed')),
              DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
            ],
            onChanged: (val) => setState(() => selectedStatus = val),
          ),

          const SizedBox(height: 16),

          // Date Range
          _buildDatePicker('Start Date', startDate, (picked) => setState(() => startDate = picked)),
          _buildDatePicker('End Date', endDate, (picked) => setState(() => endDate = picked)),

          const SizedBox(height: 24),

          // Action Buttons
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Apply Filters'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                selectedDoctor = null;
                selectedStatus = null;
                startDate = null;
                endDate = null;
                searchQuery = '';
              });
              Navigator.pop(context);
            },
            child: const Text('Clear All Filters'),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker(String label, DateTime? date, Function(DateTime?) onDatePicked) {
    return ListTile(
      title: Text(label),
      subtitle: Text(
        date != null ? DateFormat('MMM dd, yyyy').format(date) : 'Select date',
      ),
      trailing: const Icon(Icons.calendar_today),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2023),
          lastDate: DateTime(2026),
        );
        onDatePicked(picked);
      },
    );
  }
}