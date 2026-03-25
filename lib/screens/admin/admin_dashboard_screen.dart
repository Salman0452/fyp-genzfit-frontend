import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:genzfit/models/user_model.dart';
import 'package:genzfit/screens/admin/trainer_verification_screen.dart';
import 'package:genzfit/screens/admin/user_management_screen.dart';
import 'package:genzfit/screens/admin/session_monitoring_screen.dart';
import 'package:genzfit/screens/admin/analytics_dashboard_screen.dart';
import 'package:genzfit/screens/admin/content_moderation_screen.dart';
import 'package:genzfit/screens/admin/financial_management_screen.dart';
import 'package:genzfit/screens/admin/system_settings_screen.dart';
import 'package:genzfit/utils/constants.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminDashboardScreen extends StatefulWidget {
  final UserModel admin;

  const AdminDashboardScreen({super.key, required this.admin});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int _totalUsers = 0;
  int _totalClients = 0;
  int _totalTrainers = 0;
  int _pendingVerifications = 0;
  int _activeSessions = 0;
  double _platformRevenue = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      // Get all users
      final usersSnapshot = await _firestore.collection('users').get();
      int clients = 0;
      int trainers = 0;
      int pendingVerifications = 0;

      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        final role = data['role'] as String?;

        if (role == 'client') {
          clients++;
        } else if (role == 'trainer') {
          trainers++;
          if (data['verified'] != true) {
            pendingVerifications++;
          }
        }
      }

      // Get active sessions
      final sessionsSnapshot = await _firestore
          .collection('sessions')
          .where('status', isEqualTo: 'active')
          .get();

      // Calculate platform revenue (sum of all completed sessions)
      final completedSessionsSnapshot = await _firestore
          .collection('sessions')
          .where('status', isEqualTo: 'completed')
          .get();

      double revenue = 0.0;
      for (var doc in completedSessionsSnapshot.docs) {
        final amount = doc.data()['amount'] as num?;
        if (amount != null) {
          revenue += amount.toDouble();
        }
      }

      setState(() {
        _totalClients = clients;
        _totalTrainers = trainers;
        _totalUsers = clients + trainers;
        _pendingVerifications = pendingVerifications;
        _activeSessions = sessionsSnapshot.docs.length;
        _platformRevenue = revenue;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading dashboard data: $e');
      setState(() => _isLoading = false);
    }
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
        title: Row(
          children: [
            Icon(Icons.admin_panel_settings, color: brandGreen),
            const SizedBox(width: 12),
            Text(
              'Admin Dashboard',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: primaryText),
            onPressed: _loadDashboardData,
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: CircleAvatar(
              backgroundColor: brandGreen,
              child: Text(
                widget.admin.name[0].toUpperCase(),
                style: GoogleFonts.poppins(
                  color:
                      isDark ? AppColors.textPrimary : const Color(0xFFFFFFFF),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            color: cardBackground,
            onSelected: (value) async {
              if (value == 'logout') {
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  Navigator.of(context).pushReplacementNamed('/admin-login');
                }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person, color: secondaryText),
                    const SizedBox(width: 12),
                    Text(
                      widget.admin.name,
                      style: TextStyle(color: primaryText),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout,
                        color:
                            isDark ? Colors.red.shade300 : Colors.red.shade700),
                    const SizedBox(width: 12),
                    Text(
                      'Logout',
                      style: GoogleFonts.inter(
                          color: isDark
                              ? Colors.red.shade300
                              : Colors.red.shade700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: brandGreen),
            )
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              color: brandGreen,
              backgroundColor: cardBackground,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeCard(),
                    const SizedBox(height: 24),
                    _buildStatsOverview(),
                    const SizedBox(height: 32),
                    _buildQuickActions(),
                    const SizedBox(height: 32),
                    _buildRecentActivity(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWelcomeCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brandGreen = isDark ? AppColors.brandGreen : AppColors.brandGreenDeep;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            brandGreen,
            isDark ? const Color(0xFF7FFA88) : AppColors.brandGreen
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back, ${widget.admin.name}!',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFFFFFFF),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Here\'s what\'s happening with GenZFit today',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFFFFFFFF).withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsOverview() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? const Color(0xFFFFFFFF) : AppColors.textPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Platform Overview',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: primaryText,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            // Responsive grid
            final crossAxisCount = constraints.maxWidth > 1200
                ? 4
                : constraints.maxWidth > 800
                    ? 3
                    : constraints.maxWidth > 600
                        ? 2
                        : 1;

            return GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                _buildStatCard(
                  icon: Icons.people,
                  label: 'Total Users',
                  value: _totalUsers.toString(),
                  subtitle: '$_totalClients Clients • $_totalTrainers Trainers',
                  color:
                      isDark ? AppColors.brandGreen : AppColors.brandGreenDeep,
                ),
                _buildStatCard(
                  icon: Icons.pending_actions,
                  label: 'Pending Verifications',
                  value: _pendingVerifications.toString(),
                  subtitle: 'Trainers awaiting approval',
                  color: isDark
                      ? const Color(0xFFFFD166)
                      : const Color(0xFFFFA726),
                  onTap: () => _navigateToVerification(),
                ),
                _buildStatCard(
                  icon: Icons.fitness_center,
                  label: 'Active Sessions',
                  value: _activeSessions.toString(),
                  subtitle: 'Ongoing training sessions',
                  color: isDark
                      ? const Color(0xFF7FFA88)
                      : const Color(0xFF66BB6A),
                ),
                _buildStatCard(
                  icon: Icons.attach_money,
                  label: 'Platform Revenue',
                  value: '\$${_platformRevenue.toStringAsFixed(0)}',
                  subtitle: 'Total earnings',
                  color: isDark
                      ? const Color(0xFF9C27B0)
                      : const Color(0xFF8E24AA),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? const Color(0xFFFFFFFF) : AppColors.textPrimary;
    final secondaryText =
        isDark ? const Color(0xFFB0B0B0) : AppColors.textSecondary;
    final cardBackground = isDark ? const Color(0xFF1A1A1A) : AppColors.surface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: primaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: secondaryText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: isDark
                        ? const Color(0xFF757575)
                        : AppColors.textSecondary.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? const Color(0xFFFFFFFF) : AppColors.textPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: primaryText,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 900
                ? 3
                : constraints.maxWidth > 600
                    ? 2
                    : 1;

            return GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 2.5,
              children: [
                _buildActionCard(
                  icon: Icons.verified_user,
                  title: 'Verify Trainers',
                  description: '$_pendingVerifications pending',
                  color: isDark
                      ? const Color(0xFFFFD166)
                      : const Color(0xFFFFA726),
                  onTap: _navigateToVerification,
                ),
                _buildActionCard(
                  icon: Icons.manage_accounts,
                  title: 'Manage Users',
                  description: '$_totalUsers total users',
                  color:
                      isDark ? AppColors.brandGreen : AppColors.brandGreenDeep,
                  onTap: _navigateToUserManagement,
                ),
                _buildActionCard(
                  icon: Icons.event_note,
                  title: 'Monitor Sessions',
                  description: '$_activeSessions active',
                  color: isDark
                      ? const Color(0xFF7FFA88)
                      : const Color(0xFF66BB6A),
                  onTap: _navigateToSessionMonitoring,
                ),
                _buildActionCard(
                  icon: Icons.analytics,
                  title: 'Analytics',
                  description: 'View insights',
                  color: isDark
                      ? const Color(0xFF9C27B0)
                      : const Color(0xFF8E24AA),
                  onTap: _navigateToAnalytics,
                ),
                _buildActionCard(
                  icon: Icons.flag,
                  title: 'Moderation',
                  description: 'Review reports',
                  color: isDark
                      ? const Color(0xFFEF5350)
                      : const Color(0xFFD32F2F),
                  onTap: _navigateToModeration,
                ),
                _buildActionCard(
                  icon: Icons.attach_money,
                  title: 'Finances',
                  description: 'Payouts & refunds',
                  color: isDark
                      ? const Color(0xFF7FFA88)
                      : const Color(0xFF66BB6A),
                  onTap: _navigateToFinances,
                ),
                _buildActionCard(
                  icon: Icons.settings,
                  title: 'Settings',
                  description: 'System config',
                  color: isDark
                      ? const Color(0xFF78909C)
                      : const Color(0xFF546E7A),
                  onTap: _navigateToSettings,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? const Color(0xFFFFFFFF) : AppColors.textPrimary;
    final secondaryText =
        isDark ? const Color(0xFFB0B0B0) : AppColors.textSecondary;
    final cardBackground = isDark ? const Color(0xFF1A1A1A) : AppColors.surface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: primaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: isDark
                  ? const Color(0xFF757575)
                  : AppColors.textSecondary.withOpacity(0.6),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? const Color(0xFFFFFFFF) : AppColors.textPrimary;
    final secondaryText =
        isDark ? const Color(0xFFB0B0B0) : AppColors.textSecondary;
    final cardBackground = isDark ? const Color(0xFF1A1A1A) : AppColors.surface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: primaryText,
          ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('sessions')
              .orderBy('createdAt', descending: true)
              .limit(5)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: cardBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    'No recent activity',
                    style: GoogleFonts.inter(color: secondaryText),
                  ),
                ),
              );
            }

            return Container(
              decoration: BoxDecoration(
                color: cardBackground,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                separatorBuilder: (context, index) => Divider(
                  color: isDark
                      ? const Color(0xFF424242)
                      : AppColors.textSecondary.withOpacity(0.2),
                  height: 1,
                ),
                itemBuilder: (context, index) {
                  final session = snapshot.data!.docs[index];
                  return _buildActivityItem(session);
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActivityItem(QueryDocumentSnapshot session) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? const Color(0xFFFFFFFF) : AppColors.textPrimary;
    final secondaryText =
        isDark ? const Color(0xFFB0B0B0) : AppColors.textSecondary;

    final data = session.data() as Map<String, dynamic>;
    final status = data['status'] as String? ?? 'unknown';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'requested':
        statusColor =
            isDark ? const Color(0xFFFFD166) : const Color(0xFFFFA726);
        statusIcon = Icons.pending;
        break;
      case 'active':
        statusColor =
            isDark ? const Color(0xFF7FFA88) : const Color(0xFF66BB6A);
        statusIcon = Icons.check_circle;
        break;
      case 'completed':
        statusColor =
            isDark ? const Color(0xFF42A5F5) : const Color(0xFF1E88E5);
        statusIcon = Icons.done_all;
        break;
      default:
        statusColor =
            isDark ? const Color(0xFF9E9E9E) : const Color(0xFF757575);
        statusIcon = Icons.info;
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(statusIcon, color: statusColor, size: 24),
      ),
      title: Text(
        'Session ${status.toUpperCase()}',
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: primaryText,
        ),
      ),
      subtitle: Text(
        createdAt != null
            ? '${createdAt.day}/${createdAt.month}/${createdAt.year} at ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}'
            : 'Unknown date',
        style: GoogleFonts.inter(
          fontSize: 12,
          color: secondaryText,
        ),
      ),
      trailing: Chip(
        label: Text(
          status.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: statusColor,
          ),
        ),
        backgroundColor: statusColor.withOpacity(0.1),
        side: BorderSide(color: statusColor.withOpacity(0.3)),
      ),
    );
  }

  void _navigateToVerification() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const TrainerVerificationScreen(),
      ),
    );
  }

  void _navigateToUserManagement() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const UserManagementScreen(),
      ),
    );
  }

  void _navigateToSessionMonitoring() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SessionMonitoringScreen(),
      ),
    );
  }

  void _navigateToAnalytics() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AnalyticsDashboardScreen(),
      ),
    );
  }

  void _navigateToModeration() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ContentModerationScreen(),
      ),
    );
  }

  void _navigateToFinances() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const FinancialManagementScreen(),
      ),
    );
  }

  void _navigateToSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SystemSettingsScreen(),
      ),
    );
  }
}
