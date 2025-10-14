import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AvailableServicesScreen extends StatelessWidget {
  const AvailableServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Available Services"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // Navigate to add service screen or show dialog
              _showAddServiceDialog(context);
            },
          ),
        ],
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

  void _showAddServiceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final TextEditingController nameController = TextEditingController();
        final TextEditingController priceController = TextEditingController();

        return AlertDialog(
          title: const Text("Add New Service"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Service Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(
                  labelText: 'Price (R)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final String name = nameController.text.trim();
                final String priceText = priceController.text.trim();

                if (name.isEmpty || priceText.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields')),
                  );
                  return;
                }

                final double? price = double.tryParse(priceText);
                if (price == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid price')),
                  );
                  return;
                }

                try {
                  await FirebaseFirestore.instance.collection('services').add({
                    'name': name,
                    'price': price,
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$name added successfully')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error adding service: $e')),
                  );
                }
              },
              child: const Text('Add Service'),
            ),
          ],
        );
      },
    );
  }
}