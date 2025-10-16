import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e_hospotal_admin/screens/dashboard/doctors/add_doctor.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DoctorsScreen extends StatefulWidget {
  const DoctorsScreen({super.key});

  @override
  State<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends State<DoctorsScreen> {
  String searchQuery = '';

  Stream<QuerySnapshot> getDoctorsStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'doctor')
        .snapshots();
  }

  void _showDoctorDetails(BuildContext context, DocumentSnapshot doctorDoc) {
    final data = doctorDoc.data() as Map<String, dynamic>;

    showDialog(
      context: context,
      builder: (context) => DoctorDetailsPopup(doctorData: data, doctorId: doctorDoc.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Doctor Management',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // ✅ Rounded Search Bar
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
                stream: getDoctorsStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('Error loading doctors'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final doctors = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['name']?.toLowerCase() ?? '';
                    final email = data['email']?.toLowerCase() ?? '';
                    return name.contains(searchQuery) || email.contains(searchQuery);
                  }).toList();

                  if (doctors.isEmpty) {
                    return const Center(child: Text('No doctors found.'));
                  }

                  return ListView.builder(
                    itemCount: doctors.length,
                    itemBuilder: (context, index) {
                      final doc = doctors[index];
                      final data = doc.data() as Map<String, dynamic>;

                      return GestureDetector(
                        onTap: () => _showDoctorDetails(context, doc),
                        child: DoctorTile(
                          name: data['name'] ?? 'No Name',
                          email: data['email'] ?? 'No Email',
                          specialization: data['specialty'] ?? 'No Specialty',
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddDoctorPage(
                firebaseApiKey: 'AIzaSyAmkucc7_QyTmr6f7oywJdUxhjHXyugKMc',
              ),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Doctor'),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: const [
          Expanded(flex: 2, child: Text('Name', style: _headerStyle)),
          Expanded(flex: 2, child: Text('Email', style: _headerStyle)),
          Expanded(flex: 2, child: Text('Specialization', style: _headerStyle)),
        ],
      ),
    );
  }
}

class DoctorTile extends StatelessWidget {
  final String name;
  final String email;
  final String specialization;

  const DoctorTile({
    super.key,
    required this.name,
    required this.email,
    required this.specialization,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(name)),
          Expanded(flex: 2, child: Text(email)),
          Expanded(flex: 2, child: Text(specialization)),
        ],
      ),
    );
  }
}

class DoctorDetailsPopup extends StatelessWidget {
  final Map<String, dynamic> doctorData;
  final String doctorId;

  const DoctorDetailsPopup({
    super.key,
    required this.doctorData,
    required this.doctorId,
  });

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Not available';

    try {
      if (timestamp is Timestamp) {
        return DateFormat('dd MMMM yyyy \'at\' HH:mm').format(timestamp.toDate());
      } else if (timestamp is String) {
        // Try to parse string timestamp
        final date = DateTime.tryParse(timestamp);
        if (date != null) {
          return DateFormat('dd MMMM yyyy \'at\' HH:mm').format(date);
        }
      }
      return 'Invalid date';
    } catch (e) {
      return 'Date format error';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Doctor Details',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 24),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Profile Picture and Basic Info
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: doctorData['profilePicture'] != null &&
                          doctorData['profilePicture'].toString().isNotEmpty
                          ? NetworkImage(doctorData['profilePicture'].toString())
                          : const AssetImage('assets/default_avatar.png') as ImageProvider,
                      backgroundColor: Colors.grey[200],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      doctorData['name'] ?? 'No Name',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      doctorData['specialty'] ?? 'No Specialty',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // Details Section
              const Text(
                'Professional Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 16),

              _buildDetailRow('Email', doctorData['email'] ?? 'Not provided'),
              _buildDetailRow('Hospital', doctorData['hospitalName'] ?? 'Not provided'),
              _buildDetailRow('Hospital ID', doctorData['hospitalId'] ?? 'Not provided'),
              _buildDetailRow('Specialization', doctorData['specialty'] ?? 'Not provided'),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // Account Information
              const Text(
                'Account Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 16),

              _buildDetailRow('Role', doctorData['role'] ?? 'doctor'),
              _buildDetailRow(
                  'Account Created',
                  _formatTimestamp(doctorData['createdAt'])
              ),
              _buildDetailRow(
                  'Password Reset Required',
                  doctorData['requiresPasswordReset'] == true ? 'Yes' : 'No'
              ),

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: Add edit functionality
                        // Navigator.push(context, MaterialPageRoute(
                        //   builder: (context) => EditDoctorPage(doctorId: doctorId),
                        // ));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Edit Profile', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const TextStyle _headerStyle = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.bold,
  color: Colors.black87,
);