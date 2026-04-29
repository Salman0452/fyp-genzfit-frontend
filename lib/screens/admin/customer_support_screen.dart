import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:genzfit/models/message_model.dart';
import 'package:genzfit/models/user_model.dart';
import 'package:genzfit/utils/constants.dart';
import 'package:genzfit/widgets/loading_widget.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class CustomerSupportScreen extends StatefulWidget {
  const CustomerSupportScreen({super.key});

  @override
  State<CustomerSupportScreen> createState() => _CustomerSupportScreenState();
}

class _CustomerSupportScreenState extends State<CustomerSupportScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String get _activeCategory =>
      _tabController.index == 0 ? 'trainer' : 'client';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? const Color(0xFFFFFFFF) : AppColors.textPrimary;
    final secondaryText =
        isDark ? const Color(0xFFB0B0B0) : AppColors.textSecondary;
    final cardBackground = isDark ? const Color(0xFF1A1A1A) : AppColors.surface;
    final brandGreen = isDark ? AppColors.brandGreen : AppColors.brandGreenDeep;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cardBackground,
        elevation: 0,
        title: Text(
          'Customer Support',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: primaryText,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: brandGreen,
          labelColor: brandGreen,
          unselectedLabelColor: secondaryText,
          tabs: const [
            Tab(text: 'Trainer'),
            Tab(text: 'Client'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: brandGreen,
        onPressed: () => _showCreateThreadPicker(_activeCategory),
        icon: const Icon(Icons.add_comment_outlined),
        label: Text(
          'New ${_activeCategory == 'trainer' ? 'Trainer' : 'Client'} Ticket',
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _SupportThreadsList(category: 'trainer'),
          _SupportThreadsList(category: 'client'),
        ],
      ),
    );
  }

  Future<void> _showCreateThreadPicker(String category) async {
    final users = await _loadUsersByRole(category);
    if (!mounted) return;

    String query = '';
    final filteredUsers = <UserModel>[];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF111111)
          : AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        void refreshMatches(StateSetter setModalState) {
          filteredUsers
            ..clear()
            ..addAll(
              users.where((user) {
                final name = user.name.toLowerCase();
                final email = user.email.toLowerCase();
                final needle = query.toLowerCase();
                return needle.isEmpty ||
                    name.contains(needle) ||
                    email.contains(needle);
              }),
            );
        }

        return StatefulBuilder(
          builder: (context, setModalState) {
            refreshMatches(setModalState);
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final primaryText =
                isDark ? const Color(0xFFFFFFFF) : AppColors.textPrimary;
            final secondaryText =
                isDark ? const Color(0xFFB0B0B0) : AppColors.textSecondary;

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Start ${category == 'trainer' ? 'Trainer' : 'Client'} Support',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      query = value;
                      setModalState(() {});
                    },
                    decoration: InputDecoration(
                      hintText: 'Search by name or email',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF1A1A1A)
                          : const Color(0xFFF4F4F4),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.55,
                    ),
                    child: filteredUsers.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Text(
                                'No ${category}s found',
                                style: GoogleFonts.inter(color: secondaryText),
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: filteredUsers.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final user = filteredUsers[index];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(
                                    color: secondaryText.withOpacity(0.2),
                                  ),
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.brandGreenDeep
                                      .withOpacity(0.15),
                                  backgroundImage: (user.avatarUrl != null &&
                                          user.avatarUrl!.isNotEmpty)
                                      ? CachedNetworkImageProvider(
                                          user.avatarUrl!,
                                        )
                                      : null,
                                  child: (user.avatarUrl == null ||
                                          user.avatarUrl!.isEmpty)
                                      ? Text(
                                          user.name.isNotEmpty
                                              ? user.name[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : null,
                                ),
                                title: Text(
                                  user.name,
                                  style: GoogleFonts.poppins(
                                    color: primaryText,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  user.email,
                                  style: GoogleFonts.inter(
                                    color: secondaryText,
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () async {
                                  Navigator.pop(context);
                                  final threadId = await _getOrCreateThread(
                                    user: user,
                                    category: category,
                                  );
                                  if (!mounted) return;
                                  Navigator.of(this.context).push(
                                    MaterialPageRoute(
                                      builder: (_) => SupportConversationScreen(
                                        threadId: threadId,
                                        category: category,
                                        threadTitle: user.name,
                                        threadAvatarUrl: user.avatarUrl,
                                        ownerId: user.id,
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
            );
          },
        );
      },
    );

    _searchController.clear();
  }

  Future<List<UserModel>> _loadUsersByRole(String role) async {
    final snapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: role)
        .get();

    final users = snapshot.docs
        .map((doc) => UserModel.fromFirestore(doc))
        .where((user) => user.isActive)
        .toList();

    users.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return users;
  }

  Future<String> _getOrCreateThread({
    required UserModel user,
    required String category,
  }) async {
    final existing = await _firestore
        .collection('support_threads')
        .where('ownerId', isEqualTo: user.id)
        .where('category', isEqualTo: category)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return existing.docs.first.id;
    }

    final adminId = _auth.currentUser?.uid ?? '';
    final docRef = _firestore.collection('support_threads').doc();
    await docRef.set({
      'ownerId': user.id,
      'ownerName': user.name,
      'ownerAvatarUrl': user.avatarUrl ?? '',
      'category': category,
      'status': 'open',
      'createdByAdminId': adminId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessage': null,
      'lastMessageTime': null,
      'unreadByAdmin': 0,
      'unreadByUser': 0,
    });

    return docRef.id;
  }
}

