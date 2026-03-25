import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:genzfit/utils/constants.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../utils/download_helper.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  State<AnalyticsDashboardScreen> createState() =>
      _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _userGrowthData = [];
  List<Map<String, dynamic>> _revenueData = [];
  List<Map<String, dynamic>> _sessionStatsData = [];
  bool _isLoading = true;
  String _selectedPeriod = '7days'; // 7days, 30days, 90days, year

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      DateTime startDate;

      switch (_selectedPeriod) {
        case '7days':
          startDate = now.subtract(const Duration(days: 7));
          break;
        case '30days':
          startDate = now.subtract(const Duration(days: 30));
          break;
        case '90days':
          startDate = now.subtract(const Duration(days: 90));
          break;
        case 'year':
          startDate = DateTime(now.year - 1, now.month, now.day);
          break;
        default:
          startDate = now.subtract(const Duration(days: 30));
      }

      // Load user growth data
      await _loadUserGrowthData(startDate);

      // Load revenue data
      await _loadRevenueData(startDate);

      // Load session statistics
      await _loadSessionStats(startDate);

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading analytics: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUserGrowthData(DateTime startDate) async {
    final usersSnapshot = await _firestore.collection('users').get();

    // Group by date
    Map<String, Map<String, int>> dailyGrowth = {};

    for (var doc in usersSnapshot.docs) {
      final data = doc.data();
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      if (createdAt != null && createdAt.isAfter(startDate)) {
        final dateKey = DateFormat('yyyy-MM-dd').format(createdAt);
        dailyGrowth[dateKey] ??= {'clients': 0, 'trainers': 0, 'total': 0};

        final role = data['role'] as String?;
        if (role == 'client') {
          dailyGrowth[dateKey]!['clients'] =
              dailyGrowth[dateKey]!['clients']! + 1;
        } else if (role == 'trainer') {
          dailyGrowth[dateKey]!['trainers'] =
              dailyGrowth[dateKey]!['trainers']! + 1;
        }
        dailyGrowth[dateKey]!['total'] = dailyGrowth[dateKey]!['total']! + 1;
      }
    }

    _userGrowthData = dailyGrowth.entries
        .map((e) => {'date': e.key, ...e.value})
        .toList()
      ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
  }

  Future<void> _loadRevenueData(DateTime startDate) async {
    final sessionsSnapshot = await _firestore
        .collection('sessions')
        .where('status', isEqualTo: 'completed')
        .get();

    // Group by date
    Map<String, double> dailyRevenue = {};

    for (var doc in sessionsSnapshot.docs) {
      final data = doc.data();
      final completedAt = (data['completedAt'] as Timestamp?)?.toDate();
      final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;

      if (completedAt != null && completedAt.isAfter(startDate)) {
        final dateKey = DateFormat('yyyy-MM-dd').format(completedAt);
        dailyRevenue[dateKey] = (dailyRevenue[dateKey] ?? 0.0) + amount;
      }
    }

    _revenueData = dailyRevenue.entries
        .map((e) => {'date': e.key, 'revenue': e.value})
        .toList()
      ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
  }

  Future<void> _loadSessionStats(DateTime startDate) async {
    final sessionsSnapshot = await _firestore.collection('sessions').get();

    // Group by status and date
    Map<String, Map<String, int>> dailyStats = {};

    for (var doc in sessionsSnapshot.docs) {
      final data = doc.data();
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      final status = data['status'] as String?;

      if (createdAt != null && createdAt.isAfter(startDate) && status != null) {
        final dateKey = DateFormat('yyyy-MM-dd').format(createdAt);
        dailyStats[dateKey] ??= {
          'requested': 0,
          'active': 0,
          'completed': 0,
          'cancelled': 0,
          'total': 0,
        };

        dailyStats[dateKey]![status] = (dailyStats[dateKey]![status] ?? 0) + 1;
        dailyStats[dateKey]!['total'] = dailyStats[dateKey]!['total']! + 1;
      }
    }

    _sessionStatsData = dailyStats.entries
        .map((e) => {'date': e.key, ...e.value})
        .toList()
      ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
  }

  Future<void> _exportToCSV() async {
    try {
      final csvData = StringBuffer();

      // Header
      csvData.writeln(
          'GenZFit Analytics Report - ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}');
      csvData.writeln();

      // User Growth Section
      csvData.writeln('User Growth');
      csvData.writeln('Date,Clients,Trainers,Total');
      for (var data in _userGrowthData) {
        csvData.writeln(
            '${data['date']},${data['clients']},${data['trainers']},${data['total']}');
      }
      csvData.writeln();

      // Revenue Section
      csvData.writeln('Revenue');
      csvData.writeln('Date,Revenue');
      for (var data in _revenueData) {
        csvData
            .writeln('${data['date']},\$${data['revenue'].toStringAsFixed(2)}');
      }
      csvData.writeln();

      // Session Stats Section
      csvData.writeln('Session Statistics');
      csvData.writeln('Date,Requested,Active,Completed,Cancelled,Total');
      for (var data in _sessionStatsData) {
        csvData.writeln(
            '${data['date']},${data['requested']},${data['active']},${data['completed']},${data['cancelled']},${data['total']}');
      }

      // Download file
      if (kIsWeb) {
        downloadCsvFile(
          csvData.toString(),
          'genzfit_analytics_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Analytics report exported successfully'),
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF7FFA88)
                : const Color(0xFF66BB6A),
          ),
        );
      }
    } catch (e) {
      print('Error exporting CSV: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export: $e'),
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.red.shade700
                : Colors.red.shade900,
          ),
        );
      }
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: primaryText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Analytics Dashboard',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: primaryText,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.file_download, color: brandGreen),
            color: cardBackground,
            onSelected: (value) {
              if (value == 'csv') _exportToCSV();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'csv',
                child: Row(
                  children: [
                    Icon(Icons.table_chart, color: brandGreen),
                    const SizedBox(width: 12),
                    Text(
                      'Export CSV',
                      style: GoogleFonts.inter(color: primaryText),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: brandGreen),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPeriodSelector(),
                  const SizedBox(height: 24),
                  _buildUserGrowthChart(),
                  const SizedBox(height: 32),
                  _buildRevenueChart(),
                  const SizedBox(height: 32),
                  _buildSessionStatsChart(),
                ],
              ),
            ),
    );
  }

  Widget _buildPeriodSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brandGreen = isDark ? AppColors.brandGreen : AppColors.brandGreenDeep;
    final cardBackground = isDark ? const Color(0xFF1A1A1A) : AppColors.surface;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPeriodButton('7 Days', '7days'),
          _buildPeriodButton('30 Days', '30days'),
          _buildPeriodButton('90 Days', '90days'),
          _buildPeriodButton('1 Year', 'year'),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brandGreen = isDark ? AppColors.brandGreen : AppColors.brandGreenDeep;
    final primaryText =
        isDark ? const Color(0xFFFFFFFF) : AppColors.textPrimary;

    final isSelected = _selectedPeriod == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedPeriod = value);
          _loadAnalyticsData();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected ? brandGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: isSelected
                  ? (isDark ? AppColors.textPrimary : const Color(0xFFFFFFFF))
                  : primaryText,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserGrowthChart() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brandGreen = isDark ? AppColors.brandGreen : AppColors.brandGreenDeep;
    final primaryText =
        isDark ? const Color(0xFFFFFFFF) : AppColors.textPrimary;
    final secondaryText =
        isDark ? const Color(0xFFB0B0B0) : AppColors.textSecondary;
    final cardBackground = isDark ? const Color(0xFF1A1A1A) : AppColors.surface;

    final totalUsers = _userGrowthData.fold<int>(
        0, (sum, data) => sum + (data['total'] as int));
    final totalClients = _userGrowthData.fold<int>(
        0, (sum, data) => sum + (data['clients'] as int));
    final totalTrainers = _userGrowthData.fold<int>(
        0, (sum, data) => sum + (data['trainers'] as int));

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'User Growth',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryText,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: brandGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Total: $totalUsers',
                  style: GoogleFonts.inter(
                    color: brandGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildLegendItem(
                  isDark ? const Color(0xFF42A5F5) : const Color(0xFF1E88E5),
                  'Clients',
                  totalClients),
              const SizedBox(width: 24),
              _buildLegendItem(
                  isDark ? const Color(0xFFFFA726) : const Color(0xFFF57C00),
                  'Trainers',
                  totalTrainers),
            ],
          ),
          const SizedBox(height: 24),
          if (_userGrowthData.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No user growth data for this period',
                  style: GoogleFonts.inter(
                      color: isDark
                          ? const Color(0xFF757575)
                          : AppColors.textSecondary.withOpacity(0.6)),
                ),
              ),
            )
          else
            _buildSimpleBarChart(_userGrowthData, 'total', 200),
        ],
      ),
    );
  }

  Widget _buildRevenueChart() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? const Color(0xFFFFFFFF) : AppColors.textPrimary;
    final secondaryText =
        isDark ? const Color(0xFFB0B0B0) : AppColors.textSecondary;
    final cardBackground = isDark ? const Color(0xFF1A1A1A) : AppColors.surface;

    final totalRevenue = _revenueData.fold<double>(
        0, (sum, data) => sum + (data['revenue'] as double));

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Revenue',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryText,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (isDark
                          ? const Color(0xFF7FFA88)
                          : const Color(0xFF66BB6A))
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '\$${totalRevenue.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    color: isDark
                        ? const Color(0xFF7FFA88)
                        : const Color(0xFF66BB6A),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_revenueData.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No revenue data for this period',
                  style: GoogleFonts.inter(
                      color: isDark
                          ? const Color(0xFF757575)
                          : AppColors.textSecondary.withOpacity(0.6)),
                ),
              ),
            )
          else
            _buildSimpleBarChart(_revenueData, 'revenue', 200),
        ],
      ),
    );
  }

  Widget _buildSessionStatsChart() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? const Color(0xFFFFFFFF) : AppColors.textPrimary;
    final secondaryText =
        isDark ? const Color(0xFFB0B0B0) : AppColors.textSecondary;
    final cardBackground = isDark ? const Color(0xFF1A1A1A) : AppColors.surface;

    final totalSessions = _sessionStatsData.fold<int>(
        0, (sum, data) => sum + (data['total'] as int));
    final completed = _sessionStatsData.fold<int>(
        0, (sum, data) => sum + (data['completed'] as int? ?? 0));
    final cancelled = _sessionStatsData.fold<int>(
        0, (sum, data) => sum + (data['cancelled'] as int? ?? 0));

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Session Statistics',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryText,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (isDark
                          ? const Color(0xFF9C27B0)
                          : const Color(0xFF8E24AA))
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Total: $totalSessions',
                  style: GoogleFonts.inter(
                    color: isDark
                        ? const Color(0xFF9C27B0)
                        : const Color(0xFF8E24AA),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildLegendItem(
                  isDark ? const Color(0xFF7FFA88) : const Color(0xFF66BB6A),
                  'Completed',
                  completed),
              const SizedBox(width: 24),
              _buildLegendItem(
                  isDark ? Colors.red.shade300 : Colors.red.shade700,
                  'Cancelled',
                  cancelled),
            ],
          ),
          const SizedBox(height: 24),
          if (_sessionStatsData.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No session data for this period',
                  style: GoogleFonts.inter(
                      color: isDark
                          ? const Color(0xFF757575)
                          : AppColors.textSecondary.withOpacity(0.6)),
                ),
              ),
            )
          else
            _buildSimpleBarChart(_sessionStatsData, 'total', 200),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, int count) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryText =
        isDark ? const Color(0xFFB0B0B0) : AppColors.textSecondary;

    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$label: $count',
          style: GoogleFonts.inter(
            color: secondaryText,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleBarChart(
      List<Map<String, dynamic>> data, String valueKey, double height) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brandGreen = isDark ? AppColors.brandGreen : AppColors.brandGreenDeep;
    final secondaryText =
        isDark ? const Color(0xFFB0B0B0) : AppColors.textSecondary;

    if (data.isEmpty) return const SizedBox();

    final maxValue = data.fold<num>(0, (max, item) {
      final value = item[valueKey];
      if (value is num && value > max) return value;
      return max;
    }).toDouble();

    return SizedBox(
      height: height,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: data.length,
        itemBuilder: (context, index) {
          final item = data[index];
          final value = (item[valueKey] as num).toDouble();
          final percentage = maxValue > 0 ? value / maxValue : 0;
          final date = DateTime.parse(item['date'] as String);

          return Container(
            width: 60,
            margin: const EdgeInsets.only(right: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  valueKey == 'revenue'
                      ? '\$${value.toStringAsFixed(0)}'
                      : value.toStringAsFixed(0),
                  style: GoogleFonts.inter(
                    color: secondaryText,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: 40,
                      height: (height - 40) * percentage,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            brandGreen,
                            isDark
                                ? const Color(0xFF7FFA88)
                                : AppColors.brandGreen,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('MMM\nd').format(date),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: isDark
                        ? const Color(0xFF757575)
                        : AppColors.textSecondary.withOpacity(0.6),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
