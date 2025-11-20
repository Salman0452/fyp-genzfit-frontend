import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType {
  text,
  image,
  video,
  file,
}

class MessageModel {
  final String id;
  final String senderId;
  final String? text;
  final String? imageUrl;
  final String? videoUrl;
  final String? fileUrl;
  final String? fileName;
  final MessageType type;
  final DateTime timestamp;
  final bool isRead;

  MessageModel({
    required this.id,
    required this.senderId,
    this.text,
    this.imageUrl,
    this.videoUrl,
    this.fileUrl,
    this.fileName,
    required this.type,
    required this.timestamp,
    this.isRead = false,
  });

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      text: data['text'],
      imageUrl: data['imageUrl'],
      videoUrl: data['videoUrl'],
      fileUrl: data['fileUrl'],
      fileName: data['fileName'],
      type: _getMessageType(data),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
    );
  }

  static MessageType _getMessageType(Map<String, dynamic> data) {
    if (data['imageUrl'] != null) return MessageType.image;
    if (data['videoUrl'] != null) return MessageType.video;
    if (data['fileUrl'] != null) return MessageType.file;
    return MessageType.text;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'text': text,
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
    };
  }

  MessageModel copyWith({
    String? id,
    String? senderId,
    String? text,
    String? imageUrl,
    String? videoUrl,
    String? fileUrl,
    String? fileName,
    MessageType? type,
    DateTime? timestamp,
    bool? isRead,
  }) {
    return MessageModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
    );
  }
}