class _SupportThreadsList extends StatelessWidget {
  final String category;

  const _SupportThreadsList({required this.category});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? const Color(0xFFFFFFFF) : AppColors.textPrimary;
    final secondaryText =
        isDark ? const Color(0xFFB0B0B0) : AppColors.textSecondary;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('support_threads').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: LoadingWidget());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Failed to load support threads: ${snapshot.error}',
              style: GoogleFonts.inter(color: Colors.red),
            ),
          );
        }

        final threads = snapshot.data?.docs
                .map(_SupportThreadSummary.fromDoc)
                .where((thread) => thread.category == category)
                .toList() ??
            [];
        threads.sort((a, b) {
          final aTime =
              a.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime =
              b.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });

        if (threads.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.support_agent,
                  size: 72,
                  color: secondaryText.withOpacity(0.8),
                ),
                const SizedBox(height: 16),
                Text(
                  'No ${category == 'trainer' ? 'trainer' : 'client'} support threads',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start a ticket to resolve issues with ${category == 'trainer' ? 'trainers' : 'clients'}.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: secondaryText),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: threads.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final thread = threads[index];
            return _SupportThreadTile(thread: thread);
          },
        );
      },
    );
  }
}

class _SupportThreadTile extends StatelessWidget {
  final _SupportThreadSummary thread;

  const _SupportThreadTile({required this.thread});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? const Color(0xFFFFFFFF) : AppColors.textPrimary;
    final secondaryText =
        isDark ? const Color(0xFFB0B0B0) : AppColors.textSecondary;
    final cardBackground = isDark ? const Color(0xFF1A1A1A) : AppColors.surface;
    final chipColor = thread.status == 'resolved'
        ? (isDark ? const Color(0xFF66BB6A) : const Color(0xFF2E7D32))
        : (isDark ? const Color(0xFFFFB74D) : const Color(0xFFEF6C00));

