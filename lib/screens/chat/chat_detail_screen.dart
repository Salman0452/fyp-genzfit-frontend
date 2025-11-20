import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
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
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUserId = authProvider.user?.uid ?? '';
    final currentUser = authProvider.currentUser;

    final user = types.User(
      id: currentUserId,
      firstName: currentUser?.name ?? 'You',
      imageUrl: currentUser?.avatarUrl,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey[800],
              backgroundImage: widget.otherUserAvatar != null &&
                      widget.otherUserAvatar!.isNotEmpty
                  ? CachedNetworkImageProvider(widget.otherUserAvatar!)
                  : null,
              child: widget.otherUserAvatar == null ||
                      widget.otherUserAvatar!.isEmpty
                  ? Text(
                      widget.otherUserName[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.otherUserName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
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
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                );
              }

              final messages = snapshot.data ?? [];
              final chatMessages =
                  messages.map((msg) => _convertToFlutterChatMessage(msg)).toList();

              return Chat(
                messages: chatMessages,
                onSendPressed: (message) => _handleSendPressed(
                  message,
                  currentUserId,
                ),
                onAttachmentPressed: () => _handleAttachmentPressed(currentUserId),
                user: user,
                theme: DarkChatTheme(
                  backgroundColor: Colors.black,
                  primaryColor: Colors.blue,
                  secondaryColor: Colors.grey[900]!,
                  inputBackgroundColor: Colors.grey[900]!,
                  inputTextColor: Colors.white,
                  messageBorderRadius: 12,
                  userAvatarNameColors: [Colors.blue, Colors.purple],
                ),
                showUserAvatars: true,
                showUserNames: false,
              );
            },
          ),
          if (_isUploading)
            Container(
              color: Colors.black.withOpacity(0.5),
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo, color: Colors.blue),
              title: const Text('Photo', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(currentUserId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Colors.green),
              title: const Text('Video', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickVideo(currentUserId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file, color: Colors.orange),
              title: const Text('File', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickFile(currentUserId);
              },
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
        backgroundColor: Colors.red,
      ),
    );
  }
}
