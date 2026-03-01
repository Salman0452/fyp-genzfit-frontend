// ignore_for_file: unused_import
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:provider/provider.dart';

import '../../models/measurement_model.dart';
import '../../providers/auth_provider.dart';
import '../../screens/client/avatar_creator_screen.dart';
import '../../services/body_analysis_service.dart';
import '../../services/ready_player_me_service.dart';
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
  final ReadyPlayerMeService _rpmService = ReadyPlayerMeService();
  final BodyAnalysisService _bodyService = BodyAnalysisService();

  // ── State ──────────────────────────────────────────────────────────────────
  String? _baseAvatarUrl;       // RPM base avatar URL (null = not created yet)
  List<AvatarSnapshot> _snapshots = [];
  int _selectedIndex = 0;

  String? _currentGlbUrl;
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
      _statusMessage = 'Loading your avatar…';
    });

    final userId = _userId;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    final results = await Future.wait([
      _rpmService.getBaseAvatarUrl(userId),
      _rpmService.getAvatarHistory(userId),
      SmplAvatarService().isBackendAvailable(),
    ]);

    _baseAvatarUrl    = results[0] as String?;
    _snapshots        = results[1] as List<AvatarSnapshot>;
    _backendAvailable = results[2] as bool;

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
    if (_snapshots.isEmpty || _baseAvatarUrl == null) return;
    final snap = _snapshots[_selectedIndex];
    setState(() => _statusMessage = 'Loading model…');
    try {
      final path = await _rpmService.getGlbUrl(
        userId: _userId!,
        snapDate: snap.date,
        baseAvatarUrl: _baseAvatarUrl!,
      );
<<<<<<< HEAD
      if (mounted) setState(() { _currentGlbUrl = path; _statusMessage = ''; });
=======
      if (mounted)
        setState(() {
          _currentGlbPath = path;
          _statusMessage = '';
        });
>>>>>>> d569dc186443a80b28cb0b4bedb9244948328b83
    } catch (e) {
      if (mounted)
        setState(
            () => _statusMessage = 'Could not load model for ${snap.date}');
    }
  }

<<<<<<< HEAD
  // ── Avatar creation flow ───────────────────────────────────────────────────

  Future<void> _openCreator() async {
    final url = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const AvatarCreatorScreen()),
    );
    if (url != null && url.isNotEmpty) {
      setState(() => _baseAvatarUrl = url);
      _showSnack('Avatar created! Generating your first snapshot…', success: true);
      await _generateSnapshot();
=======
  Future<void> _generateNewAvatar() async {
    if (!_backendAvailable) {
      _showSnack(
          'SMPL backend is not reachable. Start the Python server first.');
      return;
>>>>>>> d569dc186443a80b28cb0b4bedb9244948328b83
    }
  }

  Future<void> _generateSnapshot() async {
    final userId = _userId;
    if (userId == null || _baseAvatarUrl == null) return;

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
<<<<<<< HEAD
      _statusMessage = _backendAvailable ? 'Morphing avatar to your measurements…' : 'Downloading avatar…';
=======
      _statusMessage = 'Generating SMPL avatar…';
>>>>>>> d569dc186443a80b28cb0b4bedb9244948328b83
    });

    try {
      final path = await _rpmService.generateSnapshot(
        userId: userId,
        baseAvatarUrl: _baseAvatarUrl!,
        measurement: latest,
      );
      _snapshots = await _rpmService.getAvatarHistory(userId);
      _selectedIndex = _snapshots.length - 1;
      if (mounted) {
<<<<<<< HEAD
        setState(() { _currentGlbUrl = path; _isGenerating = false; _statusMessage = ''; });
        _showSnack('Avatar snapshot saved!', success: true);
=======
        setState(() {
          _currentGlbPath = avatar.modelUrl;
          _isGenerating = false;
          _statusMessage = '';
        });
        _showSnack('3D avatar generated successfully!', success: true);
>>>>>>> d569dc186443a80b28cb0b4bedb9244948328b83
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
      backgroundColor: Colors.black,
      appBar: _buildAppBar(),
      body: _isLoading
          ? _buildLoadingView('Loading avatar data…')
          : _baseAvatarUrl == null
              ? _buildNoAvatarView()
              : _snapshots.isEmpty && !_isGenerating
                  ? _buildNoSnapshotView()
                  : _buildMainContent(),
      floatingActionButton: _buildFab(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.black,
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
<<<<<<< HEAD
        if (_baseAvatarUrl != null)
          IconButton(
            icon: const Icon(Icons.person_pin_outlined, color: Colors.white70),
            tooltip: 'Recreate avatar',
            onPressed: _openCreator,
          ),
        IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _init),
=======
        IconButton(
            icon: const Icon(Icons.tune, color: Colors.white),
            onPressed: _showAppearanceSheet),
        IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _init),
>>>>>>> d569dc186443a80b28cb0b4bedb9244948328b83
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
            color: Colors.grey[900],
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
    final String? src = _currentGlbUrl != null
        ? _currentGlbUrl!
        : (_baseAvatarUrl != null
            ? _rpmService.buildDirectGlbUrl(_baseAvatarUrl!)
            : null);

    if (src == null || src.isEmpty) {
      return Container(
        color: Colors.grey[900],
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
<<<<<<< HEAD
          backgroundColor: const Color(0xFF0A0B0A),
=======
          backgroundColor: Colors.transparent,
>>>>>>> d569dc186443a80b28cb0b4bedb9244948328b83
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
          bottom: 12, left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified, size: 11, color: AppColors.accent),
                const SizedBox(width: 4),
                const Text('Ready Player Me',
                    style: TextStyle(color: Colors.white60, fontSize: 10, letterSpacing: 0.3)),
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
        color: Colors.grey[900],
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
<<<<<<< HEAD
                    _backendAvailable ? 'morphed • RPM' : 'RPM base',
                    style: const TextStyle(color: AppColors.accent, fontSize: 10),
=======
                    _backendAvailable ? 'SMPL pipeline' : 'cached',
                    style:
                        const TextStyle(color: AppColors.accent, fontSize: 10),
>>>>>>> d569dc186443a80b28cb0b4bedb9244948328b83
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
    final first   = _snapshots.first;
    final current = _snapshots.isNotEmpty ? _snapshots[_selectedIndex] : null;
    if (current == null) return const SizedBox.shrink();
    final dw     = (current.weight ?? 0) - (first.weight ?? 0);
    final dWaist = (current.waist  ?? 0) - (first.waist  ?? 0);
    return Row(
      children: [
        Expanded(child: _deltaCard('Weight', dw,     'kg')),
        const SizedBox(width: 10),
        Expanded(child: _deltaCard('Waist',  dWaist, 'cm')),
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
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 4),
          Text('$prefix${delta.toStringAsFixed(1)} $unit',
              style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
          Text('since start',
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9)),
        ],
      ),
    );
  }

  Widget _measCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: Colors.grey[850], borderRadius: BorderRadius.circular(10)),
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
<<<<<<< HEAD
            Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[850],
                border: Border.all(color: AppColors.accent.withOpacity(0.4), width: 2),
              ),
              child: Icon(Icons.person_add_outlined, size: 60, color: AppColors.accent.withOpacity(0.8)),
            ),
            const SizedBox(height: 28),
            const Text('Create Your 3D Avatar',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
=======
            Icon(Icons.person_outline,
                size: 100, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 24),
            const Text('No 3D Avatar Yet',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
>>>>>>> d569dc186443a80b28cb0b4bedb9244948328b83
            const SizedBox(height: 12),
            Text(
              'Design a fully realistic avatar — choose your face, skin tone, hair, and outfit. '
              'Your body shape will automatically update as your measurements change over time.',
              textAlign: TextAlign.center,
<<<<<<< HEAD
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8, runSpacing: 8,
              children: const [
                _FeatureChip(icon: Icons.face,          label: 'Realistic face'),
                _FeatureChip(icon: Icons.checkroom,     label: 'Full outfit'),
                _FeatureChip(icon: Icons.spa,           label: 'Hair & skin'),
                _FeatureChip(icon: Icons.trending_up,   label: 'Updates with progress'),
              ],
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openCreator,
                icon: const Icon(Icons.auto_awesome, color: Colors.black),
                label: const Text('Create My Avatar',
                    style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
=======
              style:
                  TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 15),
            ),
            if (!_backendAvailable) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[850],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.4)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.terminal, color: Colors.orange, size: 16),
                      SizedBox(width: 8),
                      Text('Quick Start',
                          style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ]),
                    SizedBox(height: 8),
                    Text(
                      'cd smpl_backend\n'
                      'pip install -r requirements.txt\n'
                      'uvicorn main:app --host 0.0.0.0 --port 8000',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontFamily: 'monospace'),
                    ),
                  ],