    return Material(
      color: cardBackground,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SupportConversationScreen(
                threadId: thread.id,
                category: thread.category,
                threadTitle: thread.ownerName,
                threadAvatarUrl: thread.ownerAvatarUrl,
                ownerId: thread.ownerId,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: secondaryText.withOpacity(0.18)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.brandGreenDeep.withOpacity(0.15),
                backgroundImage: thread.ownerAvatarUrl.isNotEmpty
                    ? CachedNetworkImageProvider(thread.ownerAvatarUrl)
                    : null,
                child: thread.ownerAvatarUrl.isEmpty
                    ? Text(
                        thread.ownerName.isNotEmpty
                            ? thread.ownerName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            thread.ownerName,
                            style: GoogleFonts.poppins(
                              color: primaryText,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: chipColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            thread.status.toUpperCase(),
                            style: GoogleFonts.inter(
                              color: chipColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      thread.lastMessagePreview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(color: secondaryText),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      thread.lastMessageTime != null
                          ? DateFormat('MMM d, hh:mm a')
                              .format(thread.lastMessageTime!)
                          : 'No messages yet',
                      style: GoogleFonts.inter(
                        color: secondaryText,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (thread.unreadByAdmin > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${thread.unreadByAdmin}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class SupportConversationScreen extends StatefulWidget {
  final String threadId;
  final String category;
  final String threadTitle;
  final String? threadAvatarUrl;
  final String ownerId;

  const SupportConversationScreen({
    super.key,
    required this.threadId,
    required this.category,
    required this.threadTitle,
    required this.ownerId,
    this.threadAvatarUrl,
  });

  @override
  State<SupportConversationScreen> createState() =>
      _SupportConversationScreenState();
}

class _SupportConversationScreenState extends State<SupportConversationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final UuidGenerator _uuid = const UuidGenerator();

  Uint8List? _attachmentBytes;
  String? _attachmentName;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markThreadRead();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markThreadRead() async {
    try {
      await _firestore
          .collection('support_threads')
          .doc(widget.threadId)
          .update({
        'unreadByAdmin': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Ignore; not critical for UX.
    }
  }

  Future<void> _toggleResolution(String status) async {
    await _firestore.collection('support_threads').doc(widget.threadId).update({
      'status': status,
      'resolvedAt': status == 'resolved' ? FieldValue.serverTimestamp() : null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
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

  Future<String> _uploadAttachment({
    required Uint8List bytes,
    required String name,
    required String folder,
  }) async {
    final storageRef = _storage.ref().child(
        'support_threads/${widget.threadId}/$folder/${_uuid.v4()}_$name');
    final metadata = SettableMetadata(
      contentType: _inferContentType(name, folder == 'images'),
    );
    await storageRef.putData(bytes, metadata);
    return storageRef.getDownloadURL();
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

  Future<void> _sendCurrentMessage() async {
    if (_isSending) return;
    final text = _messageController.text.trim();
    if (text.isEmpty && _attachmentBytes == null) return;

    setState(() => _isSending = true);

    try {
      final adminId = _auth.currentUser?.uid ?? '';
      final messagesRef = _firestore
          .collection('support_threads')
          .doc(widget.threadId)
          .collection('messages');
      final messageId = messagesRef.doc().id;

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

      await messagesRef.doc(messageId).set({
        'senderId': adminId,
        'senderRole': 'admin',
        'text': text.isEmpty ? null : text,
        'imageUrl': imageUrl,
        'videoUrl': null,
        'fileUrl': fileUrl,
        'fileName': fileName,
        'type': type,
        'timestamp': Timestamp.now(),
        'isRead': false,
      });

      await _firestore
          .collection('support_threads')
          .doc(widget.threadId)
          .update({
        'status': 'open',
        'lastMessage': {
          'text': text.isNotEmpty
              ? text
              : (imageUrl != null
                  ? '[Image]'
                  : fileUrl != null
                      ? '[File]'
                      : ''),
          'senderId': adminId,
          'type': type,
        },
        'lastMessageTime': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'unreadByUser': FieldValue.increment(1),
        'unreadByAdmin': 0,
      });

      _messageController.clear();
      setState(() {
        _attachmentBytes = null;
        _attachmentName = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? const Color(0xFFFFFFFF) : AppColors.textPrimary;
    final secondaryText =
        isDark ? const Color(0xFFB0B0B0) : AppColors.textSecondary;
    final cardBackground = isDark ? const Color(0xFF1A1A1A) : AppColors.surface;
    final brandGreen = isDark ? AppColors.brandGreen : AppColors.brandGreenDeep;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cardBackground,
        elevation: 0,
        title: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _firestore
              .collection('support_threads')
              .doc(widget.threadId)
              .snapshots(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data();
            final status = (data?['status'] as String?) ?? 'open';
            final title = widget.threadTitle;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: primaryText,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${widget.category == 'trainer' ? 'Trainer' : 'Client'} • ${status.toUpperCase()}',
                  style: GoogleFonts.inter(
                    color: secondaryText,
                    fontSize: 11,
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Mark resolved',
            icon: Icon(Icons.check_circle_outline, color: brandGreen),
            onPressed: () => _toggleResolution('resolved'),
          ),
          IconButton(
            tooltip: 'Reopen',
            icon: Icon(Icons.refresh, color: secondaryText),
            onPressed: () => _toggleResolution('open'),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildThreadHeader(primaryText, secondaryText),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestore
                  .collection('support_threads')
                  .doc(widget.threadId)
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
                      'Failed to load support messages: ${snapshot.error}',
                      style: GoogleFonts.inter(color: Colors.red),
                    ),
                  );
                }

                final messages = snapshot.data?.docs ?? [];
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet',
                      style: GoogleFonts.inter(color: secondaryText),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = MessageModel.fromFirestore(messages[index]);
                    final senderId = message.senderId;
                    final isAdmin = senderId == (_auth.currentUser?.uid ?? '');
                    return _SupportMessageBubble(
                      message: message,
                      isAdmin: isAdmin,
                    );
                  },
                );
              },
            ),
          ),
          _buildComposer(cardBackground, secondaryText),
        ],
      ),
    );
  }

  Widget _buildThreadHeader(Color primaryText, Color secondaryText) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBackground = isDark ? const Color(0xFF1A1A1A) : AppColors.surface;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBackground,
        border: Border(
          bottom: BorderSide(color: secondaryText.withOpacity(0.15)),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.brandGreenDeep.withOpacity(0.15),
            backgroundImage: widget.threadAvatarUrl != null &&
                    widget.threadAvatarUrl!.isNotEmpty
                ? CachedNetworkImageProvider(widget.threadAvatarUrl!)
                : null,
            child: widget.threadAvatarUrl == null ||
                    widget.threadAvatarUrl!.isEmpty
                ? Text(
                    widget.threadTitle.isNotEmpty
                        ? widget.threadTitle[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.threadTitle,
                  style: GoogleFonts.poppins(
                    color: primaryText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Use this thread to resolve ${widget.category} issues with text, images, or files.',
                  style: GoogleFonts.inter(
                    color: secondaryText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer(Color cardBackground, Color secondaryText) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? const Color(0xFFFFFFFF) : AppColors.textPrimary;
    final brandGreen = isDark ? AppColors.brandGreen : AppColors.brandGreenDeep;

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
          if (_attachmentBytes != null && _attachmentName != null) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF101010) : const Color(0xFFF4F4F4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.attach_file),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _attachmentName!,
                      style: GoogleFonts.inter(color: primaryText),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _attachmentBytes = null;
                        _attachmentName = null;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
          Row(
            children: [
              IconButton(
                tooltip: 'Attach image',
                onPressed: () => _pickAttachment(imageOnly: true),
                icon: Icon(Icons.image, color: brandGreen),
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
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: 'Type a support response...',
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF101010)
                        : const Color(0xFFF4F4F4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                onPressed: _isSending ? null : _sendCurrentMessage,
                child: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
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

class _SupportMessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isAdmin;

  const _SupportMessageBubble({required this.message, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brandGreen = isDark ? AppColors.brandGreen : AppColors.brandGreenDeep;
    final bubbleColor = isAdmin
        ? brandGreen.withOpacity(0.12)
        : (isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5));
    final textColor = isAdmin
        ? (isDark ? const Color(0xFFFFFFFF) : AppColors.textPrimary)
        : (isDark ? const Color(0xFFFFFFFF) : AppColors.textPrimary);

    return Align(
      alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: brandGreen.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment:
              isAdmin ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (message.text != null && message.text!.trim().isNotEmpty) ...[
              Text(
                message.text!.trim(),
                style: GoogleFonts.inter(color: textColor),
              ),
            ],
            if (message.imageUrl != null && message.imageUrl!.isNotEmpty) ...[
              if (message.text != null && message.text!.trim().isNotEmpty)
                const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  message.imageUrl!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Text(
                    message.imageUrl!,
                    style: GoogleFonts.inter(color: textColor, fontSize: 12),
                  ),
                ),
              ),
            ],
            if (message.fileUrl != null && message.fileUrl!.isNotEmpty) ...[
              if (message.text != null && message.text!.trim().isNotEmpty ||
                  message.imageUrl != null)
                const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.description_outlined, size: 18),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      message.fileName?.isNotEmpty == true
                          ? message.fileName!
                          : 'Attachment',
                      style: GoogleFonts.inter(color: textColor),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 6),
            Text(
              DateFormat('MMM d, hh:mm a').format(message.timestamp),
              style: GoogleFonts.inter(
                color: textColor.withOpacity(0.65),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportThreadSummary {
  final String id;
  final String ownerId;
  final String ownerName;
  final String ownerAvatarUrl;
  final String category;
  final String status;
  final Map<String, dynamic>? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadByAdmin;

  _SupportThreadSummary({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.ownerAvatarUrl,
    required this.category,
    required this.status,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadByAdmin,
  });

  factory _SupportThreadSummary.fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return _SupportThreadSummary(
      id: doc.id,
      ownerId: (data['ownerId'] as String?) ?? '',
      ownerName: (data['ownerName'] as String?) ?? 'Unknown User',
      ownerAvatarUrl: (data['ownerAvatarUrl'] as String?) ?? '',
      category: (data['category'] as String?) ?? 'client',
      status: (data['status'] as String?) ?? 'open',
      lastMessage: data['lastMessage'] as Map<String, dynamic>?,
      lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate(),
      unreadByAdmin: (data['unreadByAdmin'] as num?)?.toInt() ?? 0,
    );
  }

  String get lastMessagePreview {
    final message = lastMessage;
    if (message == null) return 'No messages yet';
    final text = (message['text'] as String?)?.trim();
    if (text != null && text.isNotEmpty) return text;
    final type = (message['type'] as String?) ?? '';
    switch (type) {
      case 'image':
        return '[Image]';
      case 'file':
        return '[File]';
      default:
        return 'Message';
    }
  }
}

class UuidGenerator {
  const UuidGenerator();

  String v4() => FirebaseFirestore.instance.collection('_').doc().id;
}
