import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/chat_model.dart';
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
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUserId = authProvider.user?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Messages',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
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
                style: TextStyle(color: Colors.grey[400]),
              ),
            );
          }

          final chats = snapshot.data ?? [];

          if (chats.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Colors.grey[700],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No messages yet',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start a conversation with a trainer',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: chats.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: Colors.grey[800],
              indent: 80,
            ),
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
    final otherUserName = chat.getOtherParticipantName(currentUserId) ?? 'User';
    final otherUserAvatar = chat.getOtherParticipantAvatar(currentUserId);
    final unreadCount = chat.getUnreadCountForUser(currentUserId);
    final lastMessage = chat.lastMessage;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        radius: 28,
        backgroundColor: Colors.grey[800],
        backgroundImage: otherUserAvatar != null && otherUserAvatar.isNotEmpty
            ? CachedNetworkImageProvider(otherUserAvatar)
            : null,
        child: otherUserAvatar == null || otherUserAvatar.isEmpty
            ? Text(
                otherUserName[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
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
                color: Colors.white,
                fontWeight:
                    unreadCount > 0 ? FontWeight.bold : FontWeight.w500,
                fontSize: 16,
              ),
            ),
          ),
          if (chat.lastMessageTime != null)
            Text(
              timeago.format(chat.lastMessageTime!),
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
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
                color: unreadCount > 0 ? Colors.grey[300] : Colors.grey[500],
                fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
          if (unreadCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
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
    );
  }

  String _getLastMessageText(Map<String, dynamic>? lastMessage) {
    if (lastMessage == null) return 'No messages yet';

    final type = lastMessage['type'] as String?;
    final text = lastMessage['text'] as String?;

    switch (type) {
      case 'image':
        return '📷 Image';
      case 'video':
        return '🎥 Video';
      case 'file':
        return '📎 File';
      default:
        return text ?? 'Message';
    }
  }
}
