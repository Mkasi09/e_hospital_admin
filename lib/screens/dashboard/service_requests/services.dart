import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AvailableServicesScreen extends StatelessWidget {
  const AvailableServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Available Services"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('services').orderBy('name').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(child: Text("No services found."));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;

              return ListTile(
                title: Text(data['name'] ?? 'Unnamed'),
                subtitle: Text("Price: R${data['price'] ?? 0}"),
              );
            },
          );
        },
      ),
    );
  }
}
