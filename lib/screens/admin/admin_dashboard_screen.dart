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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF171917),
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.admin_panel_settings, color: Color(0xFF83BCB5)),
            const SizedBox(width: 12),
            Text(
              'Admin Dashboard',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadDashboardData,
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: CircleAvatar(
              backgroundColor: const Color(0xFF83BCB5),
              child: Text(
                widget.admin.name[0].toUpperCase(),
                style: GoogleFonts.poppins(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            color: const Color(0xFF171917),
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
                    const Icon(Icons.person, color: Colors.white60),
                    const SizedBox(width: 12),
                    Text(
                      widget.admin.name,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    const Icon(Icons.logout, color: Colors.red),
                    const SizedBox(width: 12),
                    Text(
                      'Logout',
                      style: GoogleFonts.inter(color: Colors.red),
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
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF83BCB5)),
            )
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              color: const Color(0xFF83BCB5),
              backgroundColor: const Color(0xFF171917),
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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF83BCB5), Color(0xFF7FFA88)],
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
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Here\'s what\'s happening with GenZFit today',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Platform Overview',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            // Responsive grid
            final crossAxisCount = constraints.maxWidth > 1200 ? 4 : 
                                   constraints.maxWidth > 800 ? 3 : 
                                   constraints.maxWidth > 600 ? 2 : 1;
            
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
                  color: const Color(0xFF83BCB5),
                ),
                _buildStatCard(
                  icon: Icons.pending_actions,
                  label: 'Pending Verifications',
                  value: _pendingVerifications.toString(),
                  subtitle: 'Trainers awaiting approval',
                  color: const Color(0xFFFFD166),
                  onTap: () => _navigateToVerification(),
                ),
                _buildStatCard(
                  icon: Icons.fitness_center,
                  label: 'Active Sessions',
                  value: _activeSessions.toString(),
                  subtitle: 'Ongoing training sessions',
                  color: const Color(0xFF7FFA88),
                ),
                _buildStatCard(
                  icon: Icons.attach_money,
                  label: 'Platform Revenue',
                  value: '\$${_platformRevenue.toStringAsFixed(0)}',
                  subtitle: 'Total earnings',
                  color: const Color(0xFF9C27B0),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF171917),
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
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white38,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 900 ? 3 : 
                                   constraints.maxWidth > 600 ? 2 : 1;
            
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
                  color: const Color(0xFFFFD166),
                  onTap: _navigateToVerification,
                ),
                _buildActionCard(
                  icon: Icons.manage_accounts,
                  title: 'Manage Users',
                  description: '$_totalUsers total users',
                  color: const Color(0xFF83BCB5),
                  onTap: _navigateToUserManagement,
                ),
                _buildActionCard(
                  icon: Icons.event_note,
                  title: 'Monitor Sessions',
                  description: '$_activeSessions active',
                  color: const Color(0xFF7FFA88),
                  onTap: _navigateToSessionMonitoring,
                ),
                _buildActionCard(
                  icon: Icons.analytics,
                  title: 'Analytics',
                  description: 'View insights',
                  color: Colors.purple,
                  onTap: _navigateToAnalytics,
                ),
                _buildActionCard(
                  icon: Icons.flag,
                  title: 'Moderation',
                  description: 'Review reports',
                  color: Colors.red,
                  onTap: _navigateToModeration,
                ),
                _buildActionCard(
                  icon: Icons.attach_money,
                  title: 'Finances',
                  description: 'Payouts & refunds',
                  color: const Color(0xFF7FFA88),
                  onTap: _navigateToFinances,
                ),
                _buildActionCard(
                  icon: Icons.settings,
                  title: 'Settings',
                  description: 'System config',
                  color: Colors.blueGrey,
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF171917),
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
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white38,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
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
                  color: const Color(0xFF171917),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    'No recent activity',
                    style: GoogleFonts.inter(color: Colors.white60),
                  ),
                ),
              );
            }

            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF171917),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                separatorBuilder: (context, index) => const Divider(
                  color: Colors.white12,
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
    final data = session.data() as Map<String, dynamic>;
    final status = data['status'] as String? ?? 'unknown';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'requested':
        statusColor = const Color(0xFFFFD166);
        statusIcon = Icons.pending;
        break;
      case 'active':
        statusColor = const Color(0xFF7FFA88);
        statusIcon = Icons.check_circle;
        break;
      case 'completed':
        statusColor = Colors.blue;
        statusIcon = Icons.done_all;
        break;
      default:
        statusColor = Colors.grey;
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
          color: Colors.white,
        ),
      ),
      subtitle: Text(
        createdAt != null 
            ? '${createdAt.day}/${createdAt.month}/${createdAt.year} at ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}'
            : 'Unknown date',
        style: GoogleFonts.inter(
          fontSize: 12,
          color: Colors.white60,
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
