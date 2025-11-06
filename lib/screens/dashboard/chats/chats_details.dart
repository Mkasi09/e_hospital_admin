import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';

import 'chats_management.dart';

class ChatPopupScreen extends StatefulWidget {
  final ChatRoom chatRoom;

  const ChatPopupScreen({super.key, required this.chatRoom});

  @override
  State<ChatPopupScreen> createState() => _ChatPopupScreenState();
}

class _ChatPopupScreenState extends State<ChatPopupScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  bool _isLoading = false;
  bool _isChatSuspended = false;

  @override
  void initState() {
    super.initState();
    _scrollToBottom();
    _checkChatStatus();
  }

  void _checkChatStatus() async {
    try {
      final snapshot =
          await _databaseRef
              .child('chats')
              .child(widget.chatRoom.id)
              .child('suspended')
              .once();

      if (snapshot.snapshot.value != null) {
        setState(() {
          _isChatSuspended = snapshot.snapshot.value as bool;
        });
      }
    } catch (e) {
      print('Error checking chat status: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.minScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isChatSuspended) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final messageData = {
        'text': _messageController.text.trim(),
        'senderId': 'admin', // Admin is sending the message
        'senderName': 'Admin',
        'timestamp': ServerValue.timestamp,
        'read': false,
        'type': 'text',
      };

      await _databaseRef
          .child('chats')
          .child(widget.chatRoom.id)
          .child('messages')
          .push()
          .set(messageData);

      // Update last updated timestamp
      await _databaseRef
          .child('chats')
          .child(widget.chatRoom.id)
          .child('meta')
          .child('lastUpdated')
          .set(ServerValue.timestamp);

      setState(() {
        _isLoading = false;
        _messageController.clear();
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackbar('Failed to send message: $e');
    }
  }

  void _showMessageActions(ChatMessage message, BuildContext context) {
    final isReported = _isMessageReported(message.id);

    showModalBottomSheet(
      context: context,
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isReported) ...[
                  ListTile(
                    leading: const Icon(Icons.warning, color: Colors.orange),
                    title: const Text('Reported Message'),
                    subtitle: const Text('This message has been reported'),
                    textColor: Colors.orange,
                    iconColor: Colors.orange,
                  ),
                  const Divider(),
                ],
                ListTile(
                  leading: const Icon(Icons.content_copy),
                  title: const Text('Copy Message'),
                  onTap: () {
                    Navigator.pop(context);
                    _copyToClipboard(message.text);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.visibility),
                  title: const Text('View Message Details'),
                  onTap: () {
                    Navigator.pop(context);
                    _showMessageDetails(message);
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Delete Message'),
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteMessageDialog(message);
                  },
                ),
                if (!isReported) ...[
                  ListTile(
                    leading: const Icon(Icons.flag, color: Colors.orange),
                    title: const Text('Report Message'),
                    onTap: () {
                      Navigator.pop(context);
                      _showReportDialog(message);
                    },
                  ),
                ],
                if (isReported) ...[
                  ListTile(
                    leading: const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                    ),
                    title: const Text('Resolve Report'),
                    onTap: () {
                      Navigator.pop(context);
                      _resolveMessageReport(message);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.close, color: Colors.blue),
                    title: const Text('Dismiss Report'),
                    onTap: () {
                      Navigator.pop(context);
                      _dismissMessageReport(message);
                    },
                  ),
                ],
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.cancel),
                  title: const Text('Cancel'),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
    );
  }

  bool _isMessageReported(String messageId) {
    // Check if message has any pending reports
    return widget.chatRoom.reports.any(
      (report) => report.messageId == messageId && report.status == 'pending',
    );
  }

  void _showMessageDetails(ChatMessage message) {
    final reports =
        widget.chatRoom.reports
            .where((report) => report.messageId == message.id)
            .toList();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Message Details'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Message ID', message.id),
                  _buildDetailRow(
                    'Sender',
                    message.senderId == widget.chatRoom.doctorId
                        ? 'Dr. ${widget.chatRoom.doctorName}'
                        : widget.chatRoom.patientName,
                  ),
                  _buildDetailRow('Timestamp', _formatDate(message.timestamp)),
                  _buildDetailRow(
                    'Read Status',
                    message.read ? 'Read' : 'Unread',
                  ),
                  if (reports.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Reports:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    ...reports.map((report) => _buildReportCard(report)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  Widget _buildReportCard(ChatReport report) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _getReportColor(report.status).withOpacity(0.1),
        border: Border.all(color: _getReportColor(report.status)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag, size: 16, color: _getReportColor(report.status)),
              const SizedBox(width: 4),
              Text(
                report.status.toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _getReportColor(report.status),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Reason: ${report.reason}'),
          if (report.description.isNotEmpty)
            Text('Details: ${report.description}'),
          Text('Reported: ${_formatDate(report.timestamp)}'),
          if (report.resolvedBy != null)
            Text('Resolved by: ${report.resolvedBy}'),
        ],
      ),
    );
  }

  Color _getReportColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'resolved':
        return Colors.green;
      case 'dismissed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  void _copyToClipboard(String text) {
    // Implement clipboard functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Message copied to clipboard')),
    );
  }

  void _showDeleteMessageDialog(ChatMessage message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Message'),
            content: const Text(
              'Are you sure you want to delete this message? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteMessage(message);
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  void _deleteMessage(ChatMessage message) async {
    try {
      await _databaseRef
          .child('chats')
          .child(widget.chatRoom.id)
          .child('messages')
          .child(message.id)
          .remove();

      // Also remove any reports for this message
      await _databaseRef
          .child('chats')
          .child(widget.chatRoom.id)
          .child('reports')
          .child(message.id)
          .remove();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showErrorSnackbar('Failed to delete message: $e');
    }
  }

  void _showReportDialog(ChatMessage message) {
    final reasons = [
      'Inappropriate content',
      'Harassment or bullying',
      'Spam or misleading information',
      'Privacy violation',
      'Medical misinformation',
      'Other',
    ];

    String? selectedReason;
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.flag, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Report Message as Admin'),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Message from ${message.senderId == widget.chatRoom.doctorId ? 'Dr. ${widget.chatRoom.doctorName}' : widget.chatRoom.patientName}:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          message.text,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Select reason:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...reasons
                          .map(
                            (reason) => RadioListTile<String>(
                              title: Text(reason),
                              value: reason,
                              groupValue: selectedReason,
                              onChanged: (value) {
                                setDialogState(() {
                                  selectedReason = value;
                                });
                              },
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          )
                          .toList(),
                      const SizedBox(height: 16),
                      TextField(
                        controller: descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Admin notes (optional)',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed:
                        selectedReason == null
                            ? null
                            : () {
                              _submitAdminReport(
                                message,
                                selectedReason!,
                                descriptionController.text,
                              );
                              Navigator.pop(context);
                            },
                    child: const Text(
                      'Report',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              );
            },
          ),
    );
  }

  void _submitAdminReport(
    ChatMessage message,
    String reason,
    String description,
  ) async {
    try {
      final reportData = {
        'messageId': message.id,
        'messageText': message.text,
        'senderId': message.senderId,
        'senderName':
            message.senderId == widget.chatRoom.doctorId
                ? 'Dr. ${widget.chatRoom.doctorName}'
                : widget.chatRoom.patientName,
        'reportedBy': 'admin',
        'reportedByName': 'Administrator',
        'reason': reason,
        'description': description,
        'timestamp': ServerValue.timestamp,
        'status': 'pending',
        'chatId': widget.chatRoom.id,
        'adminReport': true,
      };

      await _databaseRef
          .child('chats')
          .child(widget.chatRoom.id)
          .child('reports')
          .child(message.id)
          .set(reportData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message reported successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showErrorSnackbar('Failed to report message: $e');
    }
  }

  void _resolveMessageReport(ChatMessage message) async {
    try {
      await _databaseRef
          .child('chats')
          .child(widget.chatRoom.id)
          .child('reports')
          .child(message.id)
          .update({
            'status': 'resolved',
            'resolvedBy': 'admin',
            'resolvedAt': ServerValue.timestamp,
          });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report marked as resolved'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showErrorSnackbar('Failed to resolve report: $e');
    }
  }

  void _dismissMessageReport(ChatMessage message) async {
    try {
      await _databaseRef
          .child('chats')
          .child(widget.chatRoom.id)
          .child('reports')
          .child(message.id)
          .update({
            'status': 'dismissed',
            'resolvedBy': 'admin',
            'resolvedAt': ServerValue.timestamp,
          });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report dismissed'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      _showErrorSnackbar('Failed to dismiss report: $e');
    }
  }

  void _showChatInfo() {
    final totalReports = widget.chatRoom.reports.length;
    final pendingReports =
        widget.chatRoom.reports
            .where((report) => report.status == 'pending')
            .length;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Chat Information'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildInfoRow('Patient', widget.chatRoom.patientName),
                  _buildInfoRow('Patient ID', widget.chatRoom.patientId),
                  _buildInfoRow('Doctor', 'Dr. ${widget.chatRoom.doctorName}'),
                  _buildInfoRow('Specialty', widget.chatRoom.doctorSpecialty),
                  _buildInfoRow(
                    'Total Messages',
                    '${widget.chatRoom.messages.length}',
                  ),
                  _buildInfoRow(
                    'Reports',
                    '$totalReports (${pendingReports} pending)',
                  ),
                  _buildInfoRow(
                    'Chat Status',
                    _isChatSuspended ? 'SUSPENDED' : 'Active',
                  ),
                  _buildInfoRow(
                    'Created',
                    _formatDate(widget.chatRoom.lastUpdated),
                  ),
                  _buildInfoRow(
                    'Last Activity',
                    _formatDate(widget.chatRoom.lastUpdated),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color:
                    label == 'Chat Status' && value == 'SUSPENDED'
                        ? Colors.red
                        : null,
                fontWeight:
                    label == 'Chat Status' && value == 'SUSPENDED'
                        ? FontWeight.bold
                        : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMoreActions() {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.people),
                  title: const Text('View Participants'),
                  onTap: () {
                    Navigator.pop(context);
                    _showParticipants();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.security),
                  title: const Text('Security Actions'),
                  onTap: () {
                    Navigator.pop(context);
                    _showSecurityActions();
                  },
                ),
                ListTile(
                  leading: Icon(
                    _isChatSuspended ? Icons.play_arrow : Icons.pause,
                    color: _isChatSuspended ? Colors.green : Colors.orange,
                  ),
                  title: Text(
                    _isChatSuspended ? 'Resume Chat' : 'Suspend Chat',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _isChatSuspended ? _resumeChat() : _suspendChat();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.cleaning_services),
                  title: const Text('Clear Chat History'),
                  onTap: () {
                    Navigator.pop(context);
                    _showClearHistoryConfirmation();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.import_export),
                  title: const Text('Export Chat'),
                  onTap: () {
                    Navigator.pop(context);
                    _exportChat();
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.cancel),
                  title: const Text('Cancel'),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
    );
  }

  void _showSecurityActions() {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(
                  leading: Icon(Icons.security, color: Colors.orange),
                  title: Text('Security Actions'),
                  subtitle: Text('Manage chat security and restrictions'),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.warning, color: Colors.orange),
                  title: const Text('View All Reports'),
                  onTap: () {
                    Navigator.pop(context);
                    _showAllReports();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.block, color: Colors.red),
                  title: const Text('Block User'),
                  onTap: () {
                    Navigator.pop(context);
                    _showBlockConfirmation();
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.notifications_off,
                    color: Colors.purple,
                  ),
                  title: const Text('Disable Notifications'),
                  onTap: () {
                    Navigator.pop(context);
                    _disableNotifications();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.archive, color: Colors.blue),
                  title: const Text('Archive Chat'),
                  onTap: () {
                    Navigator.pop(context);
                    _archiveChat();
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.cancel),
                  title: const Text('Cancel'),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
    );
  }

  void _showAllReports() {
    final reports = widget.chatRoom.reports;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('All Reports'),
            content: SizedBox(
              width: double.maxFinite,
              child:
                  reports.isEmpty
                      ? const Center(child: Text('No reports found'))
                      : ListView.builder(
                        shrinkWrap: true,
                        itemCount: reports.length,
                        itemBuilder: (context, index) {
                          return _buildReportListItem(reports[index]);
                        },
                      ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  Widget _buildReportListItem(ChatReport report) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(Icons.flag, color: _getReportColor(report.status)),
        title: Text(report.reason),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${report.status}'),
            if (report.description.isNotEmpty)
              Text('Details: ${report.description}'),
            Text('Reported: ${_formatDate(report.timestamp)}'),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            _handleReportAction(value, report);
          },
          itemBuilder:
              (context) => [
                const PopupMenuItem(
                  value: 'view_message',
                  child: Text('View Message'),
                ),
                if (report.status == 'pending') ...[
                  const PopupMenuItem(
                    value: 'resolve',
                    child: Text('Resolve Report'),
                  ),
                  const PopupMenuItem(
                    value: 'dismiss',
                    child: Text('Dismiss Report'),
                  ),
                ],
                const PopupMenuItem(
                  value: 'delete_report',
                  child: Text('Delete Report'),
                ),
              ],
        ),
      ),
    );
  }

  void _handleReportAction(String action, ChatReport report) {
    switch (action) {
      case 'view_message':
        final message = widget.chatRoom.messages.firstWhere(
          (msg) => msg.id == report.messageId,
        );
        _showMessageDetails(message);
        break;
      case 'resolve':
        final message = widget.chatRoom.messages.firstWhere(
          (msg) => msg.id == report.messageId,
        );
        _resolveMessageReport(message);
        break;
      case 'dismiss':
        final message = widget.chatRoom.messages.firstWhere(
          (msg) => msg.id == report.messageId,
        );
        _dismissMessageReport(message);
        break;
      case 'delete_report':
        _deleteReport(report);
        break;
    }
  }

  void _deleteReport(ChatReport report) async {
    try {
      await _databaseRef
          .child('chats')
          .child(widget.chatRoom.id)
          .child('reports')
          .child(report.messageId)
          .remove();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showErrorSnackbar('Failed to delete report: $e');
    }
  }

  void _suspendChat() async {
    try {
      await _databaseRef
          .child('chats')
          .child(widget.chatRoom.id)
          .child('suspended')
          .set(true);

      setState(() {
        _isChatSuspended = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chat suspended successfully'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      _showErrorSnackbar('Failed to suspend chat: $e');
    }
  }

  void _resumeChat() async {
    try {
      await _databaseRef
          .child('chats')
          .child(widget.chatRoom.id)
          .child('suspended')
          .set(false);

      setState(() {
        _isChatSuspended = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chat resumed successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showErrorSnackbar('Failed to resume chat: $e');
    }
  }

  void _showParticipants() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Chat Participants'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildParticipantTile(
                  widget.chatRoom.patientName,
                  'Patient',
                  Icons.person,
                ),
                const SizedBox(height: 12),
                _buildParticipantTile(
                  'Dr. ${widget.chatRoom.doctorName}',
                  widget.chatRoom.doctorSpecialty,
                  Icons.medical_services,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  Widget _buildParticipantTile(String name, String role, IconData icon) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: Colors.blue[100],
          child: Icon(icon, color: Colors.blue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(
                role,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showBlockConfirmation() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Block User'),
            content: const Text(
              'Are you sure you want to block a user in this chat? They will no longer be able to send messages.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _blockUser();
                },
                child: const Text('Block', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }

  void _blockUser() {
    // Implement block logic
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('User blocked')));
  }

  void _disableNotifications() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Notifications disabled')));
  }

  void _archiveChat() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Chat archived')));
  }

  void _showClearHistoryConfirmation() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Clear Chat History'),
            content: const Text(
              'This will delete all messages in this chat. This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _clearHistory();
                },
                child: const Text(
                  'Clear All',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
            ],
          ),
    );
  }

  void _clearHistory() async {
    try {
      await _databaseRef
          .child('chats')
          .child(widget.chatRoom.id)
          .child('messages')
          .remove();

      // Also clear reports
      await _databaseRef
          .child('chats')
          .child(widget.chatRoom.id)
          .child('reports')
          .remove();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chat history cleared successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showErrorSnackbar('Failed to clear chat history: $e');
    }
  }

  void _exportChat() {
    // Implement export logic
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Chat exported successfully')));
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy - HH:mm').format(date);
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: MediaQuery.of(context).size.height * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isChatSuspended ? Colors.orange[50] : Colors.grey[50],
                border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor:
                        _isChatSuspended
                            ? Colors.orange[100]
                            : Colors.blue[100],
                    child: Icon(
                      _isChatSuspended ? Icons.pause : Icons.chat,
                      color: _isChatSuspended ? Colors.orange : Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.chatRoom.patientName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'With Dr. ${widget.chatRoom.doctorName}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (_isChatSuspended)
                          Text(
                            'CHAT SUSPENDED',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.info_outline),
                    onPressed: _showChatInfo,
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: _showMoreActions,
                  ),
                ],
              ),
            ),

            // Messages
            Expanded(
              child:
                  widget.chatRoom.messages.isEmpty
                      ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No messages yet',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                      : Expanded(
                        child: StreamBuilder(
                          stream:
                              _databaseRef
                                  .child('chats')
                                  .child(widget.chatRoom.id)
                                  .child('messages')
                                  .orderByChild('timestamp')
                                  .onValue,
                          builder: (context, snapshot) {
                            if (!snapshot.hasData ||
                                snapshot.data?.snapshot.value == null) {
                              return const Center(
                                child: Text('No messages yet'),
                              );
                            }

                            final data = Map<String, dynamic>.from(
                              snapshot.data!.snapshot.value as Map,
                            );

                            final messages =
                                data.entries.map((e) {
                                  return ChatMessage(
                                    id: e.key,
                                    text: e.value['text'] ?? '',
                                    senderId: e.value['senderId'],
                                    timestamp:
                                        DateTime.fromMillisecondsSinceEpoch(
                                          e.value['timestamp'] ?? 0,
                                        ),
                                    read: e.value['read'] ?? false,
                                  );
                                }).toList();

                            messages.sort(
                              (a, b) => b.timestamp.compareTo(a.timestamp),
                            );

                            return ListView.builder(
                              controller: _scrollController,
                              reverse: true,
                              padding: const EdgeInsets.all(16),
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                final message = messages[index];
                                return _buildMessageBubble(message, context);
                              },
                            );
                          },
                        ),
                      ),
            ),

            // Input Area
            if (!_isChatSuspended) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border(top: BorderSide(color: Colors.grey[300]!)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Type a message as admin...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        maxLines: null,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: _isLoading ? Colors.grey : Colors.blue,
                      child: IconButton(
                        icon:
                            _isLoading
                                ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                      Colors.white,
                                    ),
                                  ),
                                )
                                : const Icon(
                                  Icons.send,
                                  color: Colors.white,
                                  size: 20,
                                ),
                        onPressed: _isLoading ? null : _sendMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  border: Border(top: BorderSide(color: Colors.orange[300]!)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.pause, color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This chat is currently suspended. Resume chat to send messages.',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, BuildContext context) {
    final isDoctor = message.senderId == widget.chatRoom.doctorId;
    final isPatient = message.senderId == widget.chatRoom.patientId;
    final isAdmin = message.senderId == 'admin';
    final isReported = _isMessageReported(message.id);

    return GestureDetector(
      onLongPress: () => _showMessageActions(message, context),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment:
              isDoctor || isAdmin
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (isPatient) ...[
              CircleAvatar(
                radius: 12,
                backgroundColor: Colors.green[100],
                child: Icon(Icons.person, size: 14, color: Colors.green),
              ),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      isAdmin
                          ? Colors.purple[50]
                          : isDoctor
                          ? Colors.blue[50]
                          : Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        isReported
                            ? Colors.orange
                            : isAdmin
                            ? Colors.purple[100]!
                            : isDoctor
                            ? Colors.blue[100]!
                            : Colors.grey[300]!,
                    width: isReported ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isPatient)
                      Text(
                        widget.chatRoom.patientName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                    if (isAdmin)
                      Text(
                        'Admin',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple[700],
                        ),
                      ),
                    Text(message.text, style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormat('HH:mm').format(message.timestamp),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (isReported) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.flag, size: 12, color: Colors.orange),
                        ],
                        if (isDoctor || isAdmin) ...[
                          const SizedBox(width: 4),
                          Icon(
                            message.read ? Icons.done_all : Icons.done,
                            size: 12,
                            color: message.read ? Colors.blue : Colors.grey,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (isDoctor || isAdmin) ...[
              const SizedBox(width: 4),
              CircleAvatar(
                radius: 12,
                backgroundColor:
                    isAdmin ? Colors.purple[100] : Colors.blue[100],
                child: Icon(
                  isAdmin ? Icons.security : Icons.medical_services,
                  size: 14,
                  color: isAdmin ? Colors.purple : Colors.blue,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
