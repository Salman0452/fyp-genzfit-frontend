import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:genzfit/utils/constants.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/message_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../shared/loading_widget.dart';

class ChatDetailScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatar;

  const ChatDetailScreen({
    super.key,
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatar,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final ChatService _chatService = ChatService();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _markMessagesAsRead();
  }

  Future<void> _markMessagesAsRead() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.user?.uid ?? '';
    await _chatService.markMessagesAsRead(widget.chatId, currentUserId);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUserId = authProvider.user?.uid ?? '';
    final currentUser = authProvider.currentUser;

    final user = types.User(
      id: currentUserId,
      firstName: currentUser?.name ?? 'You',
      imageUrl: currentUser?.avatarUrl,
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor:
            isDarkMode ? const Color(0xFF1A1A1A) : AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDarkMode ? const Color(0xFFFFFFFF) : AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: (isDarkMode
                          ? AppColors.brandGreen
                          : AppColors.brandGreenDeep)
                      .withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: isDarkMode
                    ? const Color(0xFF2A2A2A)
                    : const Color(0xFFE0E0E0),
                backgroundImage: widget.otherUserAvatar != null &&
                        widget.otherUserAvatar!.isNotEmpty
                    ? CachedNetworkImageProvider(widget.otherUserAvatar!)
                    : null,
                child: widget.otherUserAvatar == null ||
                        widget.otherUserAvatar!.isEmpty
                    ? Text(
                        widget.otherUserName[0].toUpperCase(),
                        style: TextStyle(
                          color: isDarkMode
                              ? const Color(0xFFFFFFFF)
                              : AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName,
                    style: TextStyle(
                      color: isDarkMode
                          ? const Color(0xFFFFFFFF)
                          : AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Active now',
                    style: TextStyle(
                      color: isDarkMode
                          ? const Color(0xFF9F9F9F)
                          : AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          StreamBuilder<List<MessageModel>>(
            stream: _chatService.getChatMessages(widget.chatId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: LoadingWidget());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading messages',
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFB0B0B0)
                          : AppColors.textSecondary,
                    ),
                  ),
                );
              }

              final messages = snapshot.data ?? [];
              final chatMessages = messages
                  .map((msg) => _convertToFlutterChatMessage(msg))
                  .toList();

              return Chat(
                messages: chatMessages,
                onSendPressed: (message) => _handleSendPressed(
                  message,
                  currentUserId,
                ),
                onAttachmentPressed: () =>
                    _handleAttachmentPressed(currentUserId),
                onMessageLongPress: (context, message) =>
                    _handleMessageLongPress(
                  context,
                  message,
                  currentUserId,
                ),
                user: user,
                theme: DarkChatTheme(
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  primaryColor: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.brandGreen
                      : AppColors.brandGreenDeep,
                  secondaryColor:
                      Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF1A1A1A)
                          : AppColors.surface,
                  inputBackgroundColor:
                      Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF1A1A1A)
                          : AppColors.surface,
                  inputTextColor:
                      Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFFFFFFF)
                          : AppColors.textPrimary,
                  inputPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  inputMargin: const EdgeInsets.fromLTRB(
                    12,
                    16,
                    12,
                    20,
                  ),
                  messageBorderRadius: 12,
                  sendButtonMargin: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                  userAvatarNameColors: [
                    Theme.of(context).brightness == Brightness.dark
                        ? AppColors.brandGreen
                        : AppColors.brandGreenDeep,
                    const Color(0xFF6C63FF),
                  ],
                ),
                showUserAvatars: true,
                showUserNames: false,
              );
            },
          ),
          if (_isUploading)
            Container(
              color: (Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF000000)
                      : const Color(0xFFFFFFFF))
                  .withOpacity(0.5),
              child: const Center(
                child: LoadingWidget(),
              ),
            ),
        ],
      ),
    );
  }

  types.Message _convertToFlutterChatMessage(MessageModel message) {
    final author = types.User(id: message.senderId);

    switch (message.type) {
      case MessageType.text:
        return types.TextMessage(
          author: author,
          createdAt: message.timestamp.millisecondsSinceEpoch,
          id: message.id,
          text: message.text ?? '',
        );
      case MessageType.image:
        return types.ImageMessage(
          author: author,
          createdAt: message.timestamp.millisecondsSinceEpoch,
          id: message.id,
          name: 'image',
          size: 0,
          uri: message.imageUrl ?? '',
        );
      case MessageType.video:
        return types.FileMessage(
          author: author,
          createdAt: message.timestamp.millisecondsSinceEpoch,
          id: message.id,
          name: '🎥 Video',
          size: 0,
          uri: message.videoUrl ?? '',
        );
      case MessageType.file:
        return types.FileMessage(
          author: author,
          createdAt: message.timestamp.millisecondsSinceEpoch,
          id: message.id,
          name: message.fileName ?? 'file',
          size: 0,
          uri: message.fileUrl ?? '',
        );
    }
  }

  Future<void> _handleSendPressed(
    types.PartialText message,
    String currentUserId,
  ) async {
    try {
      await _chatService.sendTextMessage(
        chatId: widget.chatId,
        senderId: currentUserId,
        text: message.text,
        otherUserId: widget.otherUserId,
      );
    } catch (e) {
      _showErrorSnackBar('Failed to send message');
    }
  }

  Future<void> _handleAttachmentPressed(String currentUserId) async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? const Color(0xFF1A1A1A) : AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildAttachmentOption(
                context,
                Icons.photo_library_rounded,
                'Photo',
                isDarkMode ? AppColors.brandGreen : AppColors.brandGreenDeep,
                () {
                  Navigator.pop(context);
                  _pickImage(currentUserId);
                },
              ),
              _buildAttachmentOption(
                context,
                Icons.videocam_rounded,
                'Video',
                const Color(0xFF10B981),
                () {
                  Navigator.pop(context);
                  _pickVideo(currentUserId);
                },
              ),
              _buildAttachmentOption(
                context,
                Icons.attach_file_rounded,
                'File',
                const Color(0xFFFFA500),
                () {
                  Navigator.pop(context);
                  _pickFile(currentUserId);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentOption(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(AppSizes.borderRadius),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.15),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isDarkMode
                    ? const Color(0xFFFFFFFF)
                    : AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(String currentUserId) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() => _isUploading = true);
        await _chatService.sendImageMessage(
          chatId: widget.chatId,
          senderId: currentUserId,
          imageFile: File(image.path),
          otherUserId: widget.otherUserId,
        );
      }
    } catch (e) {
      _showErrorSnackBar('Failed to send image');
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _pickVideo(String currentUserId) async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
      );

      if (video != null) {
        setState(() => _isUploading = true);
        await _chatService.sendVideoMessage(
          chatId: widget.chatId,
          senderId: currentUserId,
          videoFile: File(video.path),
          otherUserId: widget.otherUserId,
        );
      }
    } catch (e) {
      _showErrorSnackBar('Failed to send video');
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _pickFile(String currentUserId) async {
    try {
      final result = await FilePicker.platform.pickFiles();

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;

        setState(() => _isUploading = true);
        await _chatService.sendFileMessage(
          chatId: widget.chatId,
          senderId: currentUserId,
          file: file,
          fileName: fileName,
          otherUserId: widget.otherUserId,
        );
      }
    } catch (e) {
      _showErrorSnackBar('Failed to send file');
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE53935),
      ),
    );
  }

  Future<void> _handleMessageLongPress(
    BuildContext context,
    types.Message message,
    String currentUserId,
  ) async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Only allow deletion of messages sent by the current user
    if (message.author.id != currentUserId) {
      _showErrorSnackBar('You can only delete your own messages');
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor:
            isDarkMode ? const Color(0xFF1A1A1A) : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF5C5C).withOpacity(0.15),
              ),
              child: const Icon(
                Icons.delete_outline,
                color: Color(0xFFFF5C5C),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Delete Message',
              style: TextStyle(
                color: isDarkMode
                    ? const Color(0xFFFFFFFF)
                    : AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this message?',
          style: TextStyle(
            color:
                isDarkMode ? const Color(0xFFB0B0B0) : AppColors.textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDarkMode
                    ? AppColors.brandGreen
                    : AppColors.brandGreenDeep,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Color(0xFFFF5C5C),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await _chatService.deleteMessage(widget.chatId, message.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Message deleted'),
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.brandGreen
                  : AppColors.brandGreenDeep,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        _showErrorSnackBar('Failed to delete message: ${e.toString()}');
      }
    }
  }
}
