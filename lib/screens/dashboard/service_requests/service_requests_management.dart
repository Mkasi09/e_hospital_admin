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

  Future<void> _showAddServiceDialog() async {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Add New Service"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Service Name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Price (R)'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = _nameController.text.trim();
                  final price =
                      double.tryParse(_priceController.text.trim()) ?? 0;
                  if (name.isNotEmpty && price > 0) {
                    await FirebaseFirestore.instance.collection('services').add(
                      {
                        'name': name,
                        'price': price,
                        'createdAt': Timestamp.now(),
                      },
                    );
                    Navigator.pop(context);
                    _nameController.clear();
                    _priceController.clear();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Service added successfully."),
                      ),
                    );
                  }
                },
                child: const Text("Add Service"),
              ),
            ],
          ),
    );
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
          return Center(child: Text("No $status service requests."));
        }

        return ListView.builder(
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
                  margin: const EdgeInsets.all(12),
                  child: ListTile(
                    title: Text("Service: ${names['serviceName']}"),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Patient: ${names['patientName']}"),
                        Text("Doctor: ${names['doctorName']}"),
                        Text("Price: R${data['price']}"),
                        if (data['timestamp'] != null)
                          Text(
                            "Requested on: ${DateFormat.yMd().add_jm().format(DateTime.fromMillisecondsSinceEpoch(data['timestamp']))}",
                          ),
                        if (status == 'approved' &&
                            data['scheduledDate'] != null)
                          Text(
                            "Scheduled for: ${DateFormat.yMd().format(DateTime.parse(data['scheduledDate']))}",
                          ),
                      ],
                    ),
                    trailing:
                        status == 'pending'
                            ? ElevatedButton(
                              onPressed: () => _approveRequest(context, doc),
                              child: const Text("Approve & Schedule"),
                            )
                            : const Icon(
                              Icons.check_circle,
                              color: Colors.green,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Service Requests Management"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: "Pending"), Tab(text: "Approved")],
        ),
        actions: [
          TextButton.icon(
            label: const Text('View/Add Services'),
            icon: const Icon(Icons.keyboard_arrow_right),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AvailableServicesScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildRequestList('pending'), _buildRequestList('approved'), ],
      ),
    );
  }
}
