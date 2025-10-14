import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  String searchQuery = '';

  Stream<QuerySnapshot> getPatientsStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'patient')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Patient Management',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search by name or email',
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search),
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
                onChanged: (value) {
                  setState(() {
                    searchQuery = value.toLowerCase();
                  });
                },
              ),
            ),


            const SizedBox(height: 16),
            const _HeaderRow(),
            const SizedBox(height: 8),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: getPatientsStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('Error loading patients'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final patients = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['fullName']?.toLowerCase() ?? '';
                    final email = data['email']?.toLowerCase() ?? '';
                    return name.contains(searchQuery) || email.contains(searchQuery);
                  }).toList();

                  if (patients.isEmpty) {
                    return const Center(child: Text('No patients found.'));
                  }

                  return ListView.builder(
                    itemCount: patients.length,
                    itemBuilder: (context, index) {
                      final doc = patients[index];
                      final data = doc.data() as Map<String, dynamic>;

                      return PatientTile(
                        name: data['fullName'] ?? 'No Name',
                        email: data['email'] ?? 'No Email',
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(flex: 1, child: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
        Expanded(flex: 1, child: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
      ],
    );
  }
}
class PatientTile extends StatelessWidget {
  final String name;
  final String email;

  const PatientTile({
    super.key,
    required this.name,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              email,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}


