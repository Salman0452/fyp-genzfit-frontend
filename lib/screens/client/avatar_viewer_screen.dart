// ignore_for_file: unused_import
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:provider/provider.dart';

import '../../models/measurement_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/body_analysis_service.dart';
import '../../services/smpl_avatar_service.dart';
import '../../utils/constants.dart';
import '../../widgets/avatar_progress_slider.dart';

class AvatarViewerScreen extends StatefulWidget {
  const AvatarViewerScreen({super.key});

  @override
  State<AvatarViewerScreen> createState() => _AvatarViewerScreenState();
}

class _AvatarViewerScreenState extends State<AvatarViewerScreen>
    with SingleTickerProviderStateMixin {
  final SmplAvatarService _smplService = SmplAvatarService();
  final BodyAnalysisService _bodyService = BodyAnalysisService();

  // ── State ──────────────────────────────────────────────────────────────────
  List<AvatarSnapshot> _snapshots = [];
  int _selectedIndex = 0;
  String? _currentGlbPath; // absolute local path for ModelViewer
  bool _isLoading = true;
  bool _isGenerating = false;
  bool _backendAvailable = false;
  String _statusMessage = '';

  late AnimationController _spinCtrl;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _init();
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    _bodyService.dispose();
    super.dispose();
  }

  // ── Initialisation ─────────────────────────────────────────────────────────

  Future<void> _init() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Loading avatar history…';
    });

    final userId = _userId;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    final results = await Future.wait([
      _smplService.getAvatarHistory(userId),
      _smplService.isBackendAvailable(),
    ]);

    _snapshots = results[0] as List<AvatarSnapshot>;
    _backendAvailable = results[1] as bool;

    if (_snapshots.isNotEmpty) {
      _selectedIndex = _snapshots.length - 1;
      await _loadGlbForSelected();
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _statusMessage = '';
      });
    }
  }

  Future<void> _loadGlbForSelected() async {
    if (_snapshots.isEmpty) return;
    final snap = _snapshots[_selectedIndex];
    setState(() => _statusMessage = 'Loading model…');
    try {
      final path = await _smplService.getGlbPath(
        userId: _userId!,
        snapDate: snap.date,
      );
      if (mounted)
        setState(() {
          _currentGlbPath = path;
          _statusMessage = '';
        });
    } catch (e) {
      if (mounted)
        setState(
            () => _statusMessage = 'Could not load model for ${snap.date}');
    }
  }

  // ── Avatar generation ─────────────────────────────────────────────────────

  Future<void> _generateAvatar() async {
    final userId = _userId;
    if (userId == null) return;

    MeasurementModel? latest;
    try {
      latest = await _bodyService.getLatestMeasurement(userId);
    } catch (_) {}

    if (latest == null) {
      _showSnack('No body scan found. Complete a body scan first.');
      return;
    }

    setState(() {
      _isGenerating = true;
      _statusMessage = 'Generating SMPL-X avatar…';
    });

    try {
      final path = await _smplService.generateAvatar(
        userId: userId,
        measurement: latest,
      );
      _snapshots = await _smplService.getAvatarHistory(userId);
      _selectedIndex = _snapshots.length - 1;
      if (mounted) {
        setState(() {
          _currentGlbPath = path;
          _isGenerating = false;
          _statusMessage = '';
        });
        _showSnack('Avatar generated!', success: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _statusMessage = 'Generation failed';
        });
        _showSnack(e.toString());
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: _isLoading
          ? _buildLoadingView('Loading avatar data…')
          : _snapshots.isEmpty && !_isGenerating
              ? _buildNoAvatarView()
              : _buildMainContent(),
      floatingActionButton: _buildFab(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        '3D Body Avatar',
        style: TextStyle(
            color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Center(
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    _backendAvailable ? Colors.greenAccent : Colors.redAccent,
              ),
            ),
          ),
        ),
        IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _init),
      ],
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        Expanded(
          flex: 5,
          child: _isGenerating
              ? _buildLoadingView(_statusMessage)
              : _build3DViewer(),
        ),
        if (_snapshots.isNotEmpty)
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: AvatarProgressSlider(
              snapshots: _snapshots,
              selectedIndex: _selectedIndex,
              onSnapshotSelected: (i) async {
                setState(() => _selectedIndex = i);
                await _loadGlbForSelected();
              },
            ),
          ),
        if (_snapshots.isNotEmpty)
          Expanded(flex: 3, child: _buildMeasurementsPanel()),
      ],
    );
  }

  Widget _build3DViewer() {
    final String? src = _currentGlbPath != null
        ? (_currentGlbPath!.startsWith('/') || _currentGlbPath!.contains(':\\')
            ? 'file://$_currentGlbPath'
            : _currentGlbPath)
        : null;

    if (src == null || src.isEmpty) {
      return Container(
        color: AppColors.surface,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.threed_rotation,
                  size: 64, color: Colors.white.withOpacity(0.3)),
              const SizedBox(height: 16),
              Text(
                _statusMessage.isNotEmpty ? _statusMessage : 'No model loaded',
                style: TextStyle(color: Colors.white.withOpacity(0.6)),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        // Gradient background so the WebView scene blends naturally
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0A0B0A), Color(0xFF0A0B0A)],
            ),
          ),
        ),
        ModelViewer(
          src: src,
          alt: '3D Body Avatar',
          ar: false,
          autoRotate: true,
          autoRotateDelay: 1500,
          cameraControls: true,
          backgroundColor: const Color(0xFF0A0B0A),
          loading: Loading.eager,
          autoPlay: true,
          shadowIntensity: 0.8,
          exposure: 1.2,
          cameraOrbit: '0deg 75deg 2.5m',
          minCameraOrbit: 'auto auto 0.5m',
          maxCameraOrbit: 'auto auto 5m',
        ),
        if (_snapshots.isNotEmpty)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                _snapshots[_selectedIndex].date,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ),
        Positioned(
          bottom: 12,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.view_in_ar, size: 11, color: AppColors.accent),
                const SizedBox(width: 4),
                const Text('SMPL-X',
                    style: TextStyle(
                        color: Colors.white60,
                        fontSize: 10,
                        letterSpacing: 0.3)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMeasurementsPanel() {
    final snap = _snapshots.isNotEmpty ? _snapshots[_selectedIndex] : null;
    final meas = snap?.measurements ?? {};
    final height = (meas['height'] as num?)?.toDouble() ?? 0;
    final weight = (meas['weight'] as num?)?.toDouble() ?? snap?.weight ?? 0;

    final bmi = (height > 0 && weight > 0)
        ? weight / ((height / 100) * (height / 100))
        : null;

    final bmiLabel = bmi == null
        ? '—'
        : bmi < 18.5
            ? 'Underweight'
            : bmi < 25
                ? 'Normal'
                : bmi < 30
                    ? 'Overweight'
                    : 'Obese';

    final bmiColor = bmi == null
        ? Colors.grey
        : bmi < 18.5
            ? Colors.blue
            : bmi < 25
                ? Colors.green
                : bmi < 30
                    ? Colors.orange
                    : Colors.red;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Body Measurements',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: AppColors.accent.withOpacity(0.4)),
                  ),
                  child: Text(
                    _backendAvailable ? 'SMPL-X morphed' : 'cached',
                    style:
                        const TextStyle(color: AppColors.accent, fontSize: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.8,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: [
                _measCard(
                    'Height', '${height.toStringAsFixed(0)} cm', Icons.height),
                _measCard('Weight', '${weight.toStringAsFixed(1)} kg',
                    Icons.monitor_weight_outlined),
                _measCard('Chest', _fmt(meas['chest']), Icons.accessibility),
                _measCard(
                    'Waist', _fmt(meas['waist']), Icons.accessibility_new),
                _measCard('Hips', _fmt(meas['hips']), Icons.accessibility),
                _measCard('Shoulders', _fmt(meas['shoulderWidth']),
                    Icons.open_in_full),
              ],
            ),
            if (bmi != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: bmiColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: bmiColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Text(
                      bmi.toStringAsFixed(1),
                      style: TextStyle(
                          color: bmiColor,
                          fontSize: 28,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 6),
                    Text('kg/m²',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 13)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: bmiColor,
                          borderRadius: BorderRadius.circular(10)),
                      child: Text(bmiLabel,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
            if (_snapshots.length > 1) ...[
              const SizedBox(height: 12),
              _buildProgressComparison(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgressComparison() {
    final first = _snapshots.first;
    final current = _snapshots.isNotEmpty ? _snapshots[_selectedIndex] : null;
    if (current == null) return const SizedBox.shrink();
    final dw = (current.weight ?? 0) - (first.weight ?? 0);
    final dWaist = (current.waist ?? 0) - (first.waist ?? 0);
    return Row(
      children: [
        Expanded(child: _deltaCard('Weight', dw, 'kg')),
        const SizedBox(width: 10),
        Expanded(child: _deltaCard('Waist', dWaist, 'cm')),
      ],
    );
  }

  Widget _deltaCard(String label, double delta, String unit) {
    final color = delta == 0
        ? Colors.white54
        : delta <= 0
            ? Colors.greenAccent[400]!
            : Colors.redAccent[200]!;
    final prefix = delta > 0 ? '+' : '';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 4),
          Text('$prefix${delta.toStringAsFixed(1)} $unit',
              style: TextStyle(
                  color: color, fontSize: 16, fontWeight: FontWeight.bold)),
          Text('since start',
              style:
                  TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9)),
        ],
      ),
    );
  }

  Widget _measCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: AppColors.charcoal, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  style: const TextStyle(color: Colors.white54, fontSize: 10)),
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoAvatarView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.charcoal,
                border: Border.all(
                    color: AppColors.accent.withOpacity(0.4), width: 2),
              ),
              child: Icon(Icons.view_in_ar,
                  size: 60, color: AppColors.accent.withOpacity(0.8)),
            ),
            const SizedBox(height: 28),
            const Text('Generate Your 3D Avatar',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
              'Your body measurements will be used to generate a realistic SMPL-X avatar. '
              'Complete a body scan first, then tap the button below.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 15,
                  height: 1.5),
            ),
            if (!_backendAvailable) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber,
                        color: Colors.redAccent, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'SMPL-X backend is offline. Start the backend server to generate avatars.',
                        style: TextStyle(color: Colors.redAccent, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _FeatureChip(
                    icon: Icons.accessibility_new, label: 'Body shape'),
                _FeatureChip(
                    icon: Icons.straighten, label: 'Real measurements'),
                _FeatureChip(icon: Icons.science, label: 'SMPL-X model'),
                _FeatureChip(
                    icon: Icons.trending_up, label: 'Updates with progress'),
              ],
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _backendAvailable ? _generateAvatar : null,
                icon: const Icon(Icons.auto_awesome, color: Colors.black),
                label: const Text('Generate My Avatar',
                    style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  disabledBackgroundColor: AppColors.accent.withOpacity(0.4),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSnapshotView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_camera_outlined,
                size: 90, color: Colors.white.withOpacity(0.25)),
            const SizedBox(height: 24),
            const Text('No Snapshots Yet',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
              'Your realistic avatar is ready!\nComplete a body scan, then tap Update Avatar '
              'to see your personalised 3D avatar with your exact measurements.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 15,
                  height: 1.5),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Go to Body Scan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingView(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RotationTransition(
            turns: _spinCtrl,
            child: const Icon(Icons.threed_rotation,
                size: 60, color: AppColors.accent),
          ),
          const SizedBox(height: 20),
          Text(message,
              style: const TextStyle(color: Colors.white70, fontSize: 16)),
        ],
      ),
    );
  }

  Widget? _buildFab() {
    if (_isLoading || _isGenerating || !_backendAvailable) return null;
    return FloatingActionButton.extended(
      onPressed: _generateAvatar,
      backgroundColor: AppColors.accent,
      icon: const Icon(Icons.sync, color: Colors.black),
      label: const Text('Update Avatar',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
    );
  }

  String? get _userId =>
      Provider.of<AuthProvider>(context, listen: false).user?.uid;

  String _fmt(dynamic v) {
    if (v == null) return '—';
    return '${(v as num).toStringAsFixed(0)} cm';
  }

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? Colors.greenAccent[700] : AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
  }
}

// ─── Feature chip ─────────────────────────────────────────────────────────────

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.accent),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}
