import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class AddDoctorPage extends StatefulWidget {
  final String firebaseApiKey;

  const AddDoctorPage({super.key, required this.firebaseApiKey});

  @override
  State<AddDoctorPage> createState() => _AddDoctorPageState();
}

class _AddDoctorPageState extends State<AddDoctorPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _specialtyCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _loading = false;

  List<QueryDocumentSnapshot> _hospitals = [];
  String? _selectedHospitalId;

  @override
  void initState() {
    super.initState();
    _fetchHospitals();
  }

  Future<void> _fetchHospitals() async {
    final snapshot =
    await FirebaseFirestore.instance.collection('hospitals').get();
    setState(() {
      _hospitals = snapshot.docs;
      if (_hospitals.isNotEmpty) {
        _selectedHospitalId = _hospitals.first.id;
      }
    });
  }

  Future<void> _createDoctorUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
    });

    final email = _emailCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final specialty = _specialtyCtrl.text.trim();
    final password = _passwordCtrl.text;

    final url =
        'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${widget.firebaseApiKey}';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
          'returnSecureToken': true,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['localId'] != null) {
        final uid = data['localId'];

        // Get hospital name for reference (optional)
        final hospitalDoc = _hospitals
            .firstWhere((doc) => doc.id == _selectedHospitalId);
        final hospitalName = hospitalDoc['name'] ?? '';

        // Save doctor info in Firestore
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'name': name,
          'email': email,
          'role': 'doctor',
          'specialty': specialty,
          'hospitalId': _selectedHospitalId,
          'hospitalName': hospitalName,
          'requiresPasswordReset': true, // <-- important
          'createdAt': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Doctor user created successfully!')),
        );

        // Clear inputs
        _emailCtrl.clear();
        _nameCtrl.clear();
        _specialtyCtrl.clear();
        _passwordCtrl.clear();
        setState(() {
          _selectedHospitalId =
          _hospitals.isNotEmpty ? _hospitals.first.id : null;
        });
      } else {
        final errMsg = data['error']?['message'] ?? 'Unknown error';
        throw Exception(errMsg);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _specialtyCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin - Add Doctor')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: _hospitals.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Doctor Email',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Enter doctor email';
                      }
                      if (!val.contains('@')) {
                        return 'Enter valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Doctor Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) => val == null || val.isEmpty
                        ? 'Enter doctor name'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _specialtyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Specialty',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) => val == null || val.isEmpty
                        ? 'Enter specialty'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedHospitalId,
                    decoration: const InputDecoration(
                      labelText: 'Hospital',
                      border: OutlineInputBorder(),
                    ),
                    items: _hospitals.map((doc) {
                      return DropdownMenuItem<String>(
                        value: doc.id,
                        child: Text(doc['name'] ?? 'Unnamed Hospital'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedHospitalId = value;
                      });
                    },
                    validator: (value) =>
                    value == null ? 'Please select a hospital' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Temporary Password',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Enter a temporary password';
                      }
                      if (val.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _createDoctorUser,
                      child: _loading
                          ? const CircularProgressIndicator(
                        color: Colors.white,
                      )
                          : const Text('Create Doctor Account'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
