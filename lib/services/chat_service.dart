import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  // Create or get existing chat between two users
  Future<String> createOrGetChat(
    String currentUserId,
    String otherUserId,
    UserModel currentUser,
    UserModel otherUser,
  ) async {
    // Check if chat already exists
    final existingChats = await _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .get();

    for (var doc in existingChats.docs) {
      final chat = ChatModel.fromFirestore(doc);
      if (chat.participants.contains(otherUserId)) {
        return doc.id;
      }
    }

    // Create new chat
    final chatData = {
      'participants': [currentUserId, otherUserId],
      'lastMessage': null,
      'lastMessageTime': null,
      'unreadCount': {
        currentUserId: 0,
        otherUserId: 0,
      },
      'participantNames': {
        currentUserId: currentUser.name,
        otherUserId: otherUser.name,
      },
      'participantAvatars': {
        currentUserId: currentUser.avatarUrl ?? '',
        otherUserId: otherUser.avatarUrl ?? '',
      },
    };

    final chatDoc = await _firestore.collection('chats').add(chatData);
    return chatDoc.id;
  }

  // Get all chats for a user
  Stream<List<ChatModel>> getUserChats(String userId) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ChatModel.fromFirestore(doc)).toList();
    });
  }

  // Get messages for a chat
  Stream<List<MessageModel>> getChatMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MessageModel.fromFirestore(doc))
          .toList();
    });
  }

  // Send text message
  Future<void> sendTextMessage({
    required String chatId,
    required String senderId,
    required String text,
    required String otherUserId,
  }) async {
    final message = MessageModel(
      id: _uuid.v4(),
      senderId: senderId,
      text: text,
      type: MessageType.text,
      timestamp: DateTime.now(),
    );

    await _sendMessage(chatId, message, otherUserId);
  }

  // Send image message
  Future<void> sendImageMessage({
    required String chatId,
    required String senderId,
    required File imageFile,
    required String otherUserId,
    String? caption,
  }) async {
    final imageUrl = await _uploadFile(
      file: imageFile,
      path: 'chats/$chatId/images',
    );

    final message = MessageModel(
      id: _uuid.v4(),
      senderId: senderId,
      imageUrl: imageUrl,
      text: caption,
      type: MessageType.image,
      timestamp: DateTime.now(),
    );

    await _sendMessage(chatId, message, otherUserId);
  }

  // Send video message
  Future<void> sendVideoMessage({
    required String chatId,
    required String senderId,
    required File videoFile,
    required String otherUserId,
    String? caption,
  }) async {
    final videoUrl = await _uploadFile(
      file: videoFile,
      path: 'chats/$chatId/videos',
    );

    final message = MessageModel(
      id: _uuid.v4(),
      senderId: senderId,
      videoUrl: videoUrl,
      text: caption,
      type: MessageType.video,
      timestamp: DateTime.now(),
    );

    await _sendMessage(chatId, message, otherUserId);
  }

  // Send file message
  Future<void> sendFileMessage({
    required String chatId,
    required String senderId,
    required File file,
    required String fileName,
    required String otherUserId,
  }) async {
    final fileUrl = await _uploadFile(
      file: file,
      path: 'chats/$chatId/files',
      fileName: fileName,
    );

    final message = MessageModel(
      id: _uuid.v4(),
      senderId: senderId,
      fileUrl: fileUrl,
      fileName: fileName,
      type: MessageType.file,
      timestamp: DateTime.now(),
    );

    await _sendMessage(chatId, message, otherUserId);
  }

  // Private method to send message
  Future<void> _sendMessage(
    String chatId,
    MessageModel message,
    String otherUserId,
  ) async {
    // Add message to subcollection
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(message.id)
        .set(message.toFirestore());

    // Update chat document
    final chatRef = _firestore.collection('chats').doc(chatId);
    final chatDoc = await chatRef.get();
    final chat = ChatModel.fromFirestore(chatDoc);

    final unreadCount = Map<String, int>.from(chat.unreadCount);
    unreadCount[otherUserId] = (unreadCount[otherUserId] ?? 0) + 1;

    await chatRef.update({
      'lastMessage': {
        'text': message.text ?? '',
        'senderId': message.senderId,
        'type': message.type.toString().split('.').last,
      },
      'lastMessageTime': Timestamp.fromDate(message.timestamp),
      'unreadCount': unreadCount,
    });
  }

  // Upload file to Firebase Storage
  Future<String> _uploadFile({
    required File file,
    required String path,
    String? fileName,
  }) async {
    final name = fileName ?? '${_uuid.v4()}.${file.path.split('.').last}';
    final ref = _storage.ref().child('$path/$name');
    final uploadTask = await ref.putFile(file);
    return await uploadTask.ref.getDownloadURL();
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String chatId, String userId) async {
    final chatRef = _firestore.collection('chats').doc(chatId);
    final chatDoc = await chatRef.get();
    final chat = ChatModel.fromFirestore(chatDoc);

    // Reset unread count for current user
    final unreadCount = Map<String, int>.from(chat.unreadCount);
    unreadCount[userId] = 0;

    await chatRef.update({
      'unreadCount': unreadCount,
    });

    // Mark all unread messages as read
    final messagesSnapshot = await chatRef
        .collection('messages')
        .where('senderId', isNotEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (var doc in messagesSnapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // Delete message
  Future<void> deleteMessage(String chatId, String messageId) async {
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  // Get total unread messages count for user
  Future<int> getTotalUnreadCount(String userId) async {
    final chatsSnapshot = await _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .get();

    int totalUnread = 0;
    for (var doc in chatsSnapshot.docs) {
      final chat = ChatModel.fromFirestore(doc);
      totalUnread += chat.getUnreadCountForUser(userId);
    }

    return totalUnread;
  }
}
