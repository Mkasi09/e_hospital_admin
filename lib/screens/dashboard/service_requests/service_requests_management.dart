import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e_hospotal_admin/screens/dashboard/service_requests/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ServiceRequestsScreen extends StatefulWidget {
  const ServiceRequestsScreen({super.key});

  @override
  State<ServiceRequestsScreen> createState() => _ServiceRequestsScreenState();
}

class _ServiceRequestsScreenState extends State<ServiceRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _getRequestDetails(Map<String, dynamic> data) async {
    final patientId = data['patientId'];
    final serviceId = data['serviceId'];

    Map<String, dynamic> details = {
      'patientName': data['patientName'] ?? 'Loading...',
      'serviceName': data['serviceName'] ?? 'Loading...',
      'patientEmail': '',
      'serviceDescription': '',
    };

    try {
      // Get patient details from users collection
      if (patientId != null) {
        final patientSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(patientId)
            .get();
        if (patientSnap.exists) {
          final patientData = patientSnap.data()!;
          details['patientName'] = patientData['name'] ??
              patientData['fullName'] ??
              'Unknown Patient';
          details['patientEmail'] = patientData['email'] ?? '';
        }
      }

      // Get service details from services collection
      if (serviceId != null) {
        final serviceSnap = await FirebaseFirestore.instance
            .collection('service')
            .doc(serviceId)
            .get();
        if (serviceSnap.exists) {
          final serviceData = serviceSnap.data()!;
          details['serviceName'] = serviceData['name'] ?? 'Unknown Service';
          details['serviceDescription'] = serviceData['description'] ?? '';
        }
      }
    } catch (e) {
      print('Error fetching request details: $e');
    }

