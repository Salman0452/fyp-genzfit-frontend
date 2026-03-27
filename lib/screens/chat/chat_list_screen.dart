import 'package:flutter/material.dart';
import 'package:genzfit/utils/constants.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/chat_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../shared/loading_widget.dart';
import 'chat_detail_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatService _chatService = ChatService();

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUserId = authProvider.user?.uid ?? '';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor:
            isDarkMode ? const Color(0xFF1A1A1A) : AppColors.surface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Messages',
              style: TextStyle(
                color: isDarkMode
                    ? const Color(0xFFFFFFFF)
                    : AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Connect with your trainers',
              style: TextStyle(
                color: isDarkMode
                    ? const Color(0xFF9F9F9F)
                    : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        iconTheme: IconThemeData(
          color: isDarkMode ? const Color(0xFFFFFFFF) : AppColors.textPrimary,
        ),
      ),
      body: StreamBuilder<List<ChatModel>>(
        stream: _chatService.getUserChats(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: LoadingWidget());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading chats',
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFB0B0B0)
                      : AppColors.textSecondary,
                ),
              ),
            );
          }

          final chats = snapshot.data ?? [];

          if (chats.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (isDarkMode
                                ? AppColors.brandGreen
                                : AppColors.brandGreenDeep)
                            .withOpacity(0.15),
                      ),
                      child: Icon(
                        Icons.chat_bubble_outline,
                        size: 40,
                        color: isDarkMode
                            ? AppColors.brandGreen
                            : AppColors.brandGreenDeep,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No messages yet',
                      style: TextStyle(
                        color: isDarkMode
                            ? const Color(0xFFFFFFFF)
                            : AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Start a conversation with a trainer',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDarkMode
                            ? const Color(0xFF9F9F9F)
                            : AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: chats.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final chat = chats[index];
              return _buildChatItem(context, chat, currentUserId);
            },
          );
        },
      ),
    );
  }

  Widget _buildChatItem(
    BuildContext context,
    ChatModel chat,
    String currentUserId,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final otherUserName = chat.getOtherParticipantName(currentUserId) ?? 'User';
    final otherUserAvatar = chat.getOtherParticipantAvatar(currentUserId);
    final unreadCount = chat.getUnreadCountForUser(currentUserId);
    final lastMessage = chat.lastMessage;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF262626) : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        border: Border.all(
          color: (isDarkMode ? AppColors.brandGreen : AppColors.brandGreenDeep)
              .withOpacity(0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.15)
                : Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          radius: 28,
          backgroundColor:
              isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0),
          backgroundImage: otherUserAvatar != null && otherUserAvatar.isNotEmpty
              ? CachedNetworkImageProvider(otherUserAvatar)
              : null,
          child: otherUserAvatar == null || otherUserAvatar.isEmpty
              ? Text(
                  otherUserName[0].toUpperCase(),
                  style: TextStyle(
                    color: isDarkMode
                        ? const Color(0xFFFFFFFF)
                        : AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                otherUserName,
                style: TextStyle(
                  color: isDarkMode
                      ? const Color(0xFFFFFFFF)
                      : AppColors.textPrimary,
                  fontWeight:
                      unreadCount > 0 ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 15,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            if (chat.lastMessageTime != null)
              Text(
                timeago.format(chat.lastMessageTime!),
                style: TextStyle(
                  color: isDarkMode
                      ? const Color(0xFF808080)
                      : const Color(0xFF9F9F9F),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: Text(
                _getLastMessageText(lastMessage),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: unreadCount > 0
                      ? (isDarkMode
                          ? const Color(0xFFD0D0D0)
                          : const Color(0xFF616161))
                      : (isDarkMode
                          ? const Color(0xFF808080)
                          : const Color(0xFF9F9F9F)),
                  fontWeight:
                      unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? AppColors.brandGreen
                      : AppColors.brandGreenDeep,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  unreadCount.toString(),
                  style: TextStyle(
                    color: isDarkMode
                        ? const Color(0xFF010101)
                        : const Color(0xFFFFFFFF),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatDetailScreen(
                chatId: chat.id,
                otherUserId: chat.getOtherParticipantId(currentUserId),
                otherUserName: otherUserName,
                otherUserAvatar: otherUserAvatar,
              ),
            ),
          );
        },
        onLongPress: () => _handleLongPress(context, chat.id, currentUserId),
      ),
    );
  }

  String _getLastMessageText(Map<String, dynamic>? lastMessage) {
    if (lastMessage == null) return 'No messages yet';

    final type = lastMessage['type'] as String?;
    final text = lastMessage['text'] as String?;

    switch (type) {
      case 'image':
        return 'Image';
      case 'video':
        return 'Video';
      case 'file':
        return 'File';
      default:
        return text ?? 'Message';
    }
  }

  Future<void> _handleLongPress(
      BuildContext context, String chatId, String currentUserId) async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userRole = authProvider.currentUser?.role ?? UserRole.trainer;

    // Only clients can delete chats
    if (userRole != UserRole.client) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Only clients can delete chats'),
          backgroundColor:
              isDarkMode ? const Color(0xFFFF5C5C) : const Color(0xFFD32F2F),
        ),
      );
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
              'Delete Chat',
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
          'This will permanently delete this chat and all messages. This action cannot be undone.',
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
        await _chatService.deleteChat(chatId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Chat deleted successfully'),
              backgroundColor:
                  isDarkMode ? AppColors.brandGreen : AppColors.brandGreenDeep,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete chat: $e'),
              backgroundColor: isDarkMode
                  ? const Color(0xFFFF5C5C)
                  : const Color(0xFFD32F2F),
            ),
          );
        }
      }
    }
  }
}
