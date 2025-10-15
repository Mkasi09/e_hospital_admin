import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e_hospotal_admin/screens/dashboard/patients/patient_profile.dart';
import 'package:flutter/material.dart';

// ----------------- Patients Screen -----------------
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
            const Text(
              'Patient Management',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Search Box
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
                decoration: const InputDecoration(
                  hintText: 'Search by name or email',
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
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

            // Patient List
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
                    final data = doc.data()! as Map<String, dynamic>;
                    final name = data['fullName']?.toLowerCase() ?? '';
                    final email = data['email']?.toLowerCase() ?? '';
                    return name.contains(searchQuery) ||
                        email.contains(searchQuery);
                  }).toList();

                  if (patients.isEmpty) {
                    return const Center(child: Text('No patients found.'));
                  }

                  return ListView.builder(
                    itemCount: patients.length,
                    itemBuilder: (context, index) {
                      final doc = patients[index];
                      final data = doc.data()! as Map<String, dynamic>;

                      return PatientTile(
                        name: data['fullName'] ?? 'No Name',
                        email: data['email'] ?? 'No Email',
                        patientId: doc.id, // Pass document ID
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

// ----------------- Header Row -----------------
class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          flex: 1,
          child: Text('Name', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        Expanded(
          flex: 1,
          child: Text('Email', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

// ----------------- Patient Tile -----------------
class PatientTile extends StatelessWidget {
  final String name;
  final String email;
  final String patientId;

  const PatientTile({
    super.key,
    required this.name,
    required this.email,
    required this.patientId,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileScreen(patientId: patientId, isAdminView: true,),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
        margin: const EdgeInsets.symmetric(vertical: 6.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Expanded(
              flex: 1,
              child: Text(email, style: const TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------- Patient Profile Screen -----------------
class PatientProfileScreen extends StatelessWidget {
  final String patientId;

  const PatientProfileScreen({super.key, required this.patientId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Patient Profile')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(patientId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading profile'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data()! as Map<String, dynamic>;

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Full Name: ${data['fullName'] ?? 'N/A'}', style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 12),
                Text('Email: ${data['email'] ?? 'N/A'}', style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 12),
                Text('Phone: ${data['phone'] ?? 'N/A'}', style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 12),
                Text('Address: ${data['address'] ?? 'N/A'}', style: const TextStyle(fontSize: 18)),
                // Add more fields here if needed
              ],
            ),
          );
        },
      ),
    );
  }
}
