import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:genzfit/providers/auth_provider.dart';
import 'package:genzfit/services/notifications_service.dart';
import 'package:genzfit/models/notification_model.dart';
import 'package:genzfit/utils/constants.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationsService _notificationsService = NotificationsService();

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFFFFFFFF)
                : AppColors.textPrimary,
          ),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (userId != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: TextButton(
                  onPressed: () async {
                    await _notificationsService.markAllAsRead(userId);
                  },
                  child: Text(
                    'Mark all as read',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandGreen,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: userId == null
          ? Center(
              child: Text(
                'Please log in to view notifications',
                style: GoogleFonts.plusJakartaSans(fontSize: 16),
              ),
            )
          : StreamBuilder<List<NotificationModel>>(
              stream: _notificationsService.getUserNotifications(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading notifications: ${snapshot.error}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 14),
                    ),
                  );
                }

                final notifications = snapshot.data ?? [];

                if (notifications.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_off_outlined,
                          size: 64,
                          color: AppColors.textSecondary.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No notifications yet',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You\'ll see updates here when trainers respond\nor sessions are approved',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return _buildNotificationCard(context, notification);
                  },
                );
              },
            ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    NotificationModel notification,
  ) {
    final isUnread = !notification.read;

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete, color: Colors.red.withOpacity(0.7)),
      ),
      onDismissed: (direction) async {
        await _notificationsService.deleteNotification(notification.id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUnread
              ? (Theme.of(context).brightness == Brightness.dark
                  ? AppColors.brandGreen.withOpacity(0.1)
                  : AppColors.brandGreen.withOpacity(0.08))
              : (Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1E1E1E)
                  : const Color(0xFFF5F5F5)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isUnread
                ? AppColors.brandGreen.withOpacity(0.3)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    notification.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isUnread
                          ? AppColors.brandGreen
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                if (isUnread)
                  GestureDetector(
                    onTap: () async {
                      await _notificationsService.markAsRead(notification.id);
                    },
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.brandGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              notification.message,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFB0B0B0)
                    : AppColors.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatTime(notification.createdAt),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary.withOpacity(0.6),
                  ),
                ),
                Text(
                  _getNotificationTypeLabel(notification.type),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _getNotificationTypeColor(notification.type),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  String _getNotificationTypeLabel(String type) {
    switch (type) {
      case 'session_approved':
        return 'Session Approved';
      case 'payment_rejected':
        return 'Payment Rejected';
      case 'message':
        return 'Message';
      default:
        return type.replaceAll('_', ' ');
    }
  }

  Color _getNotificationTypeColor(String type) {
    switch (type) {
      case 'session_approved':
        return AppColors.brandGreen;
      case 'payment_rejected':
        return Colors.red;
      case 'message':
        return AppColors.brandGreenDeep;
      default:
        return AppColors.textSecondary;
    }
  }
}
