import 'package:e_hospotal_admin/screens/dashboard/chats/room.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'chats_details.dart';

class ChatsManagementScreen extends StatefulWidget {
  const ChatsManagementScreen({super.key});

  @override
  State<ChatsManagementScreen> createState() => _ChatsManagementScreenState();
}

class _ChatsManagementScreenState extends State<ChatsManagementScreen> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  String searchQuery = '';
  String? selectedStatus;
  bool _showReportedChats = false;

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chats Management',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _showReportedChats
                          ? 'Review and manage reported conversations'
                          : 'Monitor and manage conversations between doctors and patients',
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
                // Toggle Button for Reported Chats
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.flag,
                        color: _showReportedChats ? Colors.red : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Reported Chats',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: _showReportedChats ? Colors.red : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Switch(
                        value: _showReportedChats,
                        onChanged: (value) {
                          setState(() {
                            _showReportedChats = value;
                          });
                        },
                        activeColor: Colors.red,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Search and Filters
            _buildSearchAndFilters(),
            const SizedBox(height: 16),

            // Chats List
            Expanded(child: _buildChatsList()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            decoration: InputDecoration(
              hintText:
                  _showReportedChats
                      ? 'Search reported chats...'
                      : 'Search by patient or doctor name...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onChanged: (value) {
              setState(() {
                searchQuery = value.toLowerCase();
              });
            },
          ),
        ),
        const SizedBox(width: 12),
        PopupMenuButton<String>(
          icon: const Icon(Icons.filter_list, size: 28),
          onSelected: (value) {
            setState(() {
              selectedStatus = value == 'all' ? null : value;
            });
          },
          itemBuilder:
              (context) => [
                const PopupMenuItem(value: 'all', child: Text('All Chats')),
                if (!_showReportedChats) ...[
                  const PopupMenuItem(
                    value: 'active',
                    child: Text('Active Now'),
                  ),
                  const PopupMenuItem(value: 'recent', child: Text('Recent')),
                  const PopupMenuItem(
                    value: 'unread',
                    child: Text('Unread Messages'),
                  ),
                ],
                if (_showReportedChats) ...[
                  const PopupMenuItem(
                    value: 'pending',
                    child: Text('Pending Review'),
                  ),
                  const PopupMenuItem(
                    value: 'resolved',
                    child: Text('Resolved'),
                  ),
                  const PopupMenuItem(
                    value: 'dismissed',
                    child: Text('Dismissed'),
                  ),
                ],
              ],
        ),
      ],
    );
  }

  Widget _buildChatsList() {
    return StreamBuilder<DatabaseEvent>(
      stream: _databaseRef.child('chats').onValue,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return _buildEmptyState();
        }

        final Map<dynamic, dynamic> chatsData =
            snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
        final List<ChatRoom> chatRooms = [];

        // Process chat rooms
        chatsData.forEach((chatId, chatData) {
          if (chatData is Map && chatData.containsKey('meta')) {
            final meta = chatData['meta'] as Map<dynamic, dynamic>;
            final messages =
                chatData['messages'] as Map<dynamic, dynamic>? ?? {};
            final reports = chatData['reports'] as Map<dynamic, dynamic>? ?? {};

            final chatRoom = ChatRoom(
              id: chatId.toString(),
              doctorId: meta['doctorId']?.toString() ?? '',
              doctorName: meta['doctorName']?.toString() ?? 'Unknown Doctor',
              doctorSpecialty: meta['doctorSpecialty']?.toString() ?? '',
              patientId: meta['patientId']?.toString() ?? '',
              patientName: meta['patientName']?.toString() ?? 'Unknown Patient',
              lastUpdated:
                  meta['lastUpdated'] != null
                      ? DateTime.fromMillisecondsSinceEpoch(
                        int.parse(meta['lastUpdated'].toString()),
                      )
                      : DateTime.now(),
              messages: _processMessages(messages),
              typing: _processTypingStatus(meta['typing']),
              reports: _processReports(reports),
            );

            // Apply filters based on whether we're showing reported chats or not
            if (_shouldShowChat(chatRoom)) {
              chatRooms.add(chatRoom);
            }
          }
        });

        // Sort by last updated (newest first) or by report count for reported chats
        if (_showReportedChats) {
          chatRooms.sort(
            (a, b) => b.reports.length.compareTo(a.reports.length),
          );
        } else {
          chatRooms.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
        }

        if (chatRooms.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          itemCount: chatRooms.length,
          itemBuilder: (context, index) {
            return _buildChatRoomCard(chatRooms[index]);
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _showReportedChats
                ? Icons.flag_outlined
                : Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            _showReportedChats ? 'No reported chats found' : 'No chats found',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          if (_showReportedChats) ...[
            const SizedBox(height: 8),
            const Text(
              'All reported chats will appear here for review',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  List<ChatMessage> _processMessages(Map<dynamic, dynamic> messagesData) {
    final List<ChatMessage> messages = [];

    messagesData.forEach((key, value) {
      if (value is Map) {
        messages.add(
          ChatMessage(
            id: key.toString(),
            text: value['text']?.toString() ?? '',
            senderId: value['senderId']?.toString() ?? '',
            timestamp:
                value['timestamp'] != null
                    ? DateTime.fromMillisecondsSinceEpoch(
                      int.parse(value['timestamp'].toString()),
                    )
                    : DateTime.now(),
            read: value['read']?.toString() == 'true',
          ),
        );
      }
    });

    // Sort by timestamp
    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return messages;
  }

  Map<String, bool> _processTypingStatus(dynamic typingData) {
    if (typingData is Map) {
      final Map<String, bool> typingStatus = {};
      typingData.forEach((key, value) {
        if (value is bool) {
          typingStatus[key.toString()] = value;
        }
      });
      return typingStatus;
    }
    return {};
  }

  List<ChatReport> _processReports(dynamic reportsData) {
    final List<ChatReport> reports = [];

    if (reportsData is Map) {
      reportsData.forEach((key, value) {
        if (value is Map) {
          reports.add(
            ChatReport(
              id: key.toString(),
              reportedBy: value['reportedBy']?.toString() ?? '',
              reportedById: value['reportedById']?.toString() ?? '',
              reason: value['reason']?.toString() ?? '',
              description: value['description']?.toString() ?? '',
              timestamp:
                  value['timestamp'] != null
                      ? DateTime.fromMillisecondsSinceEpoch(
                        int.parse(value['timestamp'].toString()),
                      )
                      : DateTime.now(),
              status: value['status']?.toString() ?? 'pending',
              resolvedBy: value['resolvedBy']?.toString(),
              resolvedAt:
                  value['resolvedAt'] != null
                      ? DateTime.fromMillisecondsSinceEpoch(
                        int.parse(value['resolvedAt'].toString()),
                      )
                      : null,
              messageId: value['messageId']?.toString() ?? '',
            ),
          );
        }
      });
    }

    // Sort by timestamp (newest first)
    reports.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return reports;
  }

  bool _shouldShowChat(ChatRoom chatRoom) {
    // Search filter
    if (searchQuery.isNotEmpty) {
      final matchesPatient = chatRoom.patientName.toLowerCase().contains(
        searchQuery,
      );
      final matchesDoctor = chatRoom.doctorName.toLowerCase().contains(
        searchQuery,
      );
      if (!matchesPatient && !matchesDoctor) {
        return false;
      }
    }

    if (_showReportedChats) {
      // Only show chats with reports
      if (chatRoom.reports.isEmpty) return false;

      // Status filters for reported chats
      if (selectedStatus != null) {
        switch (selectedStatus) {
          case 'pending':
            final hasPending = chatRoom.reports.any(
              (report) => report.status == 'pending',
            );
            if (!hasPending) return false;
            break;
          case 'resolved':
            final hasResolved = chatRoom.reports.any(
              (report) => report.status == 'resolved',
            );
            if (!hasResolved) return false;
            break;
          case 'dismissed':
            final hasDismissed = chatRoom.reports.any(
              (report) => report.status == 'dismissed',
            );
            if (!hasDismissed) return false;
            break;
        }
      }
    } else {
      // Regular chat filters
      if (selectedStatus != null) {
        switch (selectedStatus) {
          case 'active':
            final isActive =
                chatRoom.typing[chatRoom.patientId] == true ||
                chatRoom.typing[chatRoom.doctorId] == true;
            if (!isActive) return false;
            break;
          case 'recent':
            final isRecent = chatRoom.lastUpdated.isAfter(
              DateTime.now().subtract(const Duration(hours: 24)),
            );
            if (!isRecent) return false;
            break;
          case 'unread':
            final hasUnread = chatRoom.messages.any((message) => !message.read);
            if (!hasUnread) return false;
            break;
        }
      }
    }

    return true;
  }

  Widget _buildChatRoomCard(ChatRoom chatRoom) {
    final lastMessage =
        chatRoom.messages.isNotEmpty ? chatRoom.messages.last : null;
    final isPatientTyping = chatRoom.typing[chatRoom.patientId] == true;
    final isDoctorTyping = chatRoom.typing[chatRoom.doctorId] == true;
    final isAnyoneTyping = isPatientTyping || isDoctorTyping;
    final hasUnread = chatRoom.messages.any((message) => !message.read);
    final pendingReports =
        chatRoom.reports.where((report) => report.status == 'pending').length;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Stack(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _showReportedChats ? Colors.red[100] : Colors.blue[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                _showReportedChats ? Icons.flag : Icons.chat,
                color: _showReportedChats ? Colors.red : Colors.blue,
              ),
            ),
            if (hasUnread && !_showReportedChats)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            if (_showReportedChats && pendingReports > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      pendingReports > 9 ? '9+' : pendingReports.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    chatRoom.patientName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  _formatTime(chatRoom.lastUpdated),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'With Dr. ${chatRoom.doctorName}',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            if (chatRoom.doctorSpecialty.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                chatRoom.doctorSpecialty,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            if (_showReportedChats) ...[
              _buildReportsInfo(chatRoom),
            ] else if (isAnyoneTyping) ...[
              Row(
                children: [
                  Icon(Icons.edit, size: 14, color: Colors.orange[700]),
                  const SizedBox(width: 4),
                  Text(
                    isPatientTyping
                        ? 'Patient is typing...'
                        : 'Doctor is typing...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[700],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ] else if (lastMessage != null) ...[
              Text(
                lastMessage.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ] else ...[
              Text(
                'No messages yet',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                if (_showReportedChats) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _getReportStatusColor(chatRoom),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${chatRoom.reports.length} REPORT${chatRoom.reports.length > 1 ? 'S' : ''}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color:
                          hasUnread
                              ? Colors.red.withOpacity(0.1)
                              : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: hasUnread ? Colors.red : Colors.green,
                      ),
                    ),
                    child: Text(
                      hasUnread ? 'UNREAD' : 'READ',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: hasUnread ? Colors.red : Colors.green,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Text(
                  '${chatRoom.messages.length} messages',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
        onTap:
            () =>
                _showReportedChats
                    ? _showReportsOverview(chatRoom, context)
                    : _openChatPopup(chatRoom, context),
        trailing:
            _showReportedChats
                ? IconButton(
                  icon: const Icon(Icons.warning_amber, color: Colors.orange),
                  onPressed: () => _showReportsOverview(chatRoom, context),
                )
                : null,
      ),
    );
  }

  Widget _buildReportsInfo(ChatRoom chatRoom) {
    final pendingCount =
        chatRoom.reports.where((r) => r.status == 'pending').length;
    final resolvedCount =
        chatRoom.reports.where((r) => r.status == 'resolved').length;
    final dismissedCount =
        chatRoom.reports.where((r) => r.status == 'dismissed').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${chatRoom.reports.length} report${chatRoom.reports.length > 1 ? 's' : ''} • '
          '$pendingCount pending • $resolvedCount resolved • $dismissedCount dismissed',
          style: const TextStyle(fontSize: 12, color: Colors.red),
        ),
        if (chatRoom.reports.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Latest: ${chatRoom.reports.first.reason}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ],
      ],
    );
  }

  Color _getReportStatusColor(ChatRoom chatRoom) {
    final hasPending = chatRoom.reports.any(
      (report) => report.status == 'pending',
    );
    if (hasPending) return Colors.red;
    return Colors.orange;
  }

  void _showReportsOverview(ChatRoom chatRoom, BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => ReportsOverviewDialog(
            chatRoom: chatRoom,
            onReportsUpdated: () {
              setState(() {}); // Refresh the UI
            },
          ),
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date.isAfter(today)) {
      return DateFormat('HH:mm').format(date);
    } else if (date.isAfter(yesterday)) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM dd').format(date);
    }
  }

  String _formatDateTime(DateTime date) {
    return DateFormat('MMM dd, yyyy - HH:mm').format(date);
  }
}

// Updated Models
class ChatRoom {
  final String id;
  final String doctorId;
  final String doctorName;
  final String doctorSpecialty;
  final String patientId;
  final String patientName;
  final DateTime lastUpdated;
  final List<ChatMessage> messages;
  final Map<String, bool> typing;
  final List<ChatReport> reports;

  ChatRoom({
    required this.id,
    required this.doctorId,
    required this.doctorName,
    required this.doctorSpecialty,
    required this.patientId,
    required this.patientName,
    required this.lastUpdated,
    required this.messages,
    required this.typing,
    required this.reports,
  });
}

class ChatMessage {
  final String id;
  final String text;
  final String senderId;
  final DateTime timestamp;
  final bool read;

  ChatMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.timestamp,
    required this.read,
  });
}

class ChatReport {
  final String id;
  final String messageId;
  final String reportedBy;
  final String reportedById;
  final String reason;
  final String description;
  final DateTime timestamp;
  final String status; // pending, resolved, dismissed
  final String? resolvedBy;
  final DateTime? resolvedAt;

  ChatReport({
    required this.id,
    required this.messageId,
    required this.reportedBy,
    required this.reportedById,
    required this.reason,
    required this.description,
    required this.timestamp,
    required this.status,
    this.resolvedBy,
    this.resolvedAt,
  });
}

// Reports Overview Dialog
class ReportsOverviewDialog extends StatefulWidget {
  final ChatRoom chatRoom;
  final VoidCallback? onReportsUpdated;

  const ReportsOverviewDialog({
    super.key,
    required this.chatRoom,
    this.onReportsUpdated,
  });

  @override
  State<ReportsOverviewDialog> createState() => _ReportsOverviewDialogState();
}

class _ReportsOverviewDialogState extends State<ReportsOverviewDialog> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.flag, color: Colors.red),
                const SizedBox(width: 8),
                const Text(
                  'Reported Chat Overview',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Chat between ${widget.chatRoom.patientName} and Dr. ${widget.chatRoom.doctorName}',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            const Text(
              'Reports Summary:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildReportsSummary(),
            const SizedBox(height: 24),
            const Text(
              'All Reports:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.chatRoom.reports.length,
                itemBuilder: (context, index) {
                  return _buildReportCard(widget.chatRoom.reports[index]);
                },
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context); // Close current dialog
                      _openChatPopup(widget.chatRoom, context);
                    },
                    child: const Text('View Chat'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () {
                      _showActionMenu(context);
                    },
                    child: const Text(
                      'Take Action',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsSummary() {
    final pending =
        widget.chatRoom.reports.where((r) => r.status == 'pending').length;
    final resolved =
        widget.chatRoom.reports.where((r) => r.status == 'resolved').length;
    final dismissed =
        widget.chatRoom.reports.where((r) => r.status == 'dismissed').length;

    return Row(
      children: [
        _buildSummaryItem(
          'Total',
          widget.chatRoom.reports.length.toString(),
          Colors.grey,
        ),
        _buildSummaryItem('Pending', pending.toString(), Colors.orange),
        _buildSummaryItem('Resolved', resolved.toString(), Colors.green),
        _buildSummaryItem('Dismissed', dismissed.toString(), Colors.blue),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(ChatReport report) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(report.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    report.status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('MMM dd, yyyy').format(report.timestamp),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Reported by: ${report.reportedBy}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              'Reason: ${report.reason}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            if (report.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Description: ${report.description}'),
            ],
            if (report.resolvedBy != null) ...[
              const SizedBox(height: 4),
              Text(
                'Resolved by: ${report.resolvedBy}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
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

  void _showActionMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: const Text('Mark as Resolved'),
                  subtitle: const Text('Close all reports for this chat'),
                  onTap: () {
                    Navigator.pop(context);
                    _resolveAllReports(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.close, color: Colors.blue),
                  title: const Text('Dismiss Reports'),
                  subtitle: const Text('Mark all reports as dismissed'),
                  onTap: () {
                    Navigator.pop(context);
                    _dismissAllReports(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.warning, color: Colors.orange),
                  title: const Text('Warn Participants'),
                  subtitle: const Text(
                    'Send warning to both doctor and patient',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _warnParticipants(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.block, color: Colors.red),
                  title: const Text('Suspend Chat'),
                  subtitle: const Text('Temporarily disable this chat'),
                  onTap: () {
                    Navigator.pop(context);
                    _suspendChat(context);
                  },
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _resolveAllReports(BuildContext context) async {
    final result = await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Resolve All Reports'),
            content: const Text(
              'Are you sure you want to mark all reports for this chat as resolved?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Resolve All'),
              ),
            ],
          ),
    );

    if (result == true) {
      try {
        // Update all reports status to resolved
        for (final report in widget.chatRoom.reports) {
          await _databaseRef
              .child('chats/${widget.chatRoom.id}/reports/${report.id}')
              .update({
                'status': 'resolved',
                'resolvedBy': 'Admin',
                'resolvedAt': DateTime.now().millisecondsSinceEpoch,
              });
        }

        if (mounted) {
          Navigator.pop(context); // Close reports overview
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All reports marked as resolved'),
              backgroundColor: Colors.green,
            ),
          );
          widget.onReportsUpdated?.call();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error resolving reports: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _dismissAllReports(BuildContext context) async {
    final result = await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Dismiss All Reports'),
            content: const Text(
              'Are you sure you want to dismiss all reports for this chat?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Dismiss All'),
              ),
            ],
          ),
    );

    if (result == true) {
      try {
        // Update all reports status to dismissed
        for (final report in widget.chatRoom.reports) {
          await _databaseRef
              .child('chats/${widget.chatRoom.id}/reports/${report.id}')
              .update({
                'status': 'dismissed',
                'resolvedBy': 'Admin',
                'resolvedAt': DateTime.now().millisecondsSinceEpoch,
              });
        }

        if (mounted) {
          Navigator.pop(context); // Close reports overview
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All reports dismissed'),
              backgroundColor: Colors.blue,
            ),
          );
          widget.onReportsUpdated?.call();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error dismissing reports: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _warnParticipants(BuildContext context) async {
    final messageController = TextEditingController();

    final result = await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Warn Participants'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Send a warning message to both doctor and patient:',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: messageController,
                  decoration: const InputDecoration(
                    hintText: 'Enter warning message...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, messageController.text),
                child: const Text('Send Warning'),
              ),
            ],
          ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        // Create a warning message in the chat
        final warningMessage = {
          'text': '⚠️ ADMIN WARNING: $result',
          'senderId': 'admin',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'read': false,
          'type': 'admin_warning',
        };

        final newMessageRef =
            _databaseRef.child('chats/${widget.chatRoom.id}/messages').push();
        await newMessageRef.set(warningMessage);

        // Update last updated timestamp
        await _databaseRef
            .child('chats/${widget.chatRoom.id}/meta/lastUpdated')
            .set(DateTime.now().millisecondsSinceEpoch);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Warning sent to participants'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error sending warning: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _suspendChat(BuildContext context) async {
    final result = await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Suspend Chat'),
            content: const Text(
              'Are you sure you want to temporarily suspend this chat? '
              'Participants will not be able to send messages until the chat is restored.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Suspend Chat'),
              ),
            ],
          ),
    );

    if (result == true) {
      try {
        // Add suspension flag to chat meta
        await _databaseRef.child('chats/${widget.chatRoom.id}/meta').update({
          'suspended': true,
          'suspendedAt': DateTime.now().millisecondsSinceEpoch,
          'suspendedBy': 'Admin',
        });

        // Create suspension notification
        final suspensionMessage = {
          'text':
              '🚫 CHAT SUSPENDED: This chat has been temporarily suspended by admin for review.',
          'senderId': 'admin',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'read': false,
          'type': 'suspension_notice',
        };

        final newMessageRef =
            _databaseRef.child('chats/${widget.chatRoom.id}/messages').push();
        await newMessageRef.set(suspensionMessage);

        if (mounted) {
          Navigator.pop(context); // Close reports overview
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Chat suspended successfully'),
              backgroundColor: Colors.red,
            ),
          );
          widget.onReportsUpdated?.call();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error suspending chat: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

void _openChatPopup(ChatRoom chatRoom, BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => ChatPopupScreen(chatRoom: chatRoom),
  );
}
