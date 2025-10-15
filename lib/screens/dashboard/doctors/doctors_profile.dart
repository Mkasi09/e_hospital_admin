import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DoctorProfilePage extends StatelessWidget {
  final String doctorId;

  const DoctorProfilePage({super.key, required this.doctorId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Doctor Profile")),
      body: FutureBuilder<DocumentSnapshot>(
        future:
            FirebaseFirestore.instance.collection("users").doc(doctorId).get(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading profile"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>?;

          if (data == null) {
            return const Center(child: Text("Profile not found"));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage:
                        data["avatar"] != null &&
                                data["avatar"].toString().startsWith("http")
                            ? NetworkImage(data["avatar"])
                            : null,
                    child:
                        data["avatar"] == null
                            ? const Icon(Icons.person, size: 50)
                            : null,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    data["name"] ?? "Unknown Doctor",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    data["specialty"] ?? "General",
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
                const Divider(height: 32),

                profileRow(
                  Icons.badge,
                  "Experience",
                  data["experience"] ?? "N/A",
                ),
                profileRow(
                  Icons.people,
                  "Patients",
                  "${data["patients"] ?? 0}",
                ),
                profileRow(Icons.star, "Rating", "${data["rating"] ?? 0} / 5"),

                const Divider(height: 32),
                profileRow(Icons.email, "Email", data["email"] ?? ""),
                profileRow(Icons.phone, "Phone", data["phone"] ?? ""),
                profileRow(
                  Icons.location_on,
                  "Location",
                  data["location"] ?? "Not specified",
                ),

                const Divider(height: 32),
                Text(
                  "Biography",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  data["bio"] ?? "No biography available.",
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget profileRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text("$label: $value", style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
