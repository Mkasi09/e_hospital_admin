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
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<Map<String, String>> _getNames(Map<String, dynamic> data) async {
    final patientId = data['patientId'];
    final doctorId = data['doctorId'];
    final serviceId = data['serviceId'];

    final patientSnap =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(patientId)
            .get();
    final doctorSnap =
        await FirebaseFirestore.instance
            .collection('doctors')
            .doc(doctorId)
            .get();
    final serviceSnap =
        await FirebaseFirestore.instance
            .collection('services')
            .doc(serviceId)
            .get();

    return {
      'patientName': patientSnap.data()?['fullName'] ?? patientId,
      'doctorName': doctorSnap.data()?['fullName'] ?? doctorId,
      'serviceName': serviceSnap.data()?['name'] ?? serviceId,
    };
  }

  Future<void> _approveRequest(
    BuildContext context,
    DocumentSnapshot requestDoc,
  ) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (pickedDate != null) {
      await FirebaseFirestore.instance
          .collection('service_requests')
          .doc(requestDoc.id)
          .update({
            'status': 'approved',
            'scheduledDate': pickedDate.toIso8601String(),
          });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Service approved and scheduled.")),
      );
    }
  }

  Widget _buildRequestList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
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

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;

            return FutureBuilder<Map<String, String>>(
              future: _getNames(data),
              builder: (context, snapshot) {
                final names =
                    snapshot.data ??
                    {
                      'patientName': data['patientId'],
                      'doctorName': data['doctorId'],
                      'serviceName': data['serviceId'],
                    };

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Service Name
                        Row(
                          children: [
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                names['serviceName']!,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Patient and Doctor Info
                        _buildInfoRow(
                          Icons.person_outline,
                          "Patient: ${names['patientName']}",
                        ),

                        const SizedBox(height: 6),

                        // Price
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

                        // Scheduled Date (only for approved)
                        if (status == 'approved' &&
                            data['scheduledDate'] != null)
                          _buildInfoRow(
                            Icons.schedule_outlined,
                            "Scheduled: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(data['scheduledDate']))}",
                          ),

                        const SizedBox(height: 12),

                        // Action Button
                        if (status == 'pending')
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _approveRequest(context, doc),
                              icon: const Icon(Icons.check, size: 20),
                              label: const Text("Approve & Schedule"),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          )
                        else
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
                                  "Approved",
                                  style: TextStyle(
                                    color: Colors.green[700],
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
          labelStyle: const TextStyle(fontWeight: FontWeight.w500),
          labelColor: Colors.white, // text color when selected
          unselectedLabelColor: Colors.black, // text color when unselected
          tabs: const [
            Tab(icon: Icon(Icons.pending_actions_outlined), text: "Pending"),
            Tab(icon: Icon(Icons.verified_outlined), text: "Approved"),
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
        children: [_buildRequestList('pending'), _buildRequestList('approved')],
      ),
    );
  }
}
