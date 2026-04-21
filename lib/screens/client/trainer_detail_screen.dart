import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:genzfit/utils/constants.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../shared/loading_widget.dart';
import '../chat/chat_detail_screen.dart';
import 'payment_checkout_screen.dart';

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

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('sessions')
          .where('clientId', isEqualTo: currentUserId)
          .where('trainerId', isEqualTo: widget.userId)
          .get();

      bool hasActive = false;
      bool hasPending = false;

      for (var doc in snapshot.docs) {
        final status = doc.data()['status'] as String?;
        if (status == 'active') {
          hasActive = true;
        } else if (status == 'requested') {
          hasPending = true;
        }
      }

      setState(() {
        _hasActiveSession = hasActive;
        _hasPendingRequest = hasPending;
      });
    } catch (e) {
      print('Error checking session status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: const Center(child: LoadingWidget()),
          );
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('trainers')
              .doc(widget.trainerId)
              .snapshots(),
          builder: (context, trainerSnapshot) {
            if (!trainerSnapshot.hasData) {
              return Scaffold(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                body: const Center(child: LoadingWidget()),
              );
            }

            final userData = userSnapshot.data!.data() as Map<String, dynamic>;
            final trainerData =
                trainerSnapshot.data!.data() as Map<String, dynamic>;

            return _buildContent(userData, trainerData, isDarkMode);
          },
        );
      },
    );
  }

  Widget _buildContent(
    Map<String, dynamic> userData,
    Map<String, dynamic> trainerData,
    bool isDarkMode,
  ) {
    final name = userData['name'] ?? 'Trainer';
    final avatarUrl = userData['avatarUrl'] ?? '';
    final bio = trainerData['bio'] ?? '';
    final rating = (trainerData['rating'] ?? 0.0).toDouble();
    final monthlyRate = (trainerData['monthlyRate'] ?? 0.0).toDouble();
    final clients = trainerData['clients'] ?? 0;
    final expertise = List<String>.from(trainerData['expertise'] ?? []);
    final certifications =
        List<String>.from(trainerData['certifications'] ?? []);
    final videoUrls = List<String>.from(trainerData['videoUrls'] ?? []);

    final accentColor =
        isDarkMode ? AppColors.brandGreen : AppColors.brandGreenDeep;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            elevation: 0,
            backgroundColor:
                isDarkMode ? const Color(0xFF1A1A1A) : AppColors.surface,
            iconTheme: IconThemeData(
              color: accentColor,
              size: 20,
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Hero image
                  if (avatarUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: avatarUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: accentColor.withOpacity(0.1),
                      ),
                    )
                  else
                    Container(
                      color: accentColor.withOpacity(0.1),
                      child: Icon(
                        Icons.person,
                        size: 120,
                        color: accentColor.withOpacity(0.3),
                      ),
                    ),
                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.6),
                        ],
                      ),
                    ),
                  ),
                  // Header info
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.5,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            // Rating
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.star_rounded,
                                      color: accentColor, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Clients
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.people_rounded,
                                      color: AppColors.brandBlue, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$clients clients',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Verified badge (prominent)
                  if (trainerData['verified'] == true)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: accentColor.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Verified Trainer',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: accentColor,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (trainerData['verified'] == true)
                    const SizedBox(height: 16),
                  // Modern price card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? const Color(0xFF262626)
                          : const Color(0xFFFAFAFA),
                      borderRadius:
                          BorderRadius.circular(AppSizes.borderRadius),
                      border: Border.all(
                        color: accentColor.withOpacity(0.2),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDarkMode
                              ? Colors.black.withOpacity(0.3)
                              : Colors.black.withOpacity(0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Monthly Rate',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode
                                    ? const Color(0xFFB0B0B0)
                                    : AppColors.textSecondary,
                                letterSpacing: -0.1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'PKR ${monthlyRate.toStringAsFixed(0)}/month',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: accentColor,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.trending_up_rounded,
                            color: accentColor,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Bio section
                  if (bio.isNotEmpty) ...[
                    Text(
                      'About',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDarkMode
                            ? const Color(0xFFFFFFFF)
                            : AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? const Color(0xFF262626)
                            : const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: accentColor.withOpacity(0.1),
                        ),
                      ),
                      child: Text(
                        bio,
                        style: TextStyle(
                          color: isDarkMode
                              ? const Color(0xFFD0D0D0)
                              : AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.6,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],

                  // Expertise section
                  if (expertise.isNotEmpty) ...[
                    Text(
                      'Specializations',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDarkMode
                            ? const Color(0xFFFFFFFF)
                            : AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: expertise.map((exp) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brandBlue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.brandBlue.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 14,
                                color: AppColors.brandBlue,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                exp,
                                style: const TextStyle(
                                  color: AppColors.brandBlue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 28),
                  ],

                  // Certifications section
                  if (certifications.isNotEmpty) ...[
                    Text(
                      'Certifications',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDarkMode
                            ? const Color(0xFFFFFFFF)
                            : AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 160,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: certifications.length,
                        itemBuilder: (context, index) {
                          return Container(
                            width: 140,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? const Color(0xFF262626)
                                  : const Color(0xFFFAFAFA),
                              borderRadius:
                                  BorderRadius.circular(AppSizes.borderRadius),
                              border: Border.all(
                                color: accentColor.withOpacity(0.2),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isDarkMode
                                      ? Colors.black.withOpacity(0.3)
                                      : Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(AppSizes.borderRadius),
                              child: CachedNetworkImage(
                                imageUrl: certifications[index],
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorWidget: (context, url, error) => Container(
                                  color: accentColor.withOpacity(0.1),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.verified_user_rounded,
                                        color: accentColor,
                                        size: 32,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Certificate',
                                        style: TextStyle(
                                          color: isDarkMode
                                              ? const Color(0xFFB0B0B0)
                                              : AppColors.textSecondary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],

                  // Videos section
                  if (videoUrls.isNotEmpty) ...[
                    Text(
                      'Training Videos',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDarkMode
                            ? const Color(0xFFFFFFFF)
                            : AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 140,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: videoUrls.length,
                        itemBuilder: (context, index) {
                          return Container(
                            width: 200,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(AppSizes.borderRadius),
                              boxShadow: [
                                BoxShadow(
                                  color: isDarkMode
                                      ? Colors.black.withOpacity(0.4)
                                      : Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                      AppSizes.borderRadius),
                                  child: CachedNetworkImage(
                                    imageUrl: videoUrls[index],
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                    errorWidget: (context, url, error) =>
                                        Container(
                                      color: accentColor.withOpacity(0.1),
                                      child: Icon(
                                        Icons.video_library_rounded,
                                        color: accentColor.withOpacity(0.5),
                                        size: 40,
                                      ),
                                    ),
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.35),
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  child: Icon(
                                    Icons.play_arrow_rounded,
                                    color: accentColor,
                                    size: 28,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],

                  // Action buttons
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(monthlyRate),
    );
  }

  Widget _buildBottomBar(double monthlyRate) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final accentColor =
        isDarkMode ? AppColors.brandGreen : AppColors.brandGreenDeep;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A1A) : AppColors.surface,
        border: Border(
          top: BorderSide(
            color: accentColor.withOpacity(0.1),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: (isDarkMode ? const Color(0xFF000000) : Colors.black)
                .withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _handleMessageTrainer,
                icon: const Icon(Icons.message_outlined, size: 18),
                label: const Text(
                  'Message',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brandBlue,
                  side: BorderSide(
                    color: AppColors.brandBlue.withOpacity(0.5),
                    width: 1.5,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _isLoading || _hasActiveSession || _hasPendingRequest
                    ? null
                    : () => _handleHireTrainer(monthlyRate),
                icon: Icon(
                  _hasActiveSession
                      ? Icons.check_circle
                      : _hasPendingRequest
                          ? Icons.hourglass_empty
                          : Icons.handshake_outlined,
                  size: 18,
                ),
                label: Text(
                  _hasActiveSession
                      ? 'Active Session'
                      : _hasPendingRequest
                          ? 'Request Pending'
                          : 'Hire Trainer',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: isDarkMode ? Colors.black87 : Colors.white,
                  disabledBackgroundColor: accentColor.withOpacity(0.5),
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  shadowColor: accentColor.withOpacity(0.3),
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

  Future<void> _handleHireTrainer(double monthlyRate) async {
    try {
      // Get trainer details
      final trainerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (!trainerDoc.exists) {
        _showErrorSnackBar('Trainer not found');
        return;
      }

      final trainerUser = UserModel.fromMap({
        'id': trainerDoc.id,
        ...trainerDoc.data()!,
      });

      // Generate subscription ID for payment tracking
      final subscriptionId =
          FirebaseFirestore.instance.collection('subscriptions').doc().id;

      if (mounted) {
        // Navigate to payment checkout screen for monthly subscription
        final transactionId = await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentCheckoutScreen(
              trainer: trainerUser,
              sessionAmount: monthlyRate,
              sessionId: subscriptionId,
            ),
          ),
        );

        // If payment was submitted, create the subscription
        if (transactionId != null && mounted) {
          await _createSessionAfterPayment(
            subscriptionId,
            transactionId,
            monthlyRate,
          );
        }
      }
    } catch (e) {
      _showErrorSnackBar('Failed to process hire request: $e');
    }
  }

  Future<void> _createSessionAfterPayment(
    String sessionId,
    String transactionId,
    double amount,
  ) async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUserId = authProvider.user?.uid ?? '';

      // Create session with payment info
      await FirebaseFirestore.instance
          .collection('sessions')
          .doc(sessionId)
          .set({
        'clientId': currentUserId,
        'trainerId': widget.userId,
        'status': 'requested', // Still needs trainer approval
        'amount': amount,
        'paymentStatus':
          'pendingVerification', // Payment awaiting admin verification
        'transactionId': transactionId,
        'notes': _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _notesController.clear();
      await _checkSessionStatus();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Payment submitted! Awaiting admin verification and trainer approval.',
            ),
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? AppColors.brandGreen
                : AppColors.brandGreenDeep,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar('Failed to create session: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }
}
