import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ServiceRequestsScreen extends StatefulWidget {
  const ServiceRequestsScreen({super.key});

  @override
  State<ServiceRequestsScreen> createState() => _ServiceRequestsScreenState();
}

class _ServiceRequestsScreenState extends State<ServiceRequestsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  Future<void> _approveRequest(BuildContext context, DocumentSnapshot requestDoc) async {
    final data = requestDoc.data() as Map<String, dynamic>;

    DateTime? pickedDate = await showDatePicker(
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
      builder: (context) => AlertDialog(
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
              final price = double.tryParse(_priceController.text.trim()) ?? 0;
              if (name.isNotEmpty && price > 0) {
                await FirebaseFirestore.instance.collection('services').add({
                  'name': name,
                  'price': price,
                  'createdAt': Timestamp.now(),
                });
                Navigator.pop(context);
                _nameController.clear();
                _priceController.clear();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Service added successfully.")),
                );
              }
            },
            child: const Text("Add Service"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Service Requests Management"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: "Add Service",
            onPressed: _showAddServiceDialog,
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('service_requests')
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(child: Text("No pending service requests."));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.all(12),
                child: ListTile(
                  title: Text("Service ID: ${data['serviceId']}"),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Patient ID: ${data['patientId']}"),
                      Text("Requested by Doctor: ${data['doctorId']}"),
                      if (data['timestamp'] != null)
                        Text("Requested on: ${DateFormat.yMd().add_jm().format(DateTime.fromMillisecondsSinceEpoch(data['timestamp']))}"),
                    ],
                  ),
                  trailing: ElevatedButton(
                    onPressed: () => _approveRequest(context, doc),
                    child: const Text("Approve & Schedule"),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
