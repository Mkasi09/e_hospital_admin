import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminCreateAppointmentPopup extends StatefulWidget {
  const AdminCreateAppointmentPopup({super.key});

  @override
  State<AdminCreateAppointmentPopup> createState() => _AdminCreateAppointmentPopupState();
}

class _AdminCreateAppointmentPopupState extends State<AdminCreateAppointmentPopup> {
  // ---------------- Controllers ----------------
  final TextEditingController _patientIdController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  // ---------------- Patient ----------------
  String? _selectedPatientId;
  String? _selectedPatientName;

  // ---------------- Hospital & Doctor ----------------
  String? _selectedHospital;
  Map<String, dynamic>? _selectedDoctor;
  List<String> _availableHospitals = [];
  List<Map<String, dynamic>> _availableDoctors = [];

  // ---------------- Date & Time ----------------
  DateTime? _selectedDate;
  String? _selectedTime;
  List<String> _availableTimes = [];

  // ---------------- Appointment Type & Fee ----------------
  String _selectedAppointmentType = 'Consultation';
  double _fee = 50.0;
  final Map<String, double> _appointmentFees = {
    "Consultation": 50,
    "Follow-up": 30,
    "Checkup-up": 40,
    "Treatment": 70,
    "Emergency": 100,
  };

  bool _isLoading = false;
  bool _patientFound = false;

  @override
  void initState() {
    super.initState();
    _fetchHospitals();
    _patientIdController.addListener(_onPatientIdChanged);
  }