    return details;
  }

  Future<void> _createBillForService(
      String patientId,
      String patientName,
      String serviceName,
      double price,
      String serviceRequestId,
      DateTime scheduledDate,
      ) async {
    try {
      // Create bill in bills collection
      await FirebaseFirestore.instance.collection('bills').add({
        'patientId': patientId,
        'patientName': patientName,
        'serviceName': serviceName,
        'serviceRequestId': serviceRequestId,
        'amount': price,
        'originalAmount': price,
        'status': 'pending', // pending, paid, overdue, cancelled
        'dueDate': scheduledDate.toIso8601String(), // Due on scheduled date
        'billDate': FieldValue.serverTimestamp(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'type': 'service', // service, consultation, medication, etc.
        'description': 'Service: $serviceName',
        'items': [
          {
            'description': serviceName,
            'amount': price,
            'quantity': 1,
          }
        ],
      });

      print('Bill created successfully for patient $patientName');
    } catch (e) {
      print('Error creating bill: $e');
      throw e;
    }
  }

  Future<void> _approveRequest(
      BuildContext context,
      DocumentSnapshot requestDoc,
      Map<String, dynamic> requestData,
      ) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: 9, minute: 0),
      );

      if (pickedTime != null) {
        final scheduledDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        try {
          // Update service request status first
          await FirebaseFirestore.instance
              .collection('service_requests')
              .doc(requestDoc.id)
              .update({
            'status': 'approved',
            'scheduledDate': scheduledDateTime.toIso8601String(),
            'approvedAt': FieldValue.serverTimestamp(),
          });

          // Create bill for the service
          await _createBillForService(
            requestData['patientId'],
            requestData['patientName'] ?? 'Unknown Patient',
            requestData['serviceName'],
            (requestData['price'] as num).toDouble(),
            requestDoc.id,
            scheduledDateTime,
          );

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Service approved and bill created. Due date: ${DateFormat('MMM dd, yyyy').format(scheduledDateTime)}"),
              backgroundColor: Colors.green,
            ),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Failed to approve request: $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _rejectRequest(
      BuildContext context,
      DocumentSnapshot requestDoc,
      Map<String, dynamic> requestData,
      ) async {
    final TextEditingController reasonController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Service Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide a reason')),
                );
                return;
              }

              try {
                await FirebaseFirestore.instance
                    .collection('service_requests')
                    .doc(requestDoc.id)
                    .update({
                  'status': 'rejected',
                  'rejectionReason': reasonController.text.trim(),
                  'rejectedAt': FieldValue.serverTimestamp(),
                });

                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Service request rejected"),
                    backgroundColor: Colors.orange,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Failed to reject request: $e"),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRequestDetails(BuildContext context, Map<String, dynamic> data, Map<String, dynamic> details) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailItem('Service', details['serviceName']),
              _buildDetailItem('Patient', details['patientName']),
              if (details['patientEmail'].isNotEmpty)
                _buildDetailItem('Patient Email', details['patientEmail']),
              _buildDetailItem('Price', 'R${data['price']?.toStringAsFixed(2) ?? '0.00'}'),
              if (data['additionalNotes']?.isNotEmpty == true)
                _buildDetailItem('Additional Notes', data['additionalNotes']),
              if (data['timestamp'] != null)
                _buildDetailItem(
                  'Requested',
                  DateFormat('MMM dd, yyyy - hh:mm a')
                      .format(DateTime.fromMillisecondsSinceEpoch(data['timestamp'])),
                ),
              if (data['scheduledDate'] != null)
                _buildDetailItem(
                  'Scheduled',
                  DateFormat('MMM dd, yyyy - hh:mm a')
                      .format(DateTime.parse(data['scheduledDate'])),
                ),
              if (data['rejectionReason'] != null)
                _buildDetailItem('Rejection Reason', data['rejectionReason']),
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

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildRequestList(String status) {
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search by patient or service...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('service_requests')
                .where('status', isEqualTo: status)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        "No $status service requests",
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              // Filter results based on search query
              final filteredDocs = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final patientName = (data['patientName'] ?? '').toString().toLowerCase();
                final serviceName = (data['serviceName'] ?? '').toString().toLowerCase();

                return _searchQuery.isEmpty ||
                    patientName.contains(_searchQuery) ||
                    serviceName.contains(_searchQuery);
              }).toList();

              if (filteredDocs.isEmpty) {
                return const Center(
                  child: Text('No requests match your search'),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final doc = filteredDocs[index];
                  final data = doc.data() as Map<String, dynamic>;

                  return FutureBuilder<Map<String, dynamic>>(
                    future: _getRequestDetails(data),
                    builder: (context, snapshot) {
                      final details = snapshot.data ?? {
                        'patientName': data['patientName'] ?? 'Loading...',
                        'serviceName': data['serviceName'] ?? 'Loading...',
                        'patientEmail': '',
                        'serviceDescription': '',
                      };

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header with service name and view details
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      details['serviceName']!,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.info_outline, size: 20),
                                    onPressed: () => _showRequestDetails(context, data, details),
                                    tooltip: 'View Details',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Patient and Price Info
                              _buildInfoRow(
                                Icons.person_outline,
                                "Patient: ${details['patientName']}",
                              ),
                              const SizedBox(height: 6),

                              _buildInfoRow(
                                Icons.attach_money_outlined,
                                "Price: R${data['price']?.toStringAsFixed(2) ?? '0.00'}",
                              ),
                              const SizedBox(height: 6),

                              // Request Date
                              if (data['timestamp'] != null)
                                Column(
                                  children: [
                                    _buildInfoRow(
                                      Icons.calendar_today_outlined,
                                      "Requested: ${DateFormat('MMM dd, yyyy - hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(data['timestamp']))}",
                                    ),
                                    const SizedBox(height: 6),
                                  ],
                                ),

                              // Scheduled Date (for approved)
                              if (status == 'approved' && data['scheduledDate'] != null)
                                _buildInfoRow(
                                  Icons.schedule_outlined,
                                  "Scheduled: ${DateFormat('MMM dd, yyyy - hh:mm a').format(DateTime.parse(data['scheduledDate']))}",
                                ),

                              // Additional Notes
                              if (data['additionalNotes']?.isNotEmpty == true)
                                Column(
                                  children: [
                                    const SizedBox(height: 6),
                                    _buildInfoRow(
                                      Icons.note_outlined,
                                      "Notes: ${data['additionalNotes']}",
                                    ),
                                  ],
                                ),

                              const SizedBox(height: 12),

                              // Action Buttons
                              if (status == 'pending')
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => _rejectRequest(context, doc, data),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                          side: const BorderSide(color: Colors.red),
                                        ),
                                        child: const Text("Reject"),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () => _approveRequest(context, doc, data),
                                        icon: const Icon(Icons.check, size: 20),
                                        label: const Text("Approve & Create Bill"),
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              else if (status == 'approved')
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green[50],
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.green[100]!),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.green[600],
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        "Approved - Bill Created",
                                        style: TextStyle(
                                          color: Colors.green[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else if (status == 'rejected')
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red[50],
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.red[100]!),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.cancel,
                                          color: Colors.red[600],
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          "Rejected",
                                          style: TextStyle(
                                            color: Colors.red[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Service Requests Management"),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelStyle: const TextStyle(fontWeight: FontWeight.w500, color: Colors.white),
          tabs: const [
            Tab(icon: Icon(Icons.pending_actions_outlined), text: "Pending"),
            Tab(icon: Icon(Icons.verified_outlined), text: "Approved"),
            Tab(icon: Icon(Icons.cancel_outlined), text: "Rejected"),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AvailableServicesScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.medical_services_outlined),
              label: const Text('Services'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Theme.of(context).primaryColor,
              ),
            ),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRequestList('pending'),
          _buildRequestList('approved'),
          _buildRequestList('rejected'),
        ],
      ),
    );
  }
}