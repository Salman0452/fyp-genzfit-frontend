import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:genzfit/models/session_model.dart';
import 'package:genzfit/models/user_model.dart';
import 'package:intl/intl.dart';
import 'package:genzfit/utils/constants.dart';

class SessionMonitoringScreen extends StatefulWidget {
  const SessionMonitoringScreen({super.key});

  @override
  State<SessionMonitoringScreen> createState() =>
      _SessionMonitoringScreenState();
}

class _SessionMonitoringScreenState extends State<SessionMonitoringScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _statusFilter = 'all'; // all, requested, active, completed, cancelled

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF171917)
            : AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFFFFFFF)
                  : AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Session Monitoring',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFFFFFFFF)
                : AppColors.textPrimary,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: _buildSessionsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(
                'All',
                'all',
                Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFFFFFFF)
                    : AppColors.textPrimary),
            const SizedBox(width: 8),
            _buildFilterChip('Requested', 'requested', const Color(0xFFFFD166)),
            const SizedBox(width: 8),
            _buildFilterChip(
                'Active',
                'active',
                Theme.of(context).brightness == Brightness.dark
                    ? AppColors.brandGreen
                    : AppColors.brandGreenDeep),
            const SizedBox(width: 8),
            _buildFilterChip(
                'Completed',
                'completed',
                Theme.of(context).brightness == Brightness.dark
                    ? Colors.blue
                    : Colors.blue.shade700),
            const SizedBox(width: 8),
            _buildFilterChip('Cancelled', 'cancelled', Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, Color color) {
    final isSelected = _statusFilter == value;
    return FilterChip(
      label: Text(
        label,
        style: GoogleFonts.inter(
          color: isSelected
              ? (Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1A1A1A)
                  : AppColors.textPrimary)
              : (Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFFFFFFF)
                  : AppColors.textPrimary),
          fontWeight: FontWeight.w600,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _statusFilter = value);
      },
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF171917)
          : AppColors.surface,
      selectedColor: color,
      checkmarkColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1A1A1A)
          : AppColors.textPrimary,
      side: BorderSide(
        color: isSelected
            ? color
            : (Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFB0B0B0)
                    : AppColors.textSecondary)
                .withOpacity(0.24),
      ),
    );
  }

  Widget _buildSessionsList() {
    Query query = _firestore.collection('sessions');

    if (_statusFilter != 'all') {
      query = query.where('status', isEqualTo: _statusFilter);
    }

    query = query.orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.brandGreen
                    : AppColors.brandGreenDeep),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_note,
                  size: 80,
                  color: (Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFFFFFFF)
                          : AppColors.textPrimary)
                      .withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No sessions found',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: (Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFFFFFFF)
                            : AppColors.textPrimary)
                        .withOpacity(0.6),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final sessionDoc = snapshot.data!.docs[index];
            final session = SessionModel.fromFirestore(sessionDoc);
            return _buildSessionCard(session);
          },
        );
      },
    );
  }

  Widget _buildSessionCard(SessionModel session) {
    Color statusColor;
    IconData statusIcon;

    switch (session.status) {
      case SessionStatus.requested:
        statusColor = const Color(0xFFFFD166);
        statusIcon = Icons.pending;
        break;
      case SessionStatus.active:
        statusColor = Theme.of(context).brightness == Brightness.dark
            ? AppColors.brandGreen
            : AppColors.brandGreenDeep;
        statusIcon = Icons.check_circle;
        break;
      case SessionStatus.completed:
        statusColor = Theme.of(context).brightness == Brightness.dark
            ? Colors.blue
            : Colors.blue.shade700;
        statusIcon = Icons.done_all;
        break;
      case SessionStatus.rejected:
      case SessionStatus.cancelled:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
    }

    return Card(
      color: Theme.of(context).brightness == Brightness.dark
          ? Color(0xFF171917)
          : AppColors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: statusColor.withOpacity(0.3)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.all(16),
        childrenPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(statusIcon, color: statusColor, size: 24),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Session ${session.id.substring(0, 8)}...',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFFFFFFF)
                      : AppColors.textPrimary,
                ),
              ),
            ),
            Chip(
              label: Text(
                SessionModel.statusToString(session.status).toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
              backgroundColor: statusColor.withOpacity(0.1),
              side: BorderSide(color: statusColor.withOpacity(0.3)),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              'Created: ${DateFormat('MMM d, yyyy • HH:mm').format(session.createdAt)}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: (Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFFFFFFF)
                        : AppColors.textPrimary)
                    .withOpacity(0.6),
              ),
            ),
            if (session.amount != null) ...[
              const SizedBox(height: 4),
              Text(
                'Amount: \$${session.amount!.toStringAsFixed(2)}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.brandGreen
                      : AppColors.brandGreenDeep,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        children: [
          _buildSessionDetails(session),
        ],
      ),
    );
  }

  Widget _buildSessionDetails(SessionModel session) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(
            color: (Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFFFFFFF)
                    : AppColors.textPrimary)
                .withOpacity(0.12)),
        const SizedBox(height: 16),

        // Client and Trainer Info
        Row(
          children: [
            Expanded(
              child: _buildUserInfo('Client', session.clientId),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildUserInfo('Trainer', session.trainerId),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Session Details
        if (session.startDate != null) ...[
          _buildDetailRow(
            'Start Date',
            DateFormat('MMM d, yyyy').format(session.startDate!),
          ),
          const SizedBox(height: 12),
        ],
        if (session.endDate != null) ...[
          _buildDetailRow(
            'End Date',
            DateFormat('MMM d, yyyy').format(session.endDate!),
          ),
          const SizedBox(height: 12),
        ],
        if (session.notes != null && session.notes!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Notes:',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFFFFFFF)
                  : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1F2120)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              session.notes!,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: (Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFFFFFFF)
                        : AppColors.textPrimary)
                    .withOpacity(0.7),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),

        // Admin Actions
        _buildAdminActions(session),
      ],
    );
  }

  Widget _buildUserInfo(String label, String userId) {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: (Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFFFFFFF)
                          : AppColors.textPrimary)
                      .withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 8),
              CircularProgressIndicator(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.brandGreen
                    : AppColors.brandGreenDeep,
                strokeWidth: 2,
              ),
            ],
          );
        }

        if (!snapshot.data!.exists) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: (Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFFFFFFF)
                          : AppColors.textPrimary)
                      .withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'User not found',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.red,
                ),
              ),
            ],
          );
        }

        final user = UserModel.fromFirestore(snapshot.data!);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: (Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFFFFFFF)
                        : AppColors.textPrimary)
                    .withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundImage: user.avatarUrl != null
                      ? NetworkImage(user.avatarUrl!)
                      : null,
                  backgroundColor:
                      Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF1F2120)
                          : AppColors.surface,
                  child: user.avatarUrl == null
                      ? Text(
                          user.name[0].toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFFFFFFFF)
                                    : AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFFFFFFFF)
                              : AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        user.email,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color:
                              (Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFFFFFFFF)
                                      : AppColors.textPrimary)
                                  .withOpacity(0.6),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: (Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFFFFFFF)
                    : AppColors.textPrimary)
                .withOpacity(0.6),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFFFFFFFF)
                : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildAdminActions(SessionModel session) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Admin Actions',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFFFFFFFF)
                : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (session.status == SessionStatus.requested) ...[
              ElevatedButton.icon(
                onPressed: () => _forceActivateSession(session),
                icon: const Icon(Icons.play_arrow, size: 18),
                label: Text(
                  'Activate',
                  style: GoogleFonts.inter(fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      Theme.of(context).brightness == Brightness.dark
                          ? AppColors.brandGreen
                          : AppColors.brandGreenDeep,
                  foregroundColor:
                      Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFFFFFFF)
                          : AppColors.textPrimary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _forceRejectSession(session),
                icon: const Icon(Icons.cancel, size: 18),
                label: Text(
                  'Reject',
                  style: GoogleFonts.inter(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
            if (session.status == SessionStatus.active) ...[
              ElevatedButton.icon(
                onPressed: () => _forceCompleteSession(session),
                icon: const Icon(Icons.done_all, size: 18),
                label: Text(
                  'Complete',
                  style: GoogleFonts.inter(fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      Theme.of(context).brightness == Brightness.dark
                          ? Colors.blue
                          : Colors.blue.shade700,
                  foregroundColor:
                      Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFFFFFFF)
                          : AppColors.textPrimary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _forceCancelSession(session),
                icon: const Icon(Icons.stop, size: 18),
                label: Text(
                  'Cancel',
                  style: GoogleFonts.inter(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
            OutlinedButton.icon(
              onPressed: () => _viewFullDetails(session),
              icon: const Icon(Icons.info_outline, size: 18),
              label: Text(
                'Full Details',
                style: GoogleFonts.inter(fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.brandGreen
                    : AppColors.brandGreenDeep,
                side: BorderSide(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.brandGreen
                        : AppColors.brandGreenDeep),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _forceActivateSession(SessionModel session) async {
    final confirmed = await _showConfirmDialog(
      'Activate Session?',
      'This will force-activate the session.',
    );

    if (confirmed == true) {
      try {
        await _firestore.collection('sessions').doc(session.id).update({
          'status': 'active',
          'startDate': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Session activated'),
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.brandGreen
                  : AppColors.brandGreenDeep,
            ),
          );
        }
      } catch (e) {
        _showError(e.toString());
      }
    }
  }

  Future<void> _forceRejectSession(SessionModel session) async {
    final confirmed = await _showConfirmDialog(
      'Reject Session?',
      'This will reject the session request.',
    );

    if (confirmed == true) {
      try {
        await _firestore.collection('sessions').doc(session.id).update({
          'status': 'rejected',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Session rejected'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        _showError(e.toString());
      }
    }
  }

  Future<void> _forceCompleteSession(SessionModel session) async {
    final confirmed = await _showConfirmDialog(
      'Complete Session?',
      'This will mark the session as completed.',
    );

    if (confirmed == true) {
      try {
        await _firestore.collection('sessions').doc(session.id).update({
          'status': 'completed',
          'endDate': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Session completed'),
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.blue
                  : Colors.blue.shade700,
            ),
          );
        }
      } catch (e) {
        _showError(e.toString());
      }
    }
  }

  Future<void> _forceCancelSession(SessionModel session) async {
    final confirmed = await _showConfirmDialog(
      'Cancel Session?',
      'This will cancel the active session.',
    );

    if (confirmed == true) {
      try {
        await _firestore.collection('sessions').doc(session.id).update({
          'status': 'cancelled',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Session cancelled'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        _showError(e.toString());
      }
    }
  }

  void _viewFullDetails(SessionModel session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF171917)
            : AppColors.surface,
        title: Text('Session Details',
            style: GoogleFonts.poppins(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFFFFFFF)
                    : AppColors.textPrimary)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogRow('Session ID', session.id),
              _buildDialogRow('Client ID', session.clientId),
              _buildDialogRow('Trainer ID', session.trainerId),
              _buildDialogRow(
                  'Status', SessionModel.statusToString(session.status)),
              if (session.amount != null)
                _buildDialogRow(
                    'Amount', '\$${session.amount!.toStringAsFixed(2)}'),
              _buildDialogRow('Created',
                  DateFormat('MMM d, yyyy HH:mm').format(session.createdAt)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close',
                style: GoogleFonts.inter(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFFFFFFF)
                        : AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: (Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFFFFFFF)
                      : AppColors.textPrimary)
                  .withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFFFFFFF)
                  : AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showConfirmDialog(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF171917)
            : AppColors.surface,
        title: Text(title,
            style: GoogleFonts.poppins(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFFFFFFF)
                    : AppColors.textPrimary)),
        content: Text(message,
            style: GoogleFonts.inter(
                color: (Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFFFFFFF)
                        : AppColors.textPrimary)
                    .withOpacity(0.7))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFFFFFFF)
                        : AppColors.textPrimary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Confirm',
                style: GoogleFonts.inter(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.brandGreen
                        : AppColors.brandGreenDeep)),
          ),
        ],
      ),
    );
  }

  void _showError(String error) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
