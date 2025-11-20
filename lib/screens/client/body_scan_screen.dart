import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:genzfit/services/body_analysis_service.dart';
import 'package:genzfit/widgets/pose_overlay_painter.dart';
import 'package:genzfit/utils/constants.dart';
import 'package:genzfit/widgets/custom_button.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:genzfit/providers/auth_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class BodyScanScreen extends StatefulWidget {
  const BodyScanScreen({super.key});

  @override
  State<BodyScanScreen> createState() => _BodyScanScreenState();
}

class _BodyScanScreenState extends State<BodyScanScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _showGuidelines = true;
  List<File> _capturedPhotos = [];
  final BodyAnalysisService _bodyAnalysisService = BodyAnalysisService();
  Map<String, dynamic>? _analysisResult;

  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      // Request camera permission
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Camera permission is required for body scanning'),
              backgroundColor: AppColors.error,
            ),
          );
          Navigator.pop(context);
        }
        return;
      }

      // Get available cameras
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        throw Exception('No cameras available');
      }

      // Use back camera
      final backCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize camera: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _capturePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      setState(() => _isProcessing = true);

      // Capture image
      final XFile photo = await _cameraController!.takePicture();
      final File photoFile = File(photo.path);

      // Analyze pose
      final result = await _bodyAnalysisService.analyzePose(photo.path);

      setState(() {
        _capturedPhotos.add(photoFile);
        _analysisResult = result;
        _isProcessing = false;
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Photo captured! Confidence: ${(result['confidence'] * 100).toStringAsFixed(1)}%',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }

      // If we have at least one photo, show the review screen
      if (_capturedPhotos.length >= 1) {
        _showReviewDialog();
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showReviewDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Complete Your Scan',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            
            // Height input
            TextField(
              controller: _heightController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Height (cm)',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.charcoal,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.height, color: AppColors.accent),
              ),
            ),
            const SizedBox(height: 16),

            // Weight input
            TextField(
              controller: _weightController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Weight (kg)',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.charcoal,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.monitor_weight, color: AppColors.accent),
              ),
            ),
            const SizedBox(height: 16),

            // Notes input
            TextField(
              controller: _notesController,
              maxLines: 2,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.charcoal,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.notes, color: AppColors.accent),
              ),
            ),
            const SizedBox(height: 24),

            // Save button
            CustomButton(
              text: 'Save Measurement',
              onPressed: _saveMeasurement,
              isLoading: _isProcessing,
            ),
            const SizedBox(height: 16),

            // Cancel button
            CustomButton(
              text: 'Retake Photo',
              onPressed: () {
                setState(() {
                  _capturedPhotos.clear();
                  _analysisResult = null;
                });
                Navigator.pop(context);
              },
              isOutlined: true,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _saveMeasurement() async {
    if (_heightController.text.isEmpty || _weightController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter height and weight'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid;

      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final height = double.parse(_heightController.text);
      final weight = double.parse(_weightController.text);

      await _bodyAnalysisService.saveMeasurement(
        userId: userId,
        height: height,
        weight: weight,
        bodyLandmarks: _analysisResult?['landmarks'] ?? {},
        photos: _capturedPhotos,
        estimatedMeasurements: Map<String, double>.from(
          _analysisResult?['measurements'] ?? {},
        ),
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      if (mounted) {
        Navigator.pop(context); // Close dialog
        Navigator.pop(context); // Close scan screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Measurement saved successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save measurement: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Body Scan'),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            icon: Icon(
              _showGuidelines ? Icons.grid_on : Icons.grid_off,
              color: AppColors.accent,
            ),
            onPressed: () {
              setState(() => _showGuidelines = !_showGuidelines);
            },
          ),
        ],
      ),
      body: _isInitialized
          ? Stack(
              children: [
                // Camera preview
                Positioned.fill(
                  child: CameraPreview(_cameraController!),
                ),

                // Pose overlay guidelines
                if (_showGuidelines)
                  Positioned.fill(
                    child: PoseOverlay(
                      showGuidelines: _showGuidelines,
                      guidelineColor: AppColors.accent,
                    ),
                  ),

                // Instructions
                Positioned(
                  top: 20,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                    ),
                    child: const Text(
                      'Stand in the center with your arms slightly away from your body. Ensure good lighting.',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                // Capture button
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: _isProcessing ? null : _capturePhoto,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isProcessing
                              ? AppColors.textSecondary
                              : AppColors.accent,
                          border: Border.all(
                            color: AppColors.textPrimary,
                            width: 4,
                          ),
                        ),
                        child: _isProcessing
                            ? const Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.textPrimary,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt,
                                color: AppColors.background,
                                size: 32,
                              ),
                      ),
                    ),
                  ),
                ),

                // Photo count indicator
                if (_capturedPhotos.isNotEmpty)
                  Positioned(
                    bottom: 120,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_capturedPhotos.length} photo${_capturedPhotos.length > 1 ? 's' : ''} captured',
                          style: const TextStyle(
                            color: AppColors.background,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            )
          : const Center(
              child: CircularProgressIndicator(
                color: AppColors.accent,
              ),
            ),
    );
  }
}
