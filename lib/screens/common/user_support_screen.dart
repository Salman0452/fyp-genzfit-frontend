import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:genzfit/utils/constants.dart';
import 'package:genzfit/widgets/loading_widget.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class UserSupportScreen extends StatefulWidget {
  const UserSupportScreen({super.key});

  @override
  State<UserSupportScreen> createState() => _UserSupportScreenState();
}

class _UserSupportScreenState extends State<UserSupportScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _threadId;
  String _category = 'client';
  String _threadStatus = 'open';
  bool _isBootstrapping = true;
  bool _isSending = false;

  Uint8List? _attachmentBytes;
  String? _attachmentName;

  @override
  void initState() {
    super.initState();
    _initSupportThread();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String get _currentUid => _auth.currentUser?.uid ?? '';

  Future<void> _initSupportThread() async {
    try {
      final uid = _currentUid;
      if (uid.isEmpty) {
        if (!mounted) return;
        setState(() => _isBootstrapping = false);
        return;
      }

      final userDoc = await _firestore.collection('users').doc(uid).get();
      final userData = userDoc.data() ?? <String, dynamic>{};
      final role = (userData['role'] as String? ?? 'client').toLowerCase();
      final category = role == 'trainer' ? 'trainer' : 'client';

      final existing = await _firestore
          .collection('support_threads')
          .where('ownerId', isEqualTo: uid)
          .where('category', isEqualTo: category)
          .limit(1)
          .get();

      String resolvedThreadId;
      if (existing.docs.isNotEmpty) {
        resolvedThreadId = existing.docs.first.id;
      } else {
        final docRef = _firestore.collection('support_threads').doc();
        await docRef.set({
          'ownerId': uid,
          'ownerName': (userData['name'] as String?) ?? 'User',
          'ownerAvatarUrl': (userData['avatarUrl'] as String?) ?? '',
          'category': category,
          'status': 'open',
          'createdByAdminId': null,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'lastMessage': null,
          'lastMessageTime': null,
          'unreadByAdmin': 0,
          'unreadByUser': 0,
        });
        resolvedThreadId = docRef.id;
      }

      await _firestore
          .collection('support_threads')
          .doc(resolvedThreadId)
          .update({
        'unreadByUser': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() {
        _category = category;
        _threadId = resolvedThreadId;
        _isBootstrapping = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isBootstrapping = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open support chat: $e')),
      );
    }
  }

  bool _isImageFile(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }

  String _inferContentType(String name, bool isImage) {
    final lower = name.toLowerCase();
    if (isImage) {
      if (lower.endsWith('.png')) return 'image/png';
      if (lower.endsWith('.webp')) return 'image/webp';
      if (lower.endsWith('.gif')) return 'image/gif';
      return 'image/jpeg';
    }
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    return 'application/octet-stream';
  }

  String _newId() => FirebaseFirestore.instance.collection('_').doc().id;

  Future<String> _uploadAttachment({
    required Uint8List bytes,
    required String name,
    required String folder,
  }) async {
    final threadId = _threadId;
    if (threadId == null) throw Exception('Support thread not ready');

    final ref = _storage.ref().child(
          'support_threads/$threadId/$folder/${_newId()}_$name',
        );

    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: _inferContentType(name, folder == 'images'),
      ),
    );

    return ref.getDownloadURL();
  }

  Future<void> _pickAttachment({required bool imageOnly}) async {
    final result = await FilePicker.platform.pickFiles(
      type: imageOnly ? FileType.image : FileType.any,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() {
      _attachmentBytes = file.bytes;
      _attachmentName = file.name;
    });
  }

  Future<void> _sendMessage() async {
    if (_isSending) return;
    final threadId = _threadId;
    if (threadId == null) return;

    final text = _messageController.text.trim();
    if (text.isEmpty && _attachmentBytes == null) return;

    setState(() => _isSending = true);

    try {
      String? imageUrl;
      String? fileUrl;
      String? fileName;
      String type = 'text';

      if (_attachmentBytes != null && _attachmentName != null) {
        final isImage = _isImageFile(_attachmentName!);
        if (isImage) {
          imageUrl = await _uploadAttachment(
            bytes: _attachmentBytes!,
            name: _attachmentName!,
            folder: 'images',
          );
          type = 'image';
        } else {
          fileUrl = await _uploadAttachment(
            bytes: _attachmentBytes!,
            name: _attachmentName!,
            folder: 'files',
          );
          fileName = _attachmentName;
          type = 'file';
        }
      }

      final messageId = _newId();
      final messagesRef = _firestore
          .collection('support_threads')
          .doc(threadId)
          .collection('messages');

      await messagesRef.doc(messageId).set({
        'senderId': _currentUid,
        'senderRole': _category,
        'text': text.isEmpty ? null : text,
        'imageUrl': imageUrl,
        'videoUrl': null,
        'fileUrl': fileUrl,
        'fileName': fileName,
        'type': type,
        'timestamp': Timestamp.now(),
        'isRead': false,
      });

      await _firestore.collection('support_threads').doc(threadId).update({
        'status': 'open',
        'lastMessage': {
          'text': text.isNotEmpty
              ? text
              : (imageUrl != null
                  ? '[Image]'
                  : fileUrl != null
                      ? '[File]'
                      : ''),
          'senderId': _currentUid,
          'type': type,
        },
        'lastMessageTime': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'unreadByAdmin': FieldValue.increment(1),
        'unreadByUser': 0,
      });

      _messageController.clear();
      setState(() {
        _attachmentBytes = null;
        _attachmentName = null;
      });

      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? const Color(0xFFFFFFFF) : AppColors.textPrimary;
    final secondaryText =
        isDark ? const Color(0xFFB0B0B0) : AppColors.textSecondary;
    final cardBackground = isDark ? const Color(0xFF1A1A1A) : AppColors.surface;
    final brandGreen = isDark ? AppColors.brandGreen : AppColors.brandGreenDeep;

    if (_isBootstrapping) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Help & Support'),
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        ),
        body: const Center(child: LoadingWidget()),
      );
    }

    final threadId = _threadId;
    if (threadId == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Help & Support'),
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        ),
        body: Center(
          child: Text(
            'Unable to open support conversation. Please try again.',
            style: TextStyle(color: secondaryText),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _firestore
                .collection('support_threads')
                .doc(threadId)
                .snapshots(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data();
              _threadStatus = (data?['status'] as String?) ?? 'open';

              final statusColor = _threadStatus == 'resolved'
                  ? (isDark ? const Color(0xFF66BB6A) : const Color(0xFF2E7D32))
                  : (isDark
                      ? const Color(0xFFFFB74D)
                      : const Color(0xFFEF6C00));

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                color: cardBackground,
                child: Row(
                  children: [
                    Icon(Icons.support_agent, color: brandGreen),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _threadStatus == 'resolved'
                            ? 'Ticket resolved. You can still send a message to reopen it.'
                            : 'Chat directly with admin support.',
                        style: TextStyle(
                          color: secondaryText,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _threadStatus.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestore
                  .collection('support_threads')
                  .doc(threadId)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: LoadingWidget());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Failed to load messages: ${snapshot.error}',
                      style: TextStyle(color: Colors.red.shade400),
                    ),
                  );
                }

                final messages = snapshot.data?.docs ?? [];
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'Start by sending your issue to admin support.',
                      style: TextStyle(color: secondaryText),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data();
                    final senderId = (data['senderId'] as String?) ?? '';
                    final isMe = senderId == _currentUid;
                    return _UserSupportMessageBubble(
                      data: data,
                      isMe: isMe,
                    );
                  },
                );
              },
            ),
          ),
          _buildComposer(
              cardBackground, secondaryText, primaryText, brandGreen),
        ],
      ),
    );
  }

  Widget _buildComposer(
    Color cardBackground,
    Color secondaryText,
    Color primaryText,
    Color brandGreen,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: cardBackground,
        border: Border(top: BorderSide(color: secondaryText.withOpacity(0.15))),
      ),
      padding: EdgeInsets.fromLTRB(
        12,
        12,
        12,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_attachmentBytes != null && _attachmentName != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF101010) : const Color(0xFFF4F4F4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.attach_file, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _attachmentName!,
                      style: GoogleFonts.inter(color: primaryText),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _attachmentBytes = null;
                        _attachmentName = null;
                      });
                    },
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              IconButton(
                tooltip: 'Attach image',
                onPressed: () => _pickAttachment(imageOnly: true),
                icon: Icon(Icons.image_outlined, color: brandGreen),
              ),
              IconButton(
                tooltip: 'Attach file',
                onPressed: () => _pickAttachment(imageOnly: false),
                icon: Icon(Icons.attach_file, color: brandGreen),
              ),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Describe your issue...',
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF101010)
                        : const Color(0xFFF4F4F4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isSending ? null : _sendMessage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                ),
                child: _isSending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UserSupportMessageBubble extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isMe;

  const _UserSupportMessageBubble({required this.data, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? const Color(0xFFFFFFFF) : AppColors.textPrimary;
    final secondaryText =
        isDark ? const Color(0xFFB0B0B0) : AppColors.textSecondary;
    final brandGreen = isDark ? AppColors.brandGreen : AppColors.brandGreenDeep;

    final text = (data['text'] as String?)?.trim();
    final imageUrl = (data['imageUrl'] as String?)?.trim();
    final fileUrl = (data['fileUrl'] as String?)?.trim();
    final fileName = (data['fileName'] as String?)?.trim();
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe
              ? brandGreen.withOpacity(0.15)
              : (isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: brandGreen.withOpacity(0.12)),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (text != null && text.isNotEmpty)
              Text(text, style: TextStyle(color: primaryText)),
            if (imageUrl != null && imageUrl.isNotEmpty) ...[
              if (text != null && text.isNotEmpty) const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const SizedBox(
                    height: 120,
                    child: Center(child: LoadingWidget()),
                  ),
                  errorWidget: (_, __, ___) => Text(
                    imageUrl,
                    style: TextStyle(color: secondaryText, fontSize: 12),
                  ),
                ),
              ),
            ],
            if (fileUrl != null && fileUrl.isNotEmpty) ...[
              if ((text != null && text.isNotEmpty) ||
                  (imageUrl != null && imageUrl.isNotEmpty))
                const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.description_outlined,
                      color: secondaryText, size: 18),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      fileName?.isNotEmpty == true ? fileName! : 'Attachment',
                      style: TextStyle(color: secondaryText),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 6),
            Text(
              timestamp != null
                  ? DateFormat('MMM d, hh:mm a').format(timestamp)
                  : '',
              style: TextStyle(
                color: secondaryText.withOpacity(0.8),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