  @override
  void dispose() {
    _patientIdController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  // ---------------- Patient Search by ID ----------------
  void _onPatientIdChanged() async {
    final id = _patientIdController.text.trim();
    if (id.length != 13) {
      setState(() {
        _selectedPatientId = null;
        _selectedPatientName = null;
        _patientFound = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'patient')
        .where('id', isEqualTo: id)
        .limit(1)
        .get();

    setState(() {
      _isLoading = false;
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        _selectedPatientId = snapshot.docs.first.id;
        _selectedPatientName = data['fullName'] ?? 'Unknown';
        _patientFound = true;
      } else {
        _selectedPatientId = null;
        _selectedPatientName = 'Patient not found';
        _patientFound = false;
      }
    });
  }

  // ---------------- Hospitals & Doctors ----------------
  Future<void> _fetchHospitals() async {
    final snapshot = await FirebaseFirestore.instance.collection('hospitals').get();
    setState(() {
      _availableHospitals = snapshot.docs.map((doc) => doc.data()['name'] as String).toList();
    });
  }

  Future<void> _fetchDoctorsForHospital(String hospitalName) async {
    setState(() {
      _isLoading = true;
    });

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'doctor')
        .where('hospitalName', isEqualTo: hospitalName)
        .get();

    setState(() {
      _availableDoctors = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown',
          'specialty': data['specialty'] ?? 'General',
          'hospital': data['hospitalName'] ?? '',
        };
      }).toList();

      _selectedDoctor = null;
      _selectedTime = null;
      _availableTimes = [];
      _isLoading = false;
    });
  }

  // ---------------- Fetch Available Times ----------------
  Future<void> _fetchAvailableTimes() async {
    if (_selectedDoctor == null || _selectedDate == null) return;

    setState(() {
      _isLoading = true;
      _availableTimes = [];
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('doctorId', isEqualTo: _selectedDoctor!['id'])
          .get();

      final booked = <String>[];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final Timestamp dateTimestamp = data['date'];
        final String timeString = data['time'];
        final date = dateTimestamp.toDate();
        if (DateUtils.isSameDay(date, _selectedDate!)) {
          booked.add(timeString);
        }
      }

      final allSlots = <String>[];
      for (int hour = 8; hour <= 17; hour++) {
        for (int min = 0; min < 60; min += 30) {
          allSlots.add('${hour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}');
        }
      }

      setState(() {
        _availableTimes = allSlots.where((slot) => !booked.contains(slot)).toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching times: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ---------------- Create Appointment ----------------
  Future<void> _createAppointment() async {
    if (_selectedPatientId == null ||
        _selectedHospital == null ||
        _selectedDoctor == null ||
        _selectedDate == null ||
        _selectedTime == null ||
        _reasonController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final parts = _selectedTime!.split(':');
      final appointmentDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );

      // Create appointment
      final appointmentRef = await FirebaseFirestore.instance.collection('appointments').add({
        'hospital': _selectedHospital,
        'doctor': _selectedDoctor!['name'],
        'doctorId': _selectedDoctor!['id'],
        'date': Timestamp.fromDate(appointmentDateTime),
        'time': _selectedTime,
        'reason': _reasonController.text.trim(),
        'status': 'confirmed',
        'userId': _selectedPatientId,
        'patientName': _selectedPatientName,
        'appointmentType': _selectedAppointmentType,
        'fee': _fee,
        'createdByAdmin': true,
        'createdAt': Timestamp.now(),
      });

      // Create bill
      await FirebaseFirestore.instance.collection('bills').add({
        'userId': _selectedPatientId,
        'doctorName': _selectedDoctor!['name'],
        'appointmentId': appointmentRef.id,
        'appointmentType': _selectedAppointmentType,
        'title': '$_selectedAppointmentType Fee - ${_selectedDoctor!['name']}',
        'amount': _fee,
        'status': 'Unpaid',
        'timestamp': Timestamp.now(),
      });

      // Send notifications
      await _sendNotifications(appointmentRef.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create appointment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendNotifications(String appointmentId) async {
    // Notify patient
    await FirebaseFirestore.instance.collection('notifications').add({
      'userId': _selectedPatientId,
      'title': 'New Appointment Scheduled',
      'body': 'An appointment has been scheduled for you with Dr. ${_selectedDoctor!['name']} on ${DateFormat('MMM dd, yyyy').format(_selectedDate!)} at $_selectedTime',
      'type': 'appointment',
      'timestamp': Timestamp.now(),
      'isRead': false,
      'additionalData': {
        'appointmentId': appointmentId,
        'doctorId': _selectedDoctor!['id'],
      },
    });

    // Notify doctor
    await FirebaseFirestore.instance.collection('notifications').add({
      'userId': _selectedDoctor!['id'],
      'title': 'New Appointment Scheduled',
      'body': 'An appointment has been scheduled with $_selectedPatientName on ${DateFormat('MMM dd, yyyy').format(_selectedDate!)} at $_selectedTime',
      'type': 'doctor_appointment',
      'timestamp': Timestamp.now(),
      'isRead': false,
      'additionalData': {
        'appointmentId': appointmentId,
        'patientId': _selectedPatientId,
      },
    });
  }

  // ---------------- Build UI ----------------
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85,
        maxWidth: MediaQuery.of(context).size.height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: Colors.blue, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Create Appointment',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.blue),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Patient ID Section
                    _buildSection(
                      title: 'Patient Information',
                      icon: Icons.person,
                      color: Colors.purple,
                      children: [
                        TextField(
                          controller: _patientIdController,
                          keyboardType: TextInputType.number,
                          maxLength: 13,
                          decoration: InputDecoration(
                            labelText: 'Patient ID Number',
                            hintText: 'Enter 13-digit ID number',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.badge),
                            suffixIcon: _isLoading
                                ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                                : _patientFound
                                ? Icon(Icons.verified, color: Colors.green.shade600)
                                : _selectedPatientName != null
                                ? Icon(Icons.error, color: Colors.red.shade600)
                                : null,
                          ),
                        ),
                        if (_selectedPatientName != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _patientFound ? Colors.green.shade50 : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _patientFound ? Colors.green.shade200 : Colors.red.shade200,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _patientFound ? Icons.person : Icons.person_off,
                                  color: _patientFound ? Colors.green : Colors.red,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _selectedPatientName!,
                                    style: TextStyle(
                                      color: _patientFound ? Colors.green.shade800 : Colors.red.shade800,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Hospital & Doctor Section
                    _buildSection(
                      title: 'Medical Professional',
                      icon: Icons.medical_services,
                      color: Colors.green,
                      children: [
                        DropdownButtonFormField<String>(
                          value: _selectedHospital,
                          decoration: const InputDecoration(
                            labelText: 'Select Hospital',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.local_hospital),
                          ),
                          items: _availableHospitals.map((hospital) {
                            return DropdownMenuItem(
                              value: hospital,
                              child: Text(hospital),
                            );
                          }).toList(),
                          onChanged: (hospital) {
                            setState(() {
                              _selectedHospital = hospital;
                              _selectedDoctor = null;
                              _availableDoctors = [];
                              _selectedTime = null;
                              _availableTimes = [];
                            });
                            if (hospital != null) _fetchDoctorsForHospital(hospital);
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<Map<String, dynamic>>(
                          value: _selectedDoctor,
                          decoration: const InputDecoration(
                            labelText: 'Select Doctor',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.medical_services),
                          ),
                          items: _availableDoctors.map((doctor) {
                            return DropdownMenuItem(
                              value: doctor,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    doctor['name'],
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  Text(
                                    doctor['specialty'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (doctor) {
                            setState(() {
                              _selectedDoctor = doctor;
                              _selectedTime = null;
                              _availableTimes = [];
                            });
                            if (doctor != null && _selectedDate != null) _fetchAvailableTimes();
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Date & Time Section
                    _buildSection(
                      title: 'Schedule',
                      icon: Icons.access_time,
                      color: Colors.orange,
                      children: [
                        // Date Picker
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, color: Colors.orange.shade600),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Appointment Date',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    Text(
                                      _selectedDate != null
                                          ? DateFormat('EEEE, MMMM dd, yyyy').format(_selectedDate!)
                                          : 'Select date',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.arrow_drop_down, color: Colors.orange.shade600),
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime.now(),
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now().add(const Duration(days: 365)),
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      _selectedDate = picked;
                                      _selectedTime = null;
                                    });
                                    if (_selectedDoctor != null) _fetchAvailableTimes();
                                  }
                                },
                              ),
                            ],
                          ),
                        ),

                        // Time Slots
                        if (_selectedDoctor != null && _selectedDate != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Available Time Slots',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_isLoading)
                            const Center(child: CircularProgressIndicator())
                          else if (_availableTimes.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'No available slots for selected date',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _availableTimes.map((time) {
                                final isSelected = time == _selectedTime;
                                return ChoiceChip(
                                  label: Text(time),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setState(() {
                                      _selectedTime = selected ? time : null;
                                    });
                                  },
                                  selectedColor: Colors.blue,
                                  backgroundColor: Colors.grey.shade100,
                                  labelStyle: TextStyle(
                                    color: isSelected ? Colors.white : Colors.black,
                                    fontWeight: FontWeight.w500,
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Appointment Details Section
                    _buildSection(
                      title: 'Appointment Details',
                      icon: Icons.description,
                      color: Colors.blue,
                      children: [
                        DropdownButtonFormField<String>(
                          value: _selectedAppointmentType,
                          decoration: const InputDecoration(
                            labelText: 'Appointment Type',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.type_specimen),
                          ),
                          items: _appointmentFees.entries.map((entry) {
                            return DropdownMenuItem(
                              value: entry.key,
                              child: Text(
                                '${entry.key[0].toUpperCase()}${entry.key.substring(1)}',
                              ),
                            );
                          }).toList(),
                          onChanged: (type) {
                            setState(() {
                              _selectedAppointmentType = type!;
                              _fee = _appointmentFees[type]!;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _reasonController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Reason for Visit',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                            prefixIcon: Icon(Icons.note),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Fee Display
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Appointment Fee:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'R${_fee.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Create Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading || !_patientFound ? null : _createAppointment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                            : const Text(
                          'Create Appointment',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

void showAdminCreateAppointment(BuildContext context) {
  showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (context) => const AdminCreateAppointmentPopup(),
  );
}