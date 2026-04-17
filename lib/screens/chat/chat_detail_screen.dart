import 'package:flutter/material.dart';
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
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _markMessagesAsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _markMessagesAsRead() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.user?.uid ?? '';
    await _chatService.markMessagesAsRead(widget.chatId, currentUserId);
  }

  Future<void> _handleAttachmentPressed(String userId) async {
    // Implement attachment handling
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Image'),
              onTap: () async {
                Navigator.pop(context);
                final image =
                    await _imagePicker.pickImage(source: ImageSource.gallery);
                if (image != null) {
                  // Handle image upload
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_copy),
              title: const Text('File'),
              onTap: () async {
                Navigator.pop(context);
                final result = await FilePicker.platform.pickFiles();
                if (result != null) {
                  // Handle file upload
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid ?? '';

    try {
      await _chatService.sendTextMessage(
        chatId: widget.chatId,
        senderId: userId,
        otherUserId: widget.otherUserId,
        text: _messageController.text,
      );
      _messageController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUserId = authProvider.user?.uid ?? '';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: isDarkMode ? const Color(0xFFFFFFFF) : AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
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
        elevation: 0,
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
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
                        color: isDarkMode
                            ? const Color(0xFFB0B0B0)
                            : AppColors.textSecondary,
                      ),
                    ),
                  );
                }

                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet. Start the conversation!',
                      style: TextStyle(
                        color: isDarkMode
                            ? const Color(0xFFB0B0B0)
                            : AppColors.textSecondary,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  itemCount:
                      messages.length * 2, // Account for potential separators
                  itemBuilder: (context, index) {
                    // Calculate the actual message index (reverse order)
                    final messageIndex = index ~/ 2;

                    // Check if we need to show a date separator
                    final shouldShowSeparator = index % 2 == 1;

                    if (messageIndex >= messages.length) {
                      return const SizedBox.shrink();
                    }

                    final message = messages[messageIndex];
                    final isSentByUser = message.senderId == currentUserId;

                    // Check if next message (in chronological order, previous in reversed list) is on different day
                    bool showDateSeparator = false;
                    if (shouldShowSeparator &&
                        messageIndex + 1 < messages.length) {
                      final currentMessageDay = DateTime(
                        message.timestamp.year,
                        message.timestamp.month,
                        message.timestamp.day,
                      );
                      final nextMessageDay = DateTime(
                        messages[messageIndex + 1].timestamp.year,
                        messages[messageIndex + 1].timestamp.month,
                        messages[messageIndex + 1].timestamp.day,
                      );
                      showDateSeparator = currentMessageDay != nextMessageDay;
                    }

                    if (showDateSeparator) {
                      return _buildDateSeparator(
                        messages[messageIndex].timestamp,
                        isDarkMode,
                      );
                    }

                    return _buildMessageBubble(
                      message,
                      isSentByUser,
                      isDarkMode,
                    );
                  },
                );
              },
            ),
          ),
          // Input Field
          Container(
            color: isDarkMode ? const Color(0xFF1A1A1A) : AppColors.surface,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _handleAttachmentPressed(currentUserId),
                  icon: Icon(
                    Icons.add_circle_outline,
                    color: isDarkMode
                        ? AppColors.brandGreen
                        : AppColors.brandGreenDeep,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    maxLines: null,
                    style: TextStyle(
                      color: isDarkMode
                          ? const Color(0xFFFFFFFF)
                          : AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(
                        color: isDarkMode
                            ? const Color(0xFF9F9F9F)
                            : AppColors.textSecondary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: isDarkMode
                              ? const Color(0xFF333333)
                              : const Color(0xFFE0E0E0),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: isDarkMode
                              ? AppColors.brandGreen
                              : AppColors.brandGreenDeep,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDarkMode
                          ? AppColors.brandGreen
                          : AppColors.brandGreenDeep,
                    ),
                    child: Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSeparator(DateTime dateTime, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color:
                isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFE8E8E8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _formatDateSeparator(dateTime),
            style: TextStyle(
              color: isDarkMode
                  ? const Color(0xFF9F9F9F)
                  : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
    MessageModel message,
    bool isSentByUser,
    bool isDarkMode,
  ) {
    return Padding(
      padding: EdgeInsets.only(
        left: isSentByUser ? 60 : 12,
        right: isSentByUser ? 12 : 60,
        bottom: 8,
      ),
      child: Align(
        alignment: isSentByUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: isSentByUser
                ? (isDarkMode ? AppColors.brandGreen : AppColors.brandGreenDeep)
                : (isDarkMode
                    ? const Color(0xFF2A2A2A)
                    : const Color(0xFFE8E8E8)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.type == MessageType.text)
                Text(
                  message.text ?? '',
                  style: TextStyle(
                    color: isSentByUser
                        ? const Color(0xFF000000)
                        : (isDarkMode
                            ? const Color(0xFFFFFFFF)
                            : AppColors.textPrimary),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              if (message.type == MessageType.image && message.imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: message.imageUrl!,
                    width: 200,
                    height: 200,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const LoadingWidget(),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.error),
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                _formatTimeOnly(message.timestamp),
                style: TextStyle(
                  color: isSentByUser
                      ? const Color(0xFF000000).withOpacity(0.6)
                      : (isDarkMode
                          ? const Color(0xFF9F9F9F)
                          : AppColors.textSecondary),
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeOnly(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateSeparator(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDay = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDay == today) {
      return 'Today';
    } else if (messageDay == yesterday) {
      return 'Yesterday';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
