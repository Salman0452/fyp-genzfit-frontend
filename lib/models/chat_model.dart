import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String id;
  final List<String> participants;
  final Map<String, dynamic>? lastMessage;
  final DateTime? lastMessageTime;
  final Map<String, int> unreadCount;
  final Map<String, String>? participantNames;
  final Map<String, String>? participantAvatars;

  ChatModel({
    required this.id,
    required this.participants,
    this.lastMessage,
    this.lastMessageTime,
    required this.unreadCount,
    this.participantNames,
    this.participantAvatars,
  });

  factory ChatModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatModel(
      id: doc.id,
      participants: List<String>.from(data['participants'] ?? []),
      lastMessage: data['lastMessage'] as Map<String, dynamic>?,
      lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate(),
      unreadCount: Map<String, int>.from(
        (data['unreadCount'] as Map<String, dynamic>?)?.map(
              (key, value) => MapEntry(key, value as int),
            ) ??
            {},
      ),
      participantNames: data['participantNames'] != null
          ? Map<String, String>.from(data['participantNames'])
          : null,
      participantAvatars: data['participantAvatars'] != null
          ? Map<String, String>.from(data['participantAvatars'])
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime != null
          ? Timestamp.fromDate(lastMessageTime!)
          : null,
      'unreadCount': unreadCount,
      'participantNames': participantNames,
      'participantAvatars': participantAvatars,
    };
  }

  String getOtherParticipantId(String currentUserId) {
    return participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
  }

  String? getOtherParticipantName(String currentUserId) {
    final otherId = getOtherParticipantId(currentUserId);
    return participantNames?[otherId];
  }

  String? getOtherParticipantAvatar(String currentUserId) {
    final otherId = getOtherParticipantId(currentUserId);
    return participantAvatars?[otherId];
  }

  int getUnreadCountForUser(String userId) {
    return unreadCount[userId] ?? 0;
  }
}
