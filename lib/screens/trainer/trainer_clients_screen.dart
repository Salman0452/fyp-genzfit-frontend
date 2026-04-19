import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:genzfit/providers/auth_provider.dart';
import 'package:genzfit/models/user_model.dart';
import 'package:genzfit/services/firestore_service.dart';
import 'package:genzfit/utils/constants.dart';
import 'package:genzfit/widgets/loading_widget.dart';
import 'trainer_client_profile_screen.dart';

class TrainerClientsScreen extends StatefulWidget {
  const TrainerClientsScreen({super.key});

  @override
  State<TrainerClientsScreen> createState() => _TrainerClientsScreenState();
}

class _TrainerClientsScreenState extends State<TrainerClientsScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final trainerId = authProvider.user?.uid ?? '';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('My Clients'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('sessions')
            .where('trainerId', isEqualTo: trainerId)
            .where('status', isEqualTo: 'active')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: LoadingWidget());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading clients: ${snapshot.error}',
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFB0B0B0)
                      : AppColors.textSecondary,
                ),
              ),
            );
          }

          final sessions = snapshot.data?.docs ?? [];

          if (sessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFB0B0B0)
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No active clients',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFFFFFFF)
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your clients will appear here once they hire you',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFB0B0B0)
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final sessionDoc = sessions[index];
              final sessionData = sessionDoc.data() as Map<String, dynamic>;
              final clientId = sessionData['clientId'] as String;

              return FutureBuilder<UserModel?>(
                future: _firestoreService.getUser(clientId),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: LoadingWidget(),
                    );
                  }

                  final client = userSnapshot.data;
                  if (client == null) {
                    return const SizedBox.shrink();
                  }

                  return _buildClientCard(
                    context,
                    client,
                    clientId,
                    sessionDoc.id,
                    trainerId,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildClientCard(
    BuildContext context,
    UserModel client,
    String clientId,
    String sessionId,
    String trainerId,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TrainerClientProfileScreen(
              client: client,
              sessionId: sessionId,
              trainerId: trainerId,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1A1A1A)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.borderRadius),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.brandGreen.withOpacity(0.3)
                : AppColors.brandGreenDeep.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.brandGreen.withOpacity(0.2)
                    : AppColors.brandGreenDeep.withOpacity(0.2),
              ),
              child: client.avatarUrl != null && client.avatarUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: CachedNetworkImage(
                        imageUrl: client.avatarUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[700],
                        ),
                        errorWidget: (context, url, error) => Center(
                          child: Text(
                            client.name[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        client.name[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            // Client info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    client.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFFFFFFF)
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (client.goals != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.brandGreen.withOpacity(0.2)
                            : AppColors.brandGreenDeep.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _formatGoal(client.goals!),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.brandGreen
                              : AppColors.brandGreenDeep,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Arrow
            Icon(
              Icons.arrow_forward_ios,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFB0B0B0)
                  : AppColors.textSecondary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  String _formatGoal(String goal) {
    switch (goal) {
      case 'fitness':
        return 'General Fitness';
      case 'weightGain':
        return 'Weight Gain';
      case 'weightLoss':
        return 'Weight Loss';
      default:
        return goal;
    }
  }
}
