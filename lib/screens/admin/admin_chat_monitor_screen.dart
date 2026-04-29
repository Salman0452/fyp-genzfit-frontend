import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:genzfit/utils/constants.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminChatMonitorScreen extends StatelessWidget {
  const AdminChatMonitorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? const Color(0xFFFFFFFF) : AppColors.textPrimary;
    final secondaryText =
        isDark ? const Color(0xFFB0B0B0) : AppColors.textSecondary;
    final cardBackground = isDark ? const Color(0xFF1A1A1A) : AppColors.surface;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cardBackground,
        elevation: 0,
        title: Text(
          'Chat Monitor',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: primaryText,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .orderBy('lastMessageTime', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Failed to load chats: ${snapshot.error}',
                style: GoogleFonts.inter(color: Colors.red),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'No chats found.',
                style: GoogleFonts.inter(color: secondaryText),
              ),
            );
          }

          final chats = snapshot.data!.docs;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: chats.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = chats[index];
              final data = doc.data() as Map<String, dynamic>;
              final participants = data['participants'] is List
                  ? List<String>.from(data['participants'] as List)
                  : const <String>[];
              final participantNames = data['participantNames'] is Map
                  ? Map<String, String>.from(data['participantNames'] as Map)
                  : <String, String>{};
              final lastMessage = data['lastMessage'] is Map
                  ? Map<String, dynamic>.from(data['lastMessage'] as Map)
                  : <String, dynamic>{};

              final participantsLabel = participants
                  .map((uid) => _resolveName(uid, participantNames))
                  .join('  <->  ');
              final lastMessageText = _lastMessagePreview(lastMessage);
              final lastAt = (data['lastMessageTime'] as Timestamp?)?.toDate();

              return Material(
                color: cardBackground,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AdminChatThreadScreen(
                          chatId: doc.id,
                          participants: participants,
                          participantNames: participantNames,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: secondaryText.withOpacity(0.22)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                participantsLabel.isEmpty
                                    ? '(Unknown participants)'
                                    : participantsLabel,
                                style: GoogleFonts.poppins(
                                  color: primaryText,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (lastAt != null)
                              Text(
                                _formatDate(lastAt),
                                style: GoogleFonts.inter(
                                  color: secondaryText,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          lastMessageText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: secondaryText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Chat ID: ${doc.id}',
                          style: GoogleFonts.inter(
                            color: secondaryText,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _resolveName(String uid, Map<String, String> names) {
    final name = names[uid]?.trim() ?? '';
    if (name.isNotEmpty) {
      return name;
    }
    if (uid.length <= 8) {
      return uid;
    }
    return 'User ${uid.substring(0, 8)}';
  }

  String _lastMessagePreview(Map<String, dynamic> lastMessage) {
    if (lastMessage.isEmpty) return 'No messages yet';
    final text = (lastMessage['text'] as String?)?.trim();
    if (text != null && text.isNotEmpty) return text;
    if (lastMessage['imageUrl'] != null) return '[Image]';
    if (lastMessage['videoUrl'] != null) return '[Video]';
    if (lastMessage['fileUrl'] != null) return '[File]';
    return 'Message';
  }

  String _formatDate(DateTime dateTime) {
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    int hour = dateTime.hour;
    final period = hour >= 12 ? 'PM' : 'AM';
    int hour12 = hour % 12;
    if (hour12 == 0) hour12 = 12;
    final hourStr = hour12.toString().padLeft(2, '0');
    return '$month/$day $hourStr:$minute $period';
  }
}

class AdminChatThreadScreen extends StatelessWidget {
  final String chatId;
  final List<String> participants;
  final Map<String, String> participantNames;

  const AdminChatThreadScreen({
    super.key,
    required this.chatId,
    required this.participants,
    required this.participantNames,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? const Color(0xFFFFFFFF) : AppColors.textPrimary;
    final secondaryText =
        isDark ? const Color(0xFFB0B0B0) : AppColors.textSecondary;
    final cardBackground = isDark ? const Color(0xFF1A1A1A) : AppColors.surface;

    final title = participants.map((uid) => _resolveName(uid)).join('  <->  ');

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cardBackground,
        elevation: 0,
        title: Text(
          title.isEmpty ? 'Chat Thread' : title,
          style: GoogleFonts.poppins(
            color: primaryText,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: Text(
              'Read-only admin view',
              style: GoogleFonts.inter(
                color: secondaryText,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Failed to load messages: ${snapshot.error}',
                      style: GoogleFonts.inter(color: Colors.red),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages found.',
                      style: GoogleFonts.inter(color: secondaryText),
                    ),
                  );
                }

                final docs = snapshot.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final senderId = (data['senderId'] as String?) ?? '';
                    final senderName = _resolveName(senderId);
                    final messageText = (data['text'] as String?)?.trim();
                    final imageUrl = (data['imageUrl'] as String?)?.trim();
                    final videoUrl = (data['videoUrl'] as String?)?.trim();
                    final fileUrl = (data['fileUrl'] as String?)?.trim();
                    final fileName = (data['fileName'] as String?)?.trim();
                    final timestamp =
                        (data['timestamp'] as Timestamp?)?.toDate();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cardBackground,
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: secondaryText.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  senderName,
                                  style: GoogleFonts.poppins(
                                    color: primaryText,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              if (timestamp != null)
                                Text(
                                  _formatDate(timestamp),
                                  style: GoogleFonts.inter(
                                    color: secondaryText,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                          if (messageText != null &&
                              messageText.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              messageText,
                              style: GoogleFonts.inter(color: primaryText),
                            ),
                          ],
                          if (imageUrl != null && imageUrl.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                                errorBuilder: (_, __, ___) => Text(
                                  'Image: $imageUrl',
                                  style: GoogleFonts.inter(
                                    color: secondaryText,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (videoUrl != null && videoUrl.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Video: $videoUrl',
                              style: GoogleFonts.inter(
                                color: secondaryText,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          if (fileUrl != null && fileUrl.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'File: ${fileName?.isNotEmpty == true ? fileName : fileUrl}',
                              style: GoogleFonts.inter(
                                color: secondaryText,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _resolveName(String uid) {
    final name = participantNames[uid]?.trim() ?? '';
    if (name.isNotEmpty) {
      return name;
    }
    if (uid == 'system') {
      return 'System';
    }
    if (uid.length <= 8) {
      return uid;
    }
    return 'User ${uid.substring(0, 8)}';
  }

  String _formatDate(DateTime dateTime) {
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    int hour = dateTime.hour;
    final period = hour >= 12 ? 'PM' : 'AM';
    int hour12 = hour % 12;
    if (hour12 == 0) hour12 = 12;
    final hourStr = hour12.toString().padLeft(2, '0');
    return '$month/$day $hourStr:$minute $period';
  }
}