>>>>>>> d569dc186443a80b28cb0b4bedb9244948328b83
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
            Icon(Icons.photo_camera_outlined, size: 90, color: Colors.white.withOpacity(0.25)),
            const SizedBox(height: 24),
            const Text('No Snapshots Yet',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
              'Your realistic avatar is ready!\nComplete a body scan, then tap Update Avatar '
              'to see your personalised 3D avatar with your exact measurements.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 15, height: 1.5),
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
    if (_isLoading || _isGenerating || _baseAvatarUrl == null) return null;
    return FloatingActionButton.extended(
<<<<<<< HEAD
      onPressed: _generateSnapshot,
      backgroundColor: AppColors.accent,
      icon: const Icon(Icons.sync, color: Colors.black),
      label: const Text('Update Avatar',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
=======
      onPressed: _generateNewAvatar,
      backgroundColor: _backendAvailable ? AppColors.accent : Colors.grey[700],
      icon: const Icon(Icons.auto_awesome, color: Colors.white),
      label:
          const Text('Generate Avatar', style: TextStyle(color: Colors.white)),
    );
  }

  void _showAppearanceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Appearance',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              const Text('Skin Tone',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (final tone in ['light', 'medium', 'brown', 'dark'])
                    _SkinToneButton(
                      tone: tone,
                      selected: _skinTone == tone,
                      onTap: () => setSheet(() => _skinTone = tone),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text('Muscle Overlay',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const Spacer(),
                  Switch(
                      value: _showMuscles,
                      activeColor: AppColors.accent,
                      onChanged: (v) => setSheet(() => _showMuscles = v)),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {});
                    _generateNewAvatar();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Regenerate Avatar',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
>>>>>>> d569dc186443a80b28cb0b4bedb9244948328b83
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

<<<<<<< HEAD
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
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
=======
  const _SkinToneButton(
      {required this.tone, required this.selected, required this.onTap});

  static const _colors = {
    'light': Color(0xFFFFE0C4),
    'medium': Color(0xFFD2A078),
    'brown': Color(0xFFA5694B),
    'dark': Color(0xFF644128),
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[tone] ?? Colors.grey;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
              color: selected ? Colors.white : Colors.transparent, width: 3),
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 22)
            : null,
>>>>>>> d569dc186443a80b28cb0b4bedb9244948328b83
      ),
    );
  }
}
