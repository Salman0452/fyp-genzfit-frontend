import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/measurement_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/avatar_generation_service.dart';
import 'rpm_avatar_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data model for a history entry
// ─────────────────────────────────────────────────────────────────────────────
class _AvatarEntry {
  final String modelUrl;
  final String thumbnailUrl;
  final String createdAt;
  final double? weight;

  const _AvatarEntry({
    required this.modelUrl,
    required this.thumbnailUrl,
    required this.createdAt,
    this.weight,
  });

  factory _AvatarEntry.fromJson(Map<String, dynamic> j) => _AvatarEntry(
    modelUrl: j['model_url'] as String? ?? '',
    thumbnailUrl: j['thumbnail_url'] as String? ?? '',
    createdAt: j['created_at'] as String? ?? '',
    weight: (j['weight'] as num?)?.toDouble(),
  );

  String get shortDate {
    if (createdAt.isEmpty) return '';
    try {
      final dt = DateTime.parse(createdAt);
      const m = [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${dt.day} ${m[dt.month]}';
    } catch (_) {
      return '';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
class AvatarViewerScreen extends StatefulWidget {
  const AvatarViewerScreen({super.key});

  @override
  State<AvatarViewerScreen> createState() => _AvatarViewerScreenState();
}

class _AvatarViewerScreenState extends State<AvatarViewerScreen> {
  static const String _backendBase = String.fromEnvironment(
    'AVATAR_API_URL',
    defaultValue: 'http://192.168.10.14:8000',
  );

  // Avaturn subdomain — 'demo' works for free testing.
  // Register your own at https://developer.avaturn.me/ for production.
  static const String _avaturnSubdomain = 'genzfit';
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AvatarGenerationService _avatarService = AvatarGenerationService();

  String? _currentModelUrl;
  MeasurementModel? _latestMeasurement;
  List<_AvatarEntry> _history = [];
  int _selectedIndex = 0;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── Load ─────────────────────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final uid = auth.user?.uid;
      if (uid == null) throw Exception('Not authenticated');

      // Load latest measurement for the info panel
      final mSnap =
          await _db
              .collection('measurements')
              .where('userId', isEqualTo: uid)
              .orderBy('date', descending: true)
              .limit(1)
              .get();
      if (mSnap.docs.isNotEmpty) {
        _latestMeasurement = MeasurementModel.fromFirestore(mSnap.docs.first);
      }

      // Load avatar URL — first check Firestore avatars collection,
      // then fall back to the backend REST endpoint.
      final aSnap =
          await _db
              .collection('avatars')
              .where('userId', isEqualTo: uid)
              .orderBy('createdAt', descending: true)
              .limit(1)
              .get();

      if (aSnap.docs.isNotEmpty) {
        _currentModelUrl = aSnap.docs.first.data()['modelUrl'] as String?;
      } else {
        final res = await _avatarService.getLatestAvatar(uid);
        if (res['success'] == true && (res['modelUrl'] as String).isNotEmpty) {
          _currentModelUrl = res['modelUrl'] as String;
        }
      }

      // Load history from backend
      await _loadHistory(uid);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadHistory(String uid) async {
    try {
      final url = Uri.parse(
        '$_backendBase/api/v1/avatar/history/$uid?limit=30',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final raw =
            (data['avatars'] as List? ?? [])
                .whereType<Map<String, dynamic>>()
                .toList();
        if (mounted) {
          setState(() {
            _history = raw.map(_AvatarEntry.fromJson).toList();
            _selectedIndex = 0;
          });
        }
      }
    } catch (_) {}
  }

  // ── Open Avaturn customiser ─────────────────────────────────────────────
  Future<void> _openRpmCustomiser() async {
    // No guard needed — 'demo' subdomain always works for testing.

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final uid = auth.user?.uid;
    if (uid == null) return;

    final avatarUrl = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => RpmAvatarScreen(subdomain: _avaturnSubdomain),
        fullscreenDialog: true,
      ),
    );

    if (avatarUrl == null || avatarUrl.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      // Save to Firestore avatars collection
      await _db.collection('avatars').add({
        'userId': uid,
        'modelUrl': avatarUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Also notify our backend (fire-and-forget)
      _avatarService.saveRpmAvatar(
        userId: uid,
        rpmModelUrl: avatarUrl,
        height: _latestMeasurement?.height,
        weight: _latestMeasurement?.weight,
        measurements:
            _latestMeasurement?.estimatedMeasurements.map(
              (k, v) => MapEntry(k, v as dynamic),
            ) ??
            {},
      );

      setState(() {
        _currentModelUrl = avatarUrl;
        _selectedIndex = 0;
      });

      _showSnack('🎉 Avatar saved!', Colors.green);
      await _loadHistory(uid);
    } catch (e) {
      _showSnack('Failed to save avatar: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('3D Avatar', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
              tooltip: 'Create / Change Avatar',
              onPressed: _openRpmCustomiser,
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white54),
            tooltip: 'Reload',
            onPressed: _load,
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
              : _error != null
              ? _buildError()
              : Column(
                children: [
                  Expanded(flex: 3, child: _build3DViewer()),
                  Expanded(flex: 2, child: _buildInfoPanel()),
                  if (_history.length > 1) _buildHistoryStrip(),
                ],
              ),
    );
  }

  // ── 3D viewer ────────────────────────────────────────────────────────────
  Widget _build3DViewer() {
    final url =
        _history.isNotEmpty
            ? _history[_selectedIndex].modelUrl
            : _currentModelUrl;

    if (url == null || url.isEmpty) {
      return _buildNoAvatar();
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.grey[900]!, Colors.black],
        ),
      ),
      child: ModelViewer(
        src: url,
        alt: '3D Avatar',
        ar: false,
        autoRotate: false,
        cameraControls: true,
        backgroundColor: const Color(0xFF1A1A2E),
        loading: Loading.eager,
        interactionPrompt: InteractionPrompt.none,
        environmentImage:
            'https://modelviewer.dev/shared-assets/environments/neutral.hdr',
        exposure: 1.0,
        shadowIntensity: 1.0,
        shadowSoftness: 0.8,
      ),
    );
  }

  Widget _buildNoAvatar() {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_outline,
              size: 80,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Avatar Yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the 👤+ button above to create your avatar',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _openRpmCustomiser,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Create Avatar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Info panel ───────────────────────────────────────────────────────────
  Widget _buildInfoPanel() {
    final m = _latestMeasurement;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Body Measurements',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _openRpmCustomiser,
                  icon: const Icon(
                    Icons.edit,
                    size: 14,
                    color: Colors.deepPurpleAccent,
                  ),
                  label: const Text(
                    'Change Avatar',
                    style: TextStyle(
                      color: Colors.deepPurpleAccent,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (m == null)
              Text(
                'No measurements saved yet.',
                style: TextStyle(color: Colors.white.withOpacity(0.5)),
              )
            else
              _buildMeasurementGrid(m),
          ],
        ),
      ),
    );
  }

  Widget _buildMeasurementGrid(MeasurementModel m) {
    final meas = m.estimatedMeasurements;
    final items = [
      {
        'label': 'Height',
        'value': '${m.height.toStringAsFixed(0)} cm',
        'icon': Icons.height,
      },
      {
        'label': 'Weight',
        'value': '${m.weight.toStringAsFixed(1)} kg',
        'icon': Icons.monitor_weight_outlined,
      },
      {
        'label': 'Chest',
        'value': '${(meas['chest'] ?? 0).toStringAsFixed(0)} cm',
        'icon': Icons.accessibility,
      },
      {
        'label': 'Waist',
        'value': '${(meas['waist'] ?? 0).toStringAsFixed(0)} cm',
        'icon': Icons.accessibility_new,
      },
      {
        'label': 'Hips',
        'value': '${(meas['hips'] ?? 0).toStringAsFixed(0)} cm',
        'icon': Icons.accessibility,
      },
      {
        'label': 'Shoulders',
        'value':
            '${(meas['shoulderWidth'] ?? meas['shoulders'] ?? 0).toStringAsFixed(0)} cm',
        'icon': Icons.open_in_full,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.5,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[850],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                item['icon'] as IconData,
                color: Colors.white.withOpacity(0.6),
                size: 18,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item['label'] as String,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    item['value'] as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── History strip ────────────────────────────────────────────────────────
  Widget _buildHistoryStrip() {
    return Container(
      height: 110,
      color: const Color(0xFF111111),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'History',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _history.length,
              itemBuilder: (_, i) {
                final e = _history[i];
                final sel = i == _selectedIndex;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIndex = i),
                  child: Container(
                    width: 64,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color:
                          sel
                              ? Colors.deepPurpleAccent.withOpacity(0.2)
                              : Colors.grey[850],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color:
                            sel ? Colors.deepPurpleAccent : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (e.thumbnailUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              e.thumbnailUrl,
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (_, __, ___) => Icon(
                                    Icons.person,
                                    color:
                                        sel
                                            ? Colors.deepPurpleAccent
                                            : Colors.white38,
                                    size: 24,
                                  ),
                            ),
                          )
                        else
                          Icon(
                            Icons.person,
                            color:
                                sel ? Colors.deepPurpleAccent : Colors.white38,
                            size: 24,
                          ),
                        const SizedBox(height: 4),
                        Text(
                          e.shortDate.isNotEmpty ? e.shortDate : 'Avatar',
                          style: TextStyle(
                            color: sel ? Colors.deepPurpleAccent : Colors.white,
                            fontSize: 9,
                            fontWeight:
                                sel ? FontWeight.bold : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (i == 0)
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'LATEST',
                              style: TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 7,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Error ────────────────────────────────────────────────────────────────
  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 64),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
