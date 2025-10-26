import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:async';

class ProfileScreen extends StatefulWidget {
  final String patientId;
  final bool isAdminView;

  const ProfileScreen({
    super.key,
    required this.patientId,
    this.isAdminView = false,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Personal info
  String fullName = '';
  String email = '';
  String? profilePicture;
  String role = '';
  String phone = '';
  String nextOfKin = '';
  String nextOfKinPhone = '';
  String address = '';
  String id = "";
  String dob = '';
  String gender = '';

  // Medical info
  String bloodGroup = '';
  String allergies = '';
  String chronicConditions = '';
  String medications = '';
  String primaryDoctor = '';

  String specialty = '';
  String hospital = '';
  String licenseNumber = '';
  bool _isLoading = true;

  // Account status fields
  String accountStatus = 'active';
  DateTime? suspensionEndDate;
  String suspensionReason = '';

  // Get patient files collection reference
  CollectionReference get patientFilesCollection =>
      FirebaseFirestore.instance.collection('patient_files');

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _setupAutomaticStatusChecks();
  }

  void _setupAutomaticStatusChecks() {
    Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        checkAndReactivateSuspendedAccounts();
        _loadUserData();
      }
    });
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.patientId)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      final addressData = data['address'] as Map<String, dynamic>?;
      final medicalData = data['medicalInfo'] as Map<String, dynamic>? ?? {};
      final statusData = data['accountStatus'] as Map<String, dynamic>? ?? {};

      setState(() {
        fullName = data['fullName'] ?? data['name'] ?? '';
        email = data['email'] ?? '';
        profilePicture = data['profilePicture'];
        role = data['role'] ?? '';
        phone = data['phone'] ?? '';
        id = data['id'] ?? '';
        gender = data['gender'] ?? '';
        dob = _parseDobFromId(id);

        nextOfKin = data['nextOfKin'] ?? '';
        nextOfKinPhone = data['nextOfKinPhone'] ?? '';

        address = addressData != null
            ? '${addressData['street'] ?? ''}, ${addressData['city'] ?? ''}, ${addressData['province'] ?? ''}, ${addressData['postalCode'] ?? ''}, ${addressData['country'] ?? ''}'
            : '';

        bloodGroup = medicalData['bloodGroup'] ?? '';
        allergies = medicalData['allergies'] ?? '';
        chronicConditions = medicalData['chronicConditions'] ?? '';
        medications = medicalData['medications'] ?? '';
        primaryDoctor = medicalData['primaryDoctor'] ?? '';

        specialty = data['specialty'] ?? '';
        hospital = data['hospitalName'] ?? '';
        licenseNumber = data['licenseNumber'] ?? '';

        // Load account status
        accountStatus = statusData['status'] ?? 'active';
        suspensionReason = statusData['suspensionReason'] ?? '';
        if (statusData['suspensionEndDate'] != null) {
          suspensionEndDate = (statusData['suspensionEndDate'] as Timestamp).toDate();
        }

        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    if (!widget.isAdminView) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    final file = File(pickedFile.path);
    final cloudinaryUploadUrl = Uri.parse(
      'https://api.cloudinary.com/v1_1/dzz3iovq5/raw/upload',
    );

    final request = http.MultipartRequest('POST', cloudinaryUploadUrl)
      ..fields['upload_preset'] = 'ehospital'
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final response = await request.send();

    if (response.statusCode == 200) {
      final resStr = await response.stream.bytesToString();
      final data = json.decode(resStr);
      final secureUrl = data['secure_url'];

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.patientId)
          .update({'profilePicture': secureUrl});

      setState(() {
        profilePicture = secureUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Profile picture updated"),
          backgroundColor: const Color(0xFF00796B),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to upload image"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _parseDobFromId(String idNumber) {
    if (idNumber.length < 6) return '';

    try {
      final year = int.parse(idNumber.substring(0, 2));
      final month = int.parse(idNumber.substring(2, 4));
      final day = int.parse(idNumber.substring(4, 6));

      final currentYear = DateTime.now().year;
      final century = (year > currentYear % 100) ? 1900 : 2000;
      final fullYear = century + year;

      final date = DateTime(fullYear, month, day);
      return DateFormat('dd-MM-yyyy').format(date);
    } catch (e) {
      return '';
    }
  }

  void _showEditProfileDialog() {
    final phoneController = TextEditingController(text: phone);
    final nextOfKinController = TextEditingController(text: nextOfKin);
    final nextOfKinPhoneController = TextEditingController(
      text: nextOfKinPhone,
    );

    // Parse address parts or use empty strings
    final parts = address.split(',').map((e) => e.trim()).toList();
    final streetController = TextEditingController(
      text: parts.isNotEmpty ? parts[0] : '',
    );
    final cityController = TextEditingController(
      text: parts.length > 1 ? parts[1] : '',
    );
    final provinceController = TextEditingController(
      text: parts.length > 2 ? parts[2] : '',
    );
    final postalCodeController = TextEditingController(
      text: parts.length > 3 ? parts[3] : '',
    );
    final countryController = TextEditingController(
      text: parts.length > 4 ? parts[4] : '',
    );

    // Medical info controllers
    final bloodGroupController = TextEditingController(text: bloodGroup);
    final allergiesController = TextEditingController(text: allergies);
    final chronicConditionsController = TextEditingController(
      text: chronicConditions,
    );
    final medicationsController = TextEditingController(text: medications);
    final primaryDoctorController = TextEditingController(text: primaryDoctor);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Edit Personal & Medical Info',
          style: TextStyle(color: Color(0xFF00796B)),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Personal Details',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00796B),
                ),
              ),
              const SizedBox(height: 8),
              _buildTextField(
                phoneController,
                'Phone Number',
                TextInputType.phone,
              ),
              _buildTextField(nextOfKinController, 'Next of Kin'),
              _buildTextField(
                nextOfKinPhoneController,
                'Next of Kin Phone',
                TextInputType.phone,
              ),
              const SizedBox(height: 12),
              _buildTextField(streetController, 'Street'),
              _buildTextField(cityController, 'City'),
              _buildTextField(provinceController, 'Province'),
              _buildTextField(
                postalCodeController,
                'Postal Code',
                TextInputType.number,
              ),
              _buildTextField(countryController, 'Country'),
              const Divider(height: 32),
              const Text(
                'Medical Information',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00796B),
                ),
              ),
              const SizedBox(height: 8),
              _buildTextField(bloodGroupController, 'Blood Group'),
              _buildTextField(
                allergiesController,
                'Allergies',
                TextInputType.multiline,
              ),
              _buildTextField(
                chronicConditionsController,
                'Chronic Conditions',
                TextInputType.multiline,
              ),
              _buildTextField(
                medicationsController,
                'Medications',
                TextInputType.multiline,
              ),
              _buildTextField(primaryDoctorController, 'Primary Doctor'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF00796B)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00796B),
            ),
            onPressed: () async {
              final addressData = {
                'street': streetController.text.trim(),
                'city': cityController.text.trim(),
                'province': provinceController.text.trim(),
                'postalCode': postalCodeController.text.trim(),
                'country': countryController.text.trim(),
              };
              final medicalData = {
                'bloodGroup': bloodGroupController.text.trim(),
                'allergies': allergiesController.text.trim(),
                'chronicConditions': chronicConditionsController.text.trim(),
                'medications': medicationsController.text.trim(),
                'primaryDoctor': primaryDoctorController.text.trim(),
              };

              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.patientId)
                  .update({
                'phone': phoneController.text.trim(),
                'nextOfKin': nextOfKinController.text.trim(),
                'nextOfKinPhone': nextOfKinPhoneController.text.trim(),
                'address': addressData,
                'medicalInfo': medicalData,
              });

              Navigator.pop(context);
              _loadUserData();
            },
            child: const Text(
              'Save',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // Account Management Methods
  void _showAccountManagementDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text(
              'Manage Account',
              style: TextStyle(color: Color(0xFF00796B)),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manage account for: $fullName',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                _infoRow('Current Status', _getStatusText()),
                if (suspensionEndDate != null)
                  _infoRow('Suspension Ends', DateFormat('yyyy-MM-dd – HH:mm').format(suspensionEndDate!)),
                if (suspensionReason.isNotEmpty)
                  _infoRow('Suspension Reason', suspensionReason),

                if (accountStatus == 'banned')
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'This account is permanently banned.',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              if (widget.isAdminView)
                TextButton(
                  onPressed: _showDeleteAccountDialog,
                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              if (accountStatus == 'active') ...[
                TextButton(
                  onPressed: () => _showSuspendAccountDialog(),
                  child: const Text('Suspend', style: TextStyle(color: Colors.orange)),
                ),
                TextButton(
                  onPressed: () => _showBanAccountDialog(),
                  child: const Text('Ban', style: TextStyle(color: Colors.red)),
                ),
              ] else if (accountStatus == 'suspended') ...[
                TextButton(
                  onPressed: _reactivateAccount,
                  child: const Text('Reactivate', style: TextStyle(color: Colors.green)),
                ),
                TextButton(
                  onPressed: () => _showBanAccountDialog(),
                  child: const Text('Ban', style: TextStyle(color: Colors.red)),
                ),
              ] else if (accountStatus == 'banned') ...[
                TextButton(
                  onPressed: _reactivateAccount,
                  child: const Text('Reactivate', style: TextStyle(color: Colors.green)),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  void _showSuspendAccountDialog() {
    final durationController = TextEditingController();
    final reasonController = TextEditingController();
    DateTime? selectedDate;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Suspend Account', style: TextStyle(color: Colors.orange)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Suspend account for: $fullName'),
            const SizedBox(height: 16),
            _buildTextField(reasonController, 'Suspension Reason', TextInputType.multiline, 2),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 7)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  selectedDate = picked;
                  durationController.text = DateFormat('yyyy-MM-dd').format(picked);
                }
              },
              child: AbsorbPointer(
                child: _buildTextField(durationController, 'Suspension End Date'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              if (reasonController.text.isEmpty || selectedDate == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide reason and end date')),
                );
                return;
              }
              _suspendAccount(selectedDate!, reasonController.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Suspend', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showBanAccountDialog() {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ban Account', style: TextStyle(color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Permanently ban account for: $fullName'),
            const SizedBox(height: 16),
            _buildTextField(reasonController, 'Ban Reason', TextInputType.multiline, 2),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (reasonController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide a reason')),
                );
                return;
              }
              _banAccount(reasonController.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Ban Account', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
        content: Text('Are you sure you want to permanently delete the account for $fullName? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: _deleteAccount,
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> checkAndReactivateSuspendedAccounts() async {
    final now = Timestamp.now();
    final suspendedUsers = await FirebaseFirestore.instance
        .collection('users')
        .where('accountStatus.status', isEqualTo: 'suspended')
        .get();

    for (final doc in suspendedUsers.docs) {
      final accountStatus = doc.data()['accountStatus'] as Map<String, dynamic>;
      final suspensionEndDate = accountStatus['suspensionEndDate'] as Timestamp?;

      if (suspensionEndDate != null && suspensionEndDate.compareTo(now) < 0) {
        // Suspension period has ended, reactivate account
        await FirebaseFirestore.instance
            .collection('users')
            .doc(doc.id)
            .update({
          'accountStatus': {
            'status': 'active',
            'reactivatedAt': Timestamp.now(),
            'previousSuspensionEnd': suspensionEndDate,
          }
        });
      }
    }
  }

  Future<void> _suspendAccount(DateTime endDate, String reason) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.patientId)
          .update({
        'accountStatus': {
          'status': 'suspended',
          'suspensionEndDate': Timestamp.fromDate(endDate),
          'suspensionReason': reason,
          'suspendedAt': Timestamp.now(),
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Account suspended until ${DateFormat('yyyy-MM-dd').format(endDate)}'),
          backgroundColor: Colors.orange,
        ),
      );

      _loadUserData();
      Navigator.pop(context); // Close management dialog
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to suspend account')),
      );
    }
  }

  Future<void> _banAccount(String reason) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.patientId)
          .update({
        'accountStatus': {
          'status': 'banned',
          'banReason': reason,
          'bannedAt': Timestamp.now(),
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account banned permanently'), backgroundColor: Colors.red),
      );

      _loadUserData();
      Navigator.pop(context); // Close management dialog
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to ban account')),
      );
    }
  }

  Future<void> _reactivateAccount() async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.patientId)
          .update({
        'accountStatus': {
          'status': 'active',
          'reactivatedAt': Timestamp.now(),
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account reactivated'), backgroundColor: Colors.green),
      );

      _loadUserData();
      Navigator.pop(context); // Close management dialog
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to reactivate account')),
      );
    }
  }

  Future<void> _deleteAccount() async {
    try {
      // First, try to delete the user from Firebase Auth if you have access to their email
      // Note: This might require Admin SDK on backend for security

      // Delete from Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.patientId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account deleted successfully'), backgroundColor: Colors.green),
      );

      Navigator.pop(context); // Close dialog
      Navigator.pop(context); // Go back to previous screen
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete account')),
      );
    }
  }

  Future<void> _deletePatientFile(String docId) async {
    try {
      await patientFilesCollection.doc(docId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete document')),
      );
    }
  }

  String _getStatusText() {
    switch (accountStatus) {
      case 'suspended':
        return 'Suspended';
      case 'banned':
        return 'Banned';
      default:
        return 'Active';
    }
  }

  Color _getStatusColor() {
    switch (accountStatus) {
      case 'suspended':
        return Colors.orange;
      case 'banned':
        return Colors.red;
      default:
        return Colors.green;
    }
  }

  Widget _buildTextField(
      TextEditingController controller,
      String label, [
        TextInputType keyboardType = TextInputType.text,
        int maxLines = 1,
      ]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF00796B)),
          border: const OutlineInputBorder(),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF00796B), width: 2),
          ),
          isDense: true,
        ),
      ),
    );
  }

  Widget buildVerifiedFileCard({required String title, required String date}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: const Icon(Icons.verified, color: Colors.green),
        title: Text(title),
        subtitle: Text('Uploaded on: $date'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    final isDoctor = role == 'doctor';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(20),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9, maxWidth: MediaQuery.of(context).size.height * 0.9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: _isLoading ? _buildLoadingState() : _buildContent(isDoctor),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF00796B)),
            SizedBox(height: 20),
            Text(
              'Loading Profile...',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF00796B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isDoctor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Color(0xFF00796B),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isAdminView ? 'Patient Profile (Admin)' : 'Patient Profile',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      fullName,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: Colors.white, size: 24),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Column(
              children: [
                // Account Status Banner
                if (accountStatus != 'active' && widget.isAdminView)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    margin: EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: _getStatusColor().withOpacity(0.1),
                      border: Border.all(color: _getStatusColor()),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: _getStatusColor()),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Account ${_getStatusText().toUpperCase()}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _getStatusColor(),
                                  fontSize: 14,
                                ),
                              ),
                              if (suspensionEndDate != null)
                                Padding(
                                  padding: EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Until: ${DateFormat('yyyy-MM-dd – HH:mm').format(suspensionEndDate!)}',
                                    style: TextStyle(
                                      color: _getStatusColor(),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              if (suspensionReason.isNotEmpty)
                                Padding(
                                  padding: EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Reason: $suspensionReason',
                                    style: TextStyle(
                                      color: _getStatusColor(),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Profile Header
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Color(0xFF00796B).withOpacity(0.1),
                        backgroundImage: profilePicture != null && profilePicture!.isNotEmpty
                            ? NetworkImage(profilePicture!)
                            : null,
                        child: (profilePicture == null || profilePicture!.isEmpty)
                            ? Text(
                          fullName.isNotEmpty ? fullName[0].toUpperCase() : '',
                          style: TextStyle(
                            fontSize: 32,
                            color: Color(0xFF00796B),
                            fontWeight: FontWeight.bold,
                          ),
                        )
                            : null,
                      ),
                      if (!widget.isAdminView)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickAndUploadImage,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Color(0xFF00796B),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              padding: EdgeInsets.all(6),
                              child: Icon(
                                Icons.camera_alt,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                SizedBox(height: 16),
                Center(
                  child: Text(
                    fullName,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF00796B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 4),
                Center(
                  child: Text(
                    email,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    if (widget.isAdminView)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _showAccountManagementDialog,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Color(0xFF00796B),
                            side: BorderSide(color: Color(0xFF00796B)),
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: Icon(Icons.admin_panel_settings, size: 18),
                          label: Text('Manage Account'),
                        ),
                      )
                    else
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _showEditProfileDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF00796B),
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: Icon(Icons.edit, size: 18, color: Colors.white),
                          label: Text('Edit Profile', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                  ],
                ),

                SizedBox(height: 24),

                // Personal Details
                _buildSection(
                  title: 'Personal Details',
                  children: [
                    _infoRow('ID Number', id),
                    _infoRow('Gender', gender),
                    _infoRow('Date of Birth', dob),
                    _infoRow('Phone Number', phone),
                    if (!isDoctor) ...[
                      _infoRow(
                        'Next of Kin',
                        nextOfKin.isNotEmpty
                            ? (nextOfKinPhone.isNotEmpty
                            ? '$nextOfKin ($nextOfKinPhone)'
                            : nextOfKin)
                            : '',
                      ),
                      _infoRow('Address', address),
                    ],
                  ],
                ),

                SizedBox(height: 20),

                // Professional/Medical Info
                _buildSection(
                  title: isDoctor ? 'Professional Information' : 'Medical Information',
                  children: [
                    if (isDoctor) ...[
                      _infoRow('Specialty', specialty),
                      _infoRow('Hospital', hospital),
                      _infoRow('License No.', licenseNumber),
                    ] else ...[
                      _infoRow('Blood Group', bloodGroup),
                      _infoRow('Allergies', allergies),
                      _infoRow('Chronic Conditions', chronicConditions),
                      _infoRow('Medications', medications),
                      _infoRow('Primary Doctor', primaryDoctor),
                    ],
                  ],
                ),

                SizedBox(height: 20),

                // Files Section
                _buildFilesSection(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF00796B),
            ),
          ),
          SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildFilesSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Documents & Files',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF00796B),
            ),
          ),
          SizedBox(height: 16),

          // Official Hospital Files
          _buildFileSubsection(
            title: 'Official Hospital Files',
            stream: FirebaseFirestore.instance
                .collection('doctor_uploaded_files')
                .where('userId', isEqualTo: widget.patientId)
                .orderBy('date', descending: true)
                .snapshots(),
            emptyMessage: 'No official files available.',
          ),

          SizedBox(height: 20),

          // My Uploaded Documents
          _buildFileSubsection(
            title: 'Patient Uploaded Documents',
            stream: patientFilesCollection
                .where('userId', isEqualTo: widget.patientId)
                .orderBy('date', descending: true)
                .snapshots(),
            emptyMessage: 'No documents uploaded yet.',
            isPatientFiles: true,
          ),

          SizedBox(height: 20),

          // Prescriptions
          _buildFileSubsection(
            title: 'Prescriptions',
            stream: FirebaseFirestore.instance
                .collection('prescriptions')
                .where('userId', isEqualTo: widget.patientId)
                .orderBy('date', descending: true)
                .snapshots(),
            emptyMessage: 'No prescriptions available.',
          ),
        ],
      ),
    );
  }

  Widget _buildFileSubsection({
    required String title,
    required Stream<QuerySnapshot> stream,
    required String emptyMessage,
    bool isPatientFiles = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('Error loading files.', style: TextStyle(color: Colors.red));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            if (snapshot.data!.docs.isEmpty) {
              return Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    Icon(Icons.folder_open, size: 40, color: Colors.grey.shade400),
                    SizedBox(height: 8),
                    Text(
                      emptyMessage,
                      style: TextStyle(color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: snapshot.data!.docs.map((doc) {
                final data = doc.data()! as Map<String, dynamic>;
                if (isPatientFiles) {
                  return PatientFileCard(
                    docId: doc.id,
                    title: data['title'] ?? 'Untitled',
                    date: (data['date'] as Timestamp).toDate(),
                    status: data['status'] ?? 'pending',
                    downloadUrl: data['downloadUrl'] ?? '',
                    onDelete: () => _deletePatientFile(doc.id),
                    content: null,
                  );
                } else {
                  return buildVerifiedFileCard(
                    title: data['title'] ?? 'Untitled',
                    date: (data['date'] as Timestamp?)?.toDate() != null
                        ? DateFormat('yyyy-MM-dd').format((data['date'] as Timestamp).toDate())
                        : '',
                  );
                }
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              "$label:",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : "Not provided",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRowDialog(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              "$label:",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : "Not provided",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// PatientFileCard widget (updated for better popup styling)
class PatientFileCard extends StatelessWidget {
  final String docId;
  final String title;
  final DateTime date;
  final String status;
  final String downloadUrl;
  final Function() onDelete;
  final String? content;

  const PatientFileCard({
    super.key,
    required this.docId,
    required this.title,
    required this.date,
    required this.status,
    required this.downloadUrl,
    required this.onDelete,
    this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(
          _getStatusIcon(),
          color: _getStatusColor(),
          size: 20,
        ),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        subtitle: Text(
          'Uploaded: ${DateFormat('yyyy-MM-dd').format(date)}',
          style: TextStyle(fontSize: 12),
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete, color: Colors.red, size: 18),
          onPressed: onDelete,
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  IconData _getStatusIcon() {
    switch (status) {
      case 'verified':
        return Icons.verified;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.pending;
    }
  }

  Color _getStatusColor() {
    switch (status) {
      case 'verified':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }
}