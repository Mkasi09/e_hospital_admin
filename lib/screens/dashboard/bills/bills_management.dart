import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BillsManagementScreen extends StatefulWidget {
  const BillsManagementScreen({super.key});

  @override
  State<BillsManagementScreen> createState() => _BillsManagementScreenState();
}

class _BillsManagementScreenState extends State<BillsManagementScreen> {
  String searchQuery = '';
  String filterStatus = 'All';
  final List<String> statusFilters = ['All', 'Paid', 'Pending', 'Overdue', 'Cancelled'];

  Stream<QuerySnapshot> getBillsStream() {
    return FirebaseFirestore.instance
        .collection('bills')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<String> _getPatientName(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        return userData['name'] ?? userData['fullName'] ?? 'Unknown Patient';
      }
      return 'Patient Not Found';
    } catch (e) {
      return 'Error Loading Patient';
    }
  }

  void _showBillDetails(BuildContext context, DocumentSnapshot billDoc) {
    final data = billDoc.data() as Map<String, dynamic>;

    showDialog(
      context: context,
      builder: (context) => BillDetailsPopup(billData: data, billId: billDoc.id),
    );
  }

  void _updateBillStatus(String billId, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('bills')
          .doc(billId)
          .update({'status': newStatus});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bill status updated to $newStatus'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update bill status'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showStatusUpdateDialog(String billId, String currentStatus) {
    final statusOptions = ['Paid', 'Pending', 'Overdue', 'Cancelled'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Bill Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: statusOptions.map((status) {
            return ListTile(
              leading: Icon(
                status == currentStatus ? Icons.radio_button_checked : Icons.radio_button_off,
                color: status == currentStatus ? Colors.blue : Colors.grey,
              ),
              title: Text(status),
              onTap: () {
                Navigator.pop(context);
                _updateBillStatus(billId, status);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'overdue':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Not available';

    try {
      if (timestamp is Timestamp) {
        return DateFormat('dd MMMM yyyy \'at\' HH:mm').format(timestamp.toDate());
      } else if (timestamp is String) {
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
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'Bills Management',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Manage and track all patient bills',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Search and Filter Row
            Row(
              children: [
                // Search Bar
                Expanded(
                  child: Container(
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
                        hintText: 'Search by patient, doctor, or title...',
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
                ),
                const SizedBox(width: 16),

                // Status Filter
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: filterStatus,
                      items: statusFilters.map((String status) {
                        return DropdownMenuItem<String>(
                          value: status,
                          child: Text(status),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          filterStatus = newValue!;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Header Row
            const _BillsHeaderRow(),

            const SizedBox(height: 8),

            // Bills List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: getBillsStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('Error loading bills'));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No bills found',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  final bills = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;

                    // Apply search filter
                    final matchesSearch = searchQuery.isEmpty ||
                        (data['title']?.toString().toLowerCase().contains(searchQuery) ?? false) ||
                        (data['doctorName']?.toString().toLowerCase().contains(searchQuery) ?? false) ||
                        (data['appointmentType']?.toString().toLowerCase().contains(searchQuery) ?? false);

                    // Apply status filter
                    final matchesStatus = filterStatus == 'All' ||
                        (data['status']?.toString().toLowerCase() == filterStatus.toLowerCase());

                    return matchesSearch && matchesStatus;
                  }).toList();

                  if (bills.isEmpty) {
                    return const Center(
                      child: Text('No bills match your search criteria.'),
                    );
                  }

                  return ListView.builder(
                    itemCount: bills.length,
                    itemBuilder: (context, index) {
                      final bill = bills[index];
                      final data = bill.data() as Map<String, dynamic>;

                      return GestureDetector(
                        onTap: () => _showBillDetails(context, bill),
                        child: BillTile(
                          billData: data,
                          billId: bill.id,
                          onStatusUpdate: () => _showStatusUpdateDialog(
                              bill.id,
                              data['status'] ?? 'Pending'
                          ),
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
    );
  }
}

class _BillsHeaderRow extends StatelessWidget {
  const _BillsHeaderRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: const [
          Expanded(flex: 2, child: Text('Bill Title', style: _headerStyle)),
          Expanded(flex: 2, child: Text('Patient/Doctor', style: _headerStyle)),
          Expanded(flex: 1, child: Text('Amount', style: _headerStyle)),
          Expanded(flex: 1, child: Text('Status', style: _headerStyle)),
          Expanded(flex: 1, child: Text('Date', style: _headerStyle)),
          Expanded(flex: 1, child: Text('Actions', style: _headerStyle)),
        ],
      ),
    );
  }
}

class BillTile extends StatelessWidget {
  final Map<String, dynamic> billData;
  final String billId;
  final VoidCallback onStatusUpdate;

  const BillTile({
    super.key,
    required this.billData,
    required this.billId,
    required this.onStatusUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final amount = (billData['amount'] as num?)?.toDouble() ?? 0.0;
    final status = billData['status']?.toString() ?? 'Pending';
    final timestamp = billData['timestamp'];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          // Bill Title
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  billData['title'] ?? 'No Title',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (billData['appointmentType'] != null)
                  Text(
                    billData['appointmentType'].toString(),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
          ),

          // Patient/Doctor Info
          Expanded(
            flex: 2,
            child: FutureBuilder<String>(
              future: _getPatientName(billData['userId']),
              builder: (context, snapshot) {
                final patientName = snapshot.data ?? 'Loading...';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (billData['doctorName'] != null)
                      Text(
                        'Dr: ${billData['doctorName']}',
                        style: const TextStyle(fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      'Patient: $patientName',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                );
              },
            ),
          ),

          // Amount
          Expanded(
            flex: 1,
            child: Text(
              'R${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: amount > 0 ? Colors.green : Colors.grey,
              ),
            ),
          ),

          // Status
          Expanded(
            flex: 1,
            child: Container(
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: _getStatusColor(status),
                ),
              ),
            ),
          ),
SizedBox(width: 6),
          // Date
          Expanded(
            flex: 1,
            child: Text(
              _formatTimestampShort(timestamp),
              style: const TextStyle(fontSize: 12),
            ),
          ),

          // Actions
          Expanded(
            flex: 1,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: onStatusUpdate,
                  tooltip: 'Update Status',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<String> _getPatientName(String? userId) async {
    if (userId == null || userId.isEmpty) return 'No Patient';

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        return userData['name'] ?? userData['fullName'] ?? 'Unknown Patient';
      }
      return 'Patient Not Found';
    } catch (e) {
      return 'Error Loading';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'overdue':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  String _formatTimestampShort(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    try {
      if (timestamp is Timestamp) {
        return DateFormat('MMM dd').format(timestamp.toDate());
      }
      return 'N/A';
    } catch (e) {
      return 'N/A';
    }
  }
}

class BillDetailsPopup extends StatelessWidget {
  final Map<String, dynamic> billData;
  final String billId;

  const BillDetailsPopup({
    super.key,
    required this.billData,
    required this.billId,
  });

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Not available';

    try {
      if (timestamp is Timestamp) {
        return DateFormat('dd MMMM yyyy \'at\' HH:mm').format(timestamp.toDate());
      }
      return 'Invalid date';
    } catch (e) {
      return 'Date format error';
    }
  }

  String _formatCurrency(double amount) {
    return 'R${amount.toStringAsFixed(2)}';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'overdue':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  Future<String> _getPatientName(String? userId) async {
    if (userId == null || userId.isEmpty) return 'No Patient Information';

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final name = userData['name'] ?? userData['fullName'] ?? 'Unknown Patient';
        final email = userData['email'] ?? '';
        return '$name${email.isNotEmpty ? ' ($email)' : ''}';
      }
      return 'Patient Not Found';
    } catch (e) {
      return 'Error Loading Patient Information';
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = (billData['amount'] as num?)?.toDouble() ?? 0.0;
    final status = billData['status']?.toString() ?? 'Pending';

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
                    'Bill Details',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _getStatusColor(status)),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(status),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Amount Highlight
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Total Amount',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatCurrency(amount),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Bill Information
              const Text(
                'Bill Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 16),

              _buildDetailRow('Bill Title', billData['title'] ?? 'Not provided'),
              _buildDetailRow('Appointment Type', billData['appointmentType'] ?? 'Not provided'),
              _buildDetailRow('Appointment ID', billData['appointmentId'] ?? 'Not provided'),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // Professional Information
              const Text(
                'Professional Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 16),

              _buildDetailRow('Doctor Name', billData['doctorName'] ?? 'Not provided'),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // Patient Information
              const Text(
                'Patient Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 16),

              FutureBuilder<String>(
                future: _getPatientName(billData['userId']),
                builder: (context, snapshot) {
                  return _buildDetailRow(
                      'Patient Name',
                      snapshot.data ?? 'Loading...'
                  );
                },
              ),
              _buildDetailRow('Patient ID', billData['userId'] ?? 'Not provided'),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // Timestamp Information
              const Text(
                'Timestamps',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 16),

              _buildDetailRow('Created Date', _formatTimestamp(billData['timestamp'])),

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
  fontSize: 14,
  fontWeight: FontWeight.bold,
  color: Colors.black87,
);