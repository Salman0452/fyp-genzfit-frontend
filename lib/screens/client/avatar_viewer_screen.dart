import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    with TickerProviderStateMixin {
  final SmplAvatarService _smplService = SmplAvatarService();
  final BodyAnalysisService _bodyService = BodyAnalysisService();

  // ── State ──────────────────────────────────────────────────────────────────
  List<AvatarSnapshot> _snapshots = [];
  int _selectedIndex = 0;
  String? _currentGlbUrl; // Cloudinary https:// URL for ModelViewer
  bool _isLoading = true;
  bool _isGenerating = false;
  bool _backendAvailable = false;
  String _statusMessage = '';

  // Hint visibility
  bool _showHint = false;

  late AnimationController _spinCtrl;
  late AnimationController _hintCtrl;
  late Animation<double> _hintOpacity;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _hintCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _hintOpacity = CurvedAnimation(parent: _hintCtrl, curve: Curves.easeInOut);

    _init();
    _checkHint();
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    _hintCtrl.dispose();
    _bodyService.dispose();
    super.dispose();
  }

  Future<void> _checkHint() async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool('avatar_hint_shown') ?? false;
    if (!shown && mounted) {
      setState(() => _showHint = true);
      _hintCtrl.forward();
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        await _hintCtrl.reverse();
        setState(() => _showHint = false);
        await prefs.setBool('avatar_hint_shown', true);
      }
    }
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

    // If the snapshot already carries the URL (loaded from Firestore), use it
    // directly without a network round-trip.
    if (snap.glbUrl != null && snap.glbUrl!.isNotEmpty) {
      if (mounted) setState(() => _currentGlbUrl = snap.glbUrl);
      return;
    }

    // Fallback: fetch from Firestore in case the in-memory snapshot is stale
    setState(() => _statusMessage = 'Loading model…');
    try {
      final url = await _smplService.getGlbUrl(
        userId: _userId!,
        snapDate: snap.date,
      );
      if (mounted)
        setState(() {
          _currentGlbUrl = url;
          _statusMessage = '';
        });
    } catch (e) {
      if (mounted)
        setState(
            () => _statusMessage = 'Could not load model for \${snap.date}');
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
      final glbUrl = await _smplService.generateAvatar(
        userId: userId,
        measurement: latest,
        skinTone: Provider.of<AuthProvider>(context, listen: false)
                .userModel
                ?.skinTone ??
            'medium',
      );
      _snapshots = await _smplService.getAvatarHistory(userId);
      _selectedIndex = _snapshots.length - 1;
      if (mounted) {
        setState(() {
          _currentGlbUrl = glbUrl;
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      elevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back,
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFFFFFFFF)
              : Colors.black,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        '3D Body Avatar',
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFFFFFFFF)
              : Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
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
                color: _backendAvailable
                    ? (Theme.of(context).brightness == Brightness.dark
                        ? AppColors.accent
                        : AppColors.brandGreenDeep)
                    : AppColors.error,
              ),
            ),
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.refresh,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFFFFFFFF)
                : AppColors.textPrimary,
          ),
          onPressed: _init,
        ),
      ],
    );
  }

  Widget _buildMainContent() {
    return Stack(
      children: [
        // ── Layer 1: Avatar fills entire screen ──────────────────────────────
        Positioned.fill(
          child: _isGenerating
              ? _buildLoadingView(_statusMessage)
              : _build3DViewer(),
        ),

        // ── Layer 2: Draggable bottom sheet ───────────────────────────────────
        DraggableScrollableSheet(
          initialChildSize: 0.45,
          minChildSize: 0.08,
          maxChildSize: 0.75,
          snap: true,
          snapSizes: const [0.08, 0.45, 0.75],
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1A1A1A)
                    : AppColors.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: (Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF000000)
                            : Colors.black)
                        .withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.zero,
                children: [
                  // ── Drag handle + optional hint ───────────────────────────
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 12),
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? AppColors.accentGray
                                    : AppColors.accentGray,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      if (_showHint)
                        FadeTransition(
                          opacity: _hintOpacity,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.keyboard_arrow_down,
                                  size: 16,
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color(0xFF606060)
                                      : const Color(0xFFAAAAAA),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Swipe down for fullscreen',
                                  style: TextStyle(
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? const Color(0xFF606060)
                                        : const Color(0xFFAAAAAA),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                    ],
                  ),

                  // ── Progress timeline ─────────────────────────────────────
                  if (_snapshots.isNotEmpty)
                    Container(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF1A1A1A)
                          : AppColors.surface,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: AvatarProgressSlider(
                        snapshots: _snapshots,
                        selectedIndex: _selectedIndex,
                        onSnapshotSelected: (i) async {
                          setState(() => _selectedIndex = i);
                          await _loadGlbForSelected();
                        },
                      ),
                    ),

                  // ── Body measurements ─────────────────────────────────────
                  if (_snapshots.isNotEmpty) _buildMeasurementsPanel(),

                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _build3DViewer() {
    final String? src = (_currentGlbUrl != null && _currentGlbUrl!.isNotEmpty)
        ? _currentGlbUrl
        : null;

    if (src == null || src.isEmpty) {
      return Container(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF0A0A0A)
            : AppColors.surface,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.threed_rotation,
                  size: 64,
                  color: (Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFFFFFFF)
                          : AppColors.textPrimary)
                      .withOpacity(0.3)),
              const SizedBox(height: 16),
              Text(
                _statusMessage.isNotEmpty ? _statusMessage : 'No model loaded',
                style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFB0B0B0)
                        : AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return _buildModelViewer(src);
  }

  Widget _buildModelViewer(String src) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1C1F2E), Color(0xFF12141E)],
            ),
          ),
        ),
        ModelViewer(
          src: src,
          alt: '3D Body Avatar',
          ar: false,
          autoRotate: false,
          autoRotateDelay: 0,
          cameraControls: true,
          disablePan: true,
          backgroundColor: const Color(0xFF1C1F2E),
          loading: Loading.eager,
          autoPlay: true,
          shadowIntensity: 1,
          exposure: 1.5,
          cameraOrbit: '0deg 85deg 4.5m',
          fieldOfView: '45deg',
          minCameraOrbit: 'auto auto 0.5m',
          maxCameraOrbit: 'auto auto 5m',
        ),
        _buildViewerOverlay(),
      ],
    );
  }

  /// Date badge + SMPL-X badge overlaid on viewer
  Widget _buildViewerOverlay() {
    return Stack(
      children: [
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
                style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFB0B0B0)
                        : AppColors.textSecondary,
                    fontSize: 12),
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
                Icon(Icons.view_in_ar,
                    size: 11,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.accent
                        : AppColors.brandGreenDeep),
                const SizedBox(width: 4),
                Text('SMPL-X',
                    style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFB0B0B0)
                            : AppColors.textSecondary,
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
        ? AppColors.accentGray
        : bmi < 18.5
            ? AppColors.accentTeal
            : bmi < 25
                ? (Theme.of(context).brightness == Brightness.dark
                    ? AppColors.accent
                    : AppColors.brandGreenDeep)
                : bmi < 30
                    ? AppColors.accentDarkGray
                    : AppColors.error;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Body Measurements',
                style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFFFFFFF)
                        : AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (Theme.of(context).brightness == Brightness.dark
                          ? AppColors.accent
                          : AppColors.brandGreenDeep)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: (Theme.of(context).brightness == Brightness.dark
                              ? AppColors.accent
                              : AppColors.brandGreenDeep)
                          .withOpacity(0.4)),
                ),
                child: Text(
                  _backendAvailable ? 'SMPL-X morphed' : 'cached',
                  style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.accent
                          : AppColors.brandGreenDeep,
                      fontSize: 10),
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
              _measCard('Waist', _fmt(meas['waist']), Icons.accessibility_new),
              _measCard('Hips', _fmt(meas['hips']), Icons.accessibility),
              _measCard(
                  'Shoulders', _fmt(meas['shoulderWidth']), Icons.open_in_full),
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
                          color: Colors.white.withOpacity(0.6), fontSize: 13)),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: bmiColor,
                        borderRadius: BorderRadius.circular(10)),
                    child: Text(bmiLabel,
                        style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF010101)
                                    : const Color(0xFFFFFFFF),
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
        ? (Theme.of(context).brightness == Brightness.dark
            ? AppColors.accentGray
            : AppColors.accentGray)
        : delta <= 0
            ? (Theme.of(context).brightness == Brightness.dark
                ? AppColors.accent
                : AppColors.brandGreenDeep)
            : AppColors.error;
    final prefix = delta > 0 ? '+' : '';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color!.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF808080)
                      : const Color(0xFF9F9F9F),
                  fontSize: 11)),
          const SizedBox(height: 4),
          Text('$prefix${delta.toStringAsFixed(1)} $unit',
              style: TextStyle(
                  color: color, fontSize: 16, fontWeight: FontWeight.bold)),
          Text('since start',
              style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF606060)
                      : const Color(0xFFAAAAAA),
                  fontSize: 9)),
        ],
      ),
    );
  }

  Widget _measCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF2A2A2A)
              : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(icon,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF808080)
                  : const Color(0xFF9F9F9F),
              size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF808080)
                          : const Color(0xFF9F9F9F),
                      fontSize: 10)),
              Text(value,
                  style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFFFFFFF)
                          : AppColors.textPrimary,
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
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF2A2A2A)
                    : const Color(0xFFF5F5F5),
                border: Border.all(
                    color: (Theme.of(context).brightness == Brightness.dark
                            ? AppColors.accent
                            : AppColors.brandGreenDeep)
                        .withOpacity(0.4),
                    width: 2),
              ),
              child: Icon(Icons.view_in_ar,
                  size: 60,
                  color: (Theme.of(context).brightness == Brightness.dark
                          ? AppColors.accent
                          : AppColors.brandGreenDeep)
                      .withOpacity(0.8)),
            ),
            const SizedBox(height: 28),
            Text('Generate Your 3D Avatar',
                style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFFFFFFF)
                        : AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
              'Your body measurements will be used to generate a realistic SMPL-X avatar. '
              'Complete a body scan first, then tap the button below.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFB0B0B0)
                      : AppColors.textSecondary,
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
                icon: Icon(Icons.auto_awesome,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF010101)
                        : const Color(0xFFFFFFFF)),
                label: Text('Generate My Avatar',
                    style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF010101)
                            : const Color(0xFFFFFFFF),
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      Theme.of(context).brightness == Brightness.dark
                          ? AppColors.accent
                          : AppColors.brandGreenDeep,
                  disabledBackgroundColor:
                      (Theme.of(context).brightness == Brightness.dark
                              ? AppColors.accent
                              : AppColors.brandGreenDeep)
                          .withOpacity(0.4),
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

  Widget _buildLoadingView(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RotationTransition(
            turns: _spinCtrl,
            child: Icon(Icons.threed_rotation,
                size: 60,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.brandGreen
                    : AppColors.brandGreenDeep),
          ),
          const SizedBox(height: 20),
          Text(message,
              style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFB0B0B0)
                      : AppColors.textSecondary,
                  fontSize: 16)),
        ],
      ),
    );
  }

  Widget? _buildFab() {
    if (_isLoading || _isGenerating) return null;
    if (!_backendAvailable) return null;
    return FloatingActionButton.extended(
      heroTag: 'fab_update',
      onPressed: _generateAvatar,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.brandGreen
          : AppColors.brandGreenDeep,
      icon: Icon(Icons.sync,
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF010101)
              : AppColors.background),
      label: Text('Update Avatar',
          style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF010101)
                  : AppColors.background,
              fontWeight: FontWeight.bold)),
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
      backgroundColor: success
          ? (Theme.of(context).brightness == Brightness.dark
              ? AppColors.accent
              : AppColors.brandGreenDeep)
          : AppColors.error,
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
        color: (Theme.of(context).brightness == Brightness.dark
                ? AppColors.accent
                : AppColors.brandGreenDeep)
            .withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: (Theme.of(context).brightness == Brightness.dark
                    ? AppColors.accent
                    : AppColors.brandGreenDeep)
                .withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 13,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.accent
                  : AppColors.brandGreenDeep),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFB0B0B0)
                      : AppColors.textSecondary,
                  fontSize: 11)),
        ],
      ),
    );
  }
}
