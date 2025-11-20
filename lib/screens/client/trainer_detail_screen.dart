import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/trainer_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../services/session_service.dart';
import '../../services/hiring_service.dart';
import '../shared/loading_widget.dart';
import '../chat/chat_detail_screen.dart';

class TrainerDetailScreen extends StatefulWidget {
  final String trainerId;
  final String userId;

  const TrainerDetailScreen({
    super.key,
    required this.trainerId,
    required this.userId,
  });

  @override
  State<TrainerDetailScreen> createState() => _TrainerDetailScreenState();
}

class _TrainerDetailScreenState extends State<TrainerDetailScreen> {
  final ChatService _chatService = ChatService();
  final SessionService _sessionService = SessionService();
  final HiringService _hiringService = HiringService();
  final TextEditingController _notesController = TextEditingController();
  bool _isLoading = false;
  bool _hasActiveSession = false;
  bool _hasPendingRequest = false;

  @override
  void initState() {
    super.initState();
    _checkSessionStatus();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _checkSessionStatus() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.user?.uid ?? '';

    final hasExisting = await _hiringService.hasExistingRequest(
      currentUserId,
      widget.userId,
    );

    setState(() {
      _hasActiveSession = hasExisting;
      _hasPendingRequest = hasExisting;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: LoadingWidget()),
          );
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('trainers')
              .doc(widget.trainerId)
              .snapshots(),
          builder: (context, trainerSnapshot) {
            if (!trainerSnapshot.hasData) {
              return const Scaffold(
                backgroundColor: Colors.black,
                body: Center(child: LoadingWidget()),
              );
            }

            final userData =
                userSnapshot.data!.data() as Map<String, dynamic>;
            final trainerData =
                trainerSnapshot.data!.data() as Map<String, dynamic>;

            return _buildContent(userData, trainerData);
          },
        );
      },
    );
  }

  Widget _buildContent(
    Map<String, dynamic> userData,
    Map<String, dynamic> trainerData,
  ) {
    final name = userData['name'] ?? 'Trainer';
    final avatarUrl = userData['avatarUrl'] ?? '';
    final bio = trainerData['bio'] ?? '';
    final rating = (trainerData['rating'] ?? 0.0).toDouble();
    final hourlyRate = (trainerData['hourlyRate'] ?? 0.0).toDouble();
    final clients = trainerData['clients'] ?? 0;
    final expertise = List<String>.from(trainerData['expertise'] ?? []);
    final certifications =
        List<String>.from(trainerData['certifications'] ?? []);
    final videoUrls = List<String>.from(trainerData['videoUrls'] ?? []);

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
          pinned: true,
          backgroundColor: Colors.grey[900],
          iconTheme: const IconThemeData(color: Colors.white),
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                if (avatarUrl.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: avatarUrl,
                    fit: BoxFit.cover,
                  )
                else
                  Container(
                    color: Colors.grey[850],
                    child: Icon(
                      Icons.person,
                      size: 100,
                      color: Colors.grey[700],
                    ),
                  ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(Icons.people, color: Colors.blue, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            '$clients clients',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Price card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue, width: 2),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '\$${hourlyRate.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'per hour',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Bio
                if (bio.isNotEmpty) ...[
                  const Text(
                    'About',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    bio,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Expertise
                if (expertise.isNotEmpty) ...[
                  const Text(
                    'Expertise',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: expertise.map((exp) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.blue, width: 1),
                        ),
                        child: Text(
                          exp,
                          style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                ],

                // Certifications
                if (certifications.isNotEmpty) ...[
                  const Text(
                    'Certifications',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...certifications.map((cert) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(Icons.verified, color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              cert,
                              style: TextStyle(
                                color: Colors.grey[300],
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                ],

                // Videos
                if (videoUrls.isNotEmpty) ...[
                  const Text(
                    'Training Videos',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: videoUrls.length,
                      itemBuilder: (context, index) {
                        return Container(
                          width: 200,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[850],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  imageUrl: videoUrls[index],
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  errorWidget: (context, url, error) =>
                                      Icon(Icons.video_library,
                                          color: Colors.grey[600], size: 40),
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(12),
                                child: const Icon(
                                  Icons.play_arrow,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Action buttons
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
      ),
      bottomNavigationBar: _buildBottomBar(hourlyRate),
    );
  }

  Widget _buildBottomBar(double hourlyRate) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading ? null : _handleMessageTrainer,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  side: const BorderSide(color: Colors.blue, width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Message',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isLoading || _hasActiveSession || _hasPendingRequest
                    ? null
                    : () => _handleHireTrainer(hourlyRate),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _hasActiveSession
                      ? 'Active Session'
                      : _hasPendingRequest
                          ? 'Request Pending'
                          : 'Hire Trainer',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleMessageTrainer() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUserId = authProvider.user?.uid ?? '';
      final currentUser = authProvider.currentUser!;

      final trainerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      final trainerUser = UserModel.fromMap({
        'id': trainerDoc.id,
        ...trainerDoc.data()!,
      });

      final chatId = await _chatService.createOrGetChat(
        currentUserId,
        widget.userId,
        currentUser,
        trainerUser,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailScreen(
              chatId: chatId,
              otherUserId: widget.userId,
              otherUserName: trainerUser.name,
              otherUserAvatar: trainerUser.avatarUrl,
            ),
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar('Failed to start chat');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleHireTrainer(double hourlyRate) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Hire Trainer',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rate: \$${hourlyRate.toStringAsFixed(0)}/hour',
              style: TextStyle(color: Colors.grey[400]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Add notes (optional)',
                hintStyle: TextStyle(color: Colors.grey[600]),
                filled: true,
                fillColor: Colors.grey[850],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _submitHireRequest(hourlyRate);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitHireRequest(double hourlyRate) async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUserId = authProvider.user?.uid ?? '';

      final sessionId = await _hiringService.createHiringRequest(
        clientId: currentUserId,
        trainerId: widget.userId,
        amount: hourlyRate,
        notes: _notesController.text.trim().isNotEmpty 
            ? _notesController.text.trim() 
            : null,
      );

      if (sessionId != null) {
        _notesController.clear();
        await _checkSessionStatus();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Request sent successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        _showErrorSnackBar('Failed to send request');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to send request');
    } finally {
      setState(() => _isLoading = false);
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
