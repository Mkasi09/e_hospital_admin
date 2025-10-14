import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_doctor.dart';
import 'doctors_profile.dart';

class DoctorsScreen extends StatefulWidget {
  const DoctorsScreen({super.key});

  @override
  State<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends State<DoctorsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  Color getStatusColor(String status) {
    switch (status) {
      case "available":
        return Colors.green;
      case "busy":
        return Colors.orange;
      case "off-duty":
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String getStatusText(String status) {
    switch (status) {
      case "available":
        return "Available";
      case "busy":
        return "Busy";
      case "off-duty":
        return "Off Duty";
      default:
        return "Unknown";
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Doctors Management"),
        actions: [
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => const AddDoctorPage(
                        firebaseApiKey:
                            'AIzaSyAmkucc7_QyTmr6f7oywJdUxhjHXyugKMc',
                      ),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text("Add Doctor"),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search doctors by name, specialty, or email...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon:
                    _searchQuery.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                        : null,
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
              stream:
                  FirebaseFirestore.instance
                      .collection("users")
                      .where("role", isEqualTo: "doctor")
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text("Error loading doctors"));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingState();
                }

                final doctors = snapshot.data!.docs;

                if (doctors.isEmpty) {
                  return const Center(child: Text("No doctors available"));
                }

                // Filter doctors based on search query
                final filteredDoctors =
                    doctors.where((doctor) {
                      final data = doctor.data() as Map<String, dynamic>;
                      final name = data["name"]?.toString().toLowerCase() ?? '';
                      final specialty =
                          data["specialty"]?.toString().toLowerCase() ?? '';
                      final email =
                          data["email"]?.toString().toLowerCase() ?? '';

                      return name.contains(_searchQuery) ||
                          specialty.contains(_searchQuery) ||
                          email.contains(_searchQuery);
                    }).toList();

                if (filteredDoctors.isEmpty) {
                  return _buildNoResults();
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      // Search results count
                      if (_searchQuery.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            "Found ${filteredDoctors.length} doctor${filteredDoctors.length == 1 ? '' : 's'}",
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredDoctors.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3, // 🔹 3 per row on web
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 2,
                            ),
                        itemBuilder: (context, index) {
                          final doctor =
                              filteredDoctors[index].data()
                                  as Map<String, dynamic>;

                          return Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  /// Header Row
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 24,
                                            backgroundColor:
                                                Theme.of(context).primaryColor,
                                            child: Text(
                                              doctor["avatar"] ?? "Dr",
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                doctor["name"] ?? "",
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              Text(
                                                doctor["specialty"] ??
                                                    "General",
                                                style: const TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      Chip(
                                        label: Text(
                                          getStatusText(doctor["status"] ?? ""),
                                        ),
                                        backgroundColor: getStatusColor(
                                          doctor["status"] ?? "",
                                        ).withOpacity(0.1),
                                        labelStyle: TextStyle(
                                          color: getStatusColor(
                                            doctor["status"] ?? "",
                                          ),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 16),

                                  infoRow(
                                    "Experience",
                                    doctor["experience"] ?? "N/A",
                                  ),
                                  infoRow(
                                    "Patients",
                                    "${doctor["patients"] ?? 0}",
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        "Rating",
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.star,
                                            color: Colors.orange,
                                            size: 16,
                                          ),
                                          Text(
                                            "${doctor["rating"] ?? 0}",
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),

                                  const Divider(height: 24),

                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.email,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          doctor["email"] ?? "",
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.phone,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        doctor["phone"] ?? "",
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const Spacer(),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder:
                                                    (_) => DoctorProfilePage(
                                                      doctorId:
                                                          filteredDoctors[index]
                                                              .id,
                                                    ),
                                              ),
                                            );
                                          },
                                          child: const Text("View Profile"),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () {},
                                          child: const Text("Schedule"),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            "Loading doctors...",
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            "No doctors found",
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Try searching with different terms",
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  /// Helper - info row
  Widget infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
