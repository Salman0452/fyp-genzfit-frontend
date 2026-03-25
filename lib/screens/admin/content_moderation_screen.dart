import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:genzfit/utils/constants.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class ContentModerationScreen extends StatefulWidget {
  const ContentModerationScreen({super.key});

  @override
  State<ContentModerationScreen> createState() =>
      _ContentModerationScreenState();
}

class _ContentModerationScreenState extends State<ContentModerationScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brandGreen = isDark ? AppColors.brandGreen : AppColors.brandGreenDeep;
    final primaryText =
        isDark ? const Color(0xFFFFFFFF) : AppColors.textPrimary;
    final secondaryText =
        isDark ? const Color(0xFFB0B0B0) : AppColors.textSecondary;
    final cardBackground = isDark ? const Color(0xFF1A1A1A) : AppColors.surface;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cardBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: primaryText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Content Moderation',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: primaryText,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: brandGreen,
          labelColor: brandGreen,
          unselectedLabelColor: secondaryText,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Flagged Content'),
            Tab(text: 'Reported Messages'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFlaggedContentTab(),
          _buildReportedMessagesTab(),
        ],
      ),
    );
  }

  Widget _buildFlaggedContentTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brandGreen = isDark ? AppColors.brandGreen : AppColors.brandGreenDeep;
    final primaryText =
        isDark ? const Color(0xFFFFFFFF) : AppColors.textPrimary;
    final secondaryText =
        isDark ? const Color(0xFFB0B0B0) : AppColors.textSecondary;

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('reports')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: GoogleFonts.inter(
                  color: isDark ? Colors.red.shade300 : Colors.red.shade700),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: brandGreen),
          );
        }

        final reports = snapshot.data?.docs ?? [];

        if (reports.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline,
                    size: 64,
                    color: isDark
                        ? const Color(0xFF424242)
                        : AppColors.textSecondary.withOpacity(0.3)),
                const SizedBox(height: 16),
                Text(
                  'No flagged content',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: secondaryText.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final report = reports[index].data() as Map<String, dynamic>;
            final reportId = reports[index].id;
            return _buildReportCard(report, reportId);
          },
        );
      },
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report, String reportId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brandGreen = isDark ? AppColors.brandGreen : AppColors.brandGreenDeep;
    final primaryText =
        isDark ? const Color(0xFFFFFFFF) : AppColors.textPrimary;
    final secondaryText =
        isDark ? const Color(0xFFB0B0B0) : AppColors.textSecondary;
    final cardBackground = isDark ? const Color(0xFF1A1A1A) : AppColors.surface;
    final redColor = isDark ? Colors.red.shade400 : Colors.red.shade700;

    final contentType = report['contentType'] as String? ?? 'Unknown';
    final reason = report['reason'] as String? ?? 'No reason provided';
    final details = report['details'] as String? ?? '';
    final reportedBy = report['reportedBy'] as String? ?? 'Unknown';
    final reportedUserId = report['reportedUserId'] as String? ?? '';
    final contentId = report['contentId'] as String? ?? '';
    final createdAt = (report['createdAt'] as Timestamp?)?.toDate();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: redColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: redColor.withOpacity(0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(
                  _getContentIcon(contentType),
                  color: redColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reported $contentType',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: primaryText,
                        ),
                      ),
                      if (createdAt != null)
                        Text(
                          DateFormat('MMM dd, yyyy • hh:mm a')
                              .format(createdAt),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: secondaryText.withOpacity(0.6),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: redColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'PENDING',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.textPrimary
                          : const Color(0xFFFFFFFF),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Reason', reason, redColor),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildInfoRow('Details', details, secondaryText),
                ],
                const SizedBox(height: 12),
                _buildInfoRow('Reported By', reportedBy, secondaryText),
                const SizedBox(height: 12),
                _buildInfoRow('Reported User', reportedUserId, secondaryText),
                const SizedBox(height: 12),
                _buildInfoRow(
                    'Content ID', contentId, secondaryText.withOpacity(0.6)),
              ],
            ),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _viewContent(contentType, contentId),
                    icon: const Icon(Icons.visibility),
                    label: Text(
                      'View Content',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandGreen,
                      foregroundColor: isDark
                          ? AppColors.textPrimary
                          : const Color(0xFFFFFFFF),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _takeAction(
                        reportId, contentType, contentId, reportedUserId),
                    icon: const Icon(Icons.delete_forever),
                    label: Text(
                      'Remove & Ban',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: redColor,
                      foregroundColor: isDark
                          ? AppColors.textPrimary
                          : const Color(0xFFFFFFFF),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () => _dismissReport(reportId),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(14),
                    side: BorderSide(color: brandGreen),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Icon(Icons.close, color: brandGreen),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color valueColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryText =
        isDark ? const Color(0xFFB0B0B0) : AppColors.textSecondary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: secondaryText.withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: valueColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportedMessagesTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brandGreen = isDark ? AppColors.brandGreen : AppColors.brandGreenDeep;
    final secondaryText =
        isDark ? const Color(0xFFB0B0B0) : AppColors.textSecondary;

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('reports')
          .where('contentType', isEqualTo: 'message')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: GoogleFonts.inter(
                  color: isDark ? Colors.red.shade300 : Colors.red.shade700),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: brandGreen),
          );
        }

        final reports = snapshot.data?.docs ?? [];

        if (reports.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline,
                    size: 64,
                    color: isDark
                        ? const Color(0xFF424242)
                        : AppColors.textSecondary.withOpacity(0.3)),
                const SizedBox(height: 16),
                Text(
                  'No reported messages',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: secondaryText.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final report = reports[index].data() as Map<String, dynamic>;
            final reportId = reports[index].id;
            return _buildMessageReportCard(report, reportId);
          },
        );
      },
    );
  }

  Widget _buildMessageReportCard(Map<String, dynamic> report, String reportId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brandGreen = isDark ? AppColors.brandGreen : AppColors.brandGreenDeep;
    final primaryText =
        isDark ? const Color(0xFFFFFFFF) : AppColors.textPrimary;
    final secondaryText =
        isDark ? const Color(0xFFB0B0B0) : AppColors.textSecondary;
    final cardBackground = isDark ? const Color(0xFF1A1A1A) : AppColors.surface;
    final messageBackground =
        isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF5F5F5);
    final orangeColor =
        isDark ? Colors.orange.shade400 : Colors.orange.shade700;

    final messageText =
        report['messageText'] as String? ?? '[Message content unavailable]';
    final reason = report['reason'] as String? ?? 'No reason provided';
    final reportedBy = report['reportedBy'] as String? ?? 'Unknown';
    final reportedUserId = report['reportedUserId'] as String? ?? '';
    final chatId = report['chatId'] as String? ?? '';
    final createdAt = (report['createdAt'] as Timestamp?)?.toDate();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: orangeColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: orangeColor.withOpacity(0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(Icons.message, color: orangeColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reported Message',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: primaryText,
                        ),
                      ),
                      if (createdAt != null)
                        Text(
                          DateFormat('MMM dd, yyyy • hh:mm a')
                              .format(createdAt),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: secondaryText.withOpacity(0.6),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Message Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: messageBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    messageText,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: primaryText,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildInfoRow('Reason', reason, orangeColor),
                const SizedBox(height: 12),
                _buildInfoRow('Reported By', reportedBy, secondaryText),
                const SizedBox(height: 12),
                _buildInfoRow('Sender', reportedUserId, secondaryText),
              ],
            ),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _viewChat(chatId),
                    icon: const Icon(Icons.chat),
                    label: Text(
                      'View Chat',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandGreen,
                      foregroundColor: isDark
                          ? AppColors.textPrimary
                          : const Color(0xFFFFFFFF),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _warnUser(reportId, reportedUserId),
                    icon: const Icon(Icons.warning),
                    label: Text(
                      'Warn User',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: orangeColor,
                      foregroundColor: isDark
                          ? AppColors.textPrimary
                          : const Color(0xFFFFFFFF),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () => _dismissReport(reportId),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(14),
                    side: BorderSide(color: brandGreen),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Icon(Icons.close, color: brandGreen),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getContentIcon(String contentType) {
    switch (contentType.toLowerCase()) {
      case 'message':
        return Icons.message;
      case 'profile':
        return Icons.person;
      case 'post':
        return Icons.article;
      case 'comment':
        return Icons.comment;
      default:
        return Icons.flag;
    }
  }

  Future<void> _viewContent(String contentType, String contentId) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brandGreen = isDark ? AppColors.brandGreen : AppColors.brandGreenDeep;

    // TODO: Navigate to content detail view based on type
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('View $contentType: $contentId'),
        backgroundColor: brandGreen,
      ),
    );
  }

  Future<void> _viewChat(String chatId) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brandGreen = isDark ? AppColors.brandGreen : AppColors.brandGreenDeep;

    // TODO: Navigate to chat view
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('View chat: $chatId'),
        backgroundColor: brandGreen,
      ),
    );
  }

  Future<void> _takeAction(String reportId, String contentType,
      String contentId, String userId) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? const Color(0xFFFFFFFF) : AppColors.textPrimary;
    final secondaryText =
        isDark ? const Color(0xFFB0B0B0) : AppColors.textSecondary;
    final cardBackground = isDark ? const Color(0xFF1A1A1A) : AppColors.surface;
    final redColor = isDark ? Colors.red.shade400 : Colors.red.shade700;
    final greenColor =
        isDark ? const Color(0xFF7FFA88) : const Color(0xFF66BB6A);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardBackground,
        title: Text(
          'Remove Content & Ban User',
          style: GoogleFonts.poppins(color: primaryText),
        ),
        content: Text(
          'This will remove the content and suspend the user account. Continue?',
          style: GoogleFonts.inter(color: secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style:
                    GoogleFonts.inter(color: secondaryText.withOpacity(0.6))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: redColor),
            child: Text('Remove & Ban',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.textPrimary
                        : const Color(0xFFFFFFFF))),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Update report status
        await _firestore.collection('reports').doc(reportId).update({
          'status': 'resolved',
          'action': 'removed_and_banned',
          'resolvedAt': FieldValue.serverTimestamp(),
        });

        // Suspend user
        await _firestore.collection('users').doc(userId).update({
          'status': 'suspended',
          'suspendedReason': 'Content violation',
          'suspendedAt': FieldValue.serverTimestamp(),
        });

        // TODO: Delete/hide the actual content based on contentType and contentId

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Content removed and user banned'),
              backgroundColor: greenColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: redColor,
            ),
          );
        }
      }
    }
  }

  Future<void> _warnUser(String reportId, String userId) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final greenColor =
        isDark ? const Color(0xFF7FFA88) : const Color(0xFF66BB6A);
    final redColor = isDark ? Colors.red.shade400 : Colors.red.shade700;

    try {
      // Update report status
      await _firestore.collection('reports').doc(reportId).update({
        'status': 'resolved',
        'action': 'warned',
        'resolvedAt': FieldValue.serverTimestamp(),
      });

      // TODO: Send warning notification to user
      // You can create a warnings collection or add to user document
      await _firestore.collection('users').doc(userId).update({
        'warnings': FieldValue.increment(1),
        'lastWarningAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('User has been warned'),
            backgroundColor: greenColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: redColor,
          ),
        );
      }
    }
  }

  Future<void> _dismissReport(String reportId) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final greenColor =
        isDark ? const Color(0xFF7FFA88) : const Color(0xFF66BB6A);
    final redColor = isDark ? Colors.red.shade400 : Colors.red.shade700;

    try {
      await _firestore.collection('reports').doc(reportId).update({
        'status': 'dismissed',
        'resolvedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Report dismissed'),
            backgroundColor: greenColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: redColor,
          ),
        );
      }
    }
  }
}
