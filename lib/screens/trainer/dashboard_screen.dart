import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:genzfit/models/user_model.dart';
import 'package:genzfit/models/session_model.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class TrainerDashboardScreen extends StatefulWidget {
  final UserModel trainer;

  const TrainerDashboardScreen({super.key, required this.trainer});

  @override
  State<TrainerDashboardScreen> createState() => _TrainerDashboardScreenState();
}

class _TrainerDashboardScreenState extends State<TrainerDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  int _totalClients = 0;
  int _activeSessions = 0;
  double _totalEarnings = 0.0;
  int _pendingRequests = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    
    try {
      // Get all sessions for this trainer
      final sessionsSnapshot = await _firestore
          .collection('sessions')
          .where('trainerId', isEqualTo: widget.trainer.id)
          .get();

      int clients = 0;
      int active = 0;
      double earnings = 0.0;
      int pending = 0;
      Set<String> uniqueClients = {};

      for (var doc in sessionsSnapshot.docs) {
        final session = SessionModel.fromFirestore(doc);
        
        uniqueClients.add(session.clientId);
        
        if (session.status == SessionStatus.active) {
          active++;
        }
        
        if (session.status == SessionStatus.requested) {
          pending++;
        }
        
        if (session.status == SessionStatus.completed && session.amount != null) {
          earnings += session.amount!;
        }
      }

      clients = uniqueClients.length;

      setState(() {
        _totalClients = clients;
        _activeSessions = active;
        _totalEarnings = earnings;
        _pendingRequests = pending;
        _isLoading = false;
      });

      // Update trainer's client count in Firestore
      await _firestore.collection('users').doc(widget.trainer.id).update({
        'clients': clients,
        'totalEarnings': earnings,
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
        backgroundColor: const Color(0xFF1C1C1E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Dashboard',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00D4FF)),
            )
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              color: const Color(0xFF00D4FF),
              backgroundColor: const Color(0xFF1C1C1E),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsOverview(),
                    const SizedBox(height: 24),
                    _buildPendingRequests(),
                    const SizedBox(height: 24),
                    _buildActiveClients(),
                    const SizedBox(height: 24),
                    _buildRecentSessions(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatsOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.people,
                label: 'Total Clients',
                value: _totalClients.toString(),
                color: const Color(0xFF00D4FF),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.fitness_center,
                label: 'Active Sessions',
                value: _activeSessions.toString(),
                color: const Color(0xFF0066FF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.attach_money,
                label: 'Total Earnings',
                value: '\$${_totalEarnings.toStringAsFixed(0)}',
                color: const Color(0xFF00C853),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.pending_actions,
                label: 'Pending Requests',
                value: _pendingRequests.toString(),
                color: const Color(0xFFFF9800),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingRequests() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Pending Requests',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (_pendingRequests > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _pendingRequests.toString(),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('sessions')
              .where('trainerId', isEqualTo: widget.trainer.id)
              .where('status', isEqualTo: 'requested')
              .orderBy('createdAt', descending: true)
              .limit(3)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    'No pending requests',
                    style: GoogleFonts.inter(color: Colors.white60),
                  ),
                ),
              );
            }

            return Column(
              children: snapshot.data!.docs.map((doc) {
                final session = SessionModel.fromFirestore(doc);
                return _buildRequestCard(session);
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRequestCard(SessionModel session) {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('users').doc(session.clientId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox();
        }

        final clientData = snapshot.data!.data() as Map<String, dynamic>;
        final clientName = clientData['name'] ?? 'Unknown';
        final clientAvatar = clientData['avatarUrl'];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFF9800).withOpacity(0.3)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: clientAvatar != null
                    ? NetworkImage(clientAvatar)
                    : null,
                backgroundColor: const Color(0xFF2C2C2E),
                child: clientAvatar == null
                    ? Text(
                        clientName[0].toUpperCase(),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clientName,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      DateFormat('MMM d, y').format(session.createdAt),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Color(0xFF00C853)),
                    onPressed: () => _acceptRequest(session),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    onPressed: () => _rejectRequest(session),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActiveClients() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Active Clients',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('sessions')
              .where('trainerId', isEqualTo: widget.trainer.id)
              .where('status', isEqualTo: 'active')
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    'No active clients',
                    style: GoogleFonts.inter(color: Colors.white60),
                  ),
                ),
              );
            }

            return Column(
              children: snapshot.data!.docs.take(5).map((doc) {
                final session = SessionModel.fromFirestore(doc);
                return _buildClientCard(session);
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildClientCard(SessionModel session) {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('users').doc(session.clientId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final clientData = snapshot.data!.data() as Map<String, dynamic>;
        final clientName = clientData['name'] ?? 'Unknown';
        final clientAvatar = clientData['avatarUrl'];
        final goals = clientData['goals'] ?? 'fitness';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: clientAvatar != null
                    ? NetworkImage(clientAvatar)
                    : null,
                backgroundColor: const Color(0xFF2C2C2E),
                child: clientAvatar == null
                    ? Text(
                        clientName[0].toUpperCase(),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clientName,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Goal: ${goals}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF00D4FF)),
                onPressed: () {
                  // Navigate to chat
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentSessions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Sessions',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('sessions')
              .where('trainerId', isEqualTo: widget.trainer.id)
              .orderBy('createdAt', descending: true)
              .limit(10)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    'No sessions yet',
                    style: GoogleFonts.inter(color: Colors.white60),
                  ),
                ),
              );
            }

            return Column(
              children: snapshot.data!.docs.map((doc) {
                final session = SessionModel.fromFirestore(doc);
                return _buildSessionCard(session);
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSessionCard(SessionModel session) {
    Color statusColor;
    IconData statusIcon;

    switch (session.status) {
      case SessionStatus.active:
        statusColor = const Color(0xFF00C853);
        statusIcon = Icons.check_circle;
        break;
      case SessionStatus.completed:
        statusColor = Colors.blue;
        statusIcon = Icons.done_all;
        break;
      case SessionStatus.requested:
        statusColor = const Color(0xFFFF9800);
        statusIcon = Icons.pending;
        break;
      case SessionStatus.rejected:
      case SessionStatus.cancelled:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(statusIcon, color: statusColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  SessionModel.statusToString(session.status).toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
                Text(
                  DateFormat('MMM d, y').format(session.createdAt),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ),
          if (session.amount != null)
            Text(
              '\$${session.amount!.toStringAsFixed(0)}',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _acceptRequest(SessionModel session) async {
    try {
      await _firestore.collection('sessions').doc(session.id).update({
        'status': 'active',
        'updatedAt': FieldValue.serverTimestamp(),
        'startDate': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request accepted!'),
          backgroundColor: const Color(0xFF00C853),
        ),
      );

      _loadDashboardData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to accept request'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectRequest(SessionModel session) async {
    try {
      await _firestore.collection('sessions').doc(session.id).update({
        'status': 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request rejected'),
          backgroundColor: Colors.red.shade700,
        ),
      );

      _loadDashboardData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reject request'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
