import 'package:flutter/material.dart';

class PoseOverlayPainter extends CustomPainter {
  final bool showGuidelines;
  final Color guidelineColor;

  PoseOverlayPainter({
    this.showGuidelines = true,
    this.guidelineColor = Colors.white,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!showGuidelines) return;

    final paint = Paint()
      ..color = guidelineColor.withOpacity(0.5)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final dashedPaint = Paint()
      ..color = guidelineColor.withOpacity(0.3)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Draw vertical center line (main guideline)
    final centerX = size.width / 2;
    canvas.drawLine(
      Offset(centerX, 0),
      Offset(centerX, size.height),
      paint,
    );

    // Draw horizontal guidelines for body parts
    // These are positioned at typical body proportion ratios
    final guidelines = {
      0.10: 'Head Top',
      0.15: 'Eyes',
      0.20: 'Chin',
      0.30: 'Shoulders',
      0.45: 'Chest',
      0.55: 'Waist',
      0.65: 'Hips',
      0.80: 'Knees',
      0.95: 'Ankles',
    };

    for (var entry in guidelines.entries) {
      final y = size.height * entry.key;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        dashedPaint,
      );
    }

    // Draw body outline template (simplified silhouette)
    _drawBodySilhouette(canvas, size, paint);

    // Draw corner markers
    _drawCornerMarkers(canvas, size, paint);
  }

  void _drawBodySilhouette(Canvas canvas, Size size, Paint paint) {
    final silhouettePaint = Paint()
      ..color = guidelineColor.withOpacity(0.2)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    final centerX = size.width / 2;
    final shoulderWidth = size.width * 0.35;
    final hipWidth = size.width * 0.30;

    // Head (circle)
    canvas.drawCircle(
      Offset(centerX, size.height * 0.12),
      size.width * 0.08,
      silhouettePaint,
    );

    // Body outline
    path.moveTo(centerX - shoulderWidth / 2, size.height * 0.30); // Left shoulder
    path.lineTo(centerX - shoulderWidth / 2, size.height * 0.50); // Left side
    path.lineTo(centerX - hipWidth / 2, size.height * 0.65); // Left hip
    path.lineTo(centerX - hipWidth / 2 - 20, size.height * 0.95); // Left ankle

    // Right side
    path.moveTo(centerX + shoulderWidth / 2, size.height * 0.30); // Right shoulder
    path.lineTo(centerX + shoulderWidth / 2, size.height * 0.50); // Right side
    path.lineTo(centerX + hipWidth / 2, size.height * 0.65); // Right hip
    path.lineTo(centerX + hipWidth / 2 + 20, size.height * 0.95); // Right ankle

    // Arms
    path.moveTo(centerX - shoulderWidth / 2, size.height * 0.30); // Left shoulder
    path.lineTo(centerX - shoulderWidth / 2 - 30, size.height * 0.50); // Left hand

    path.moveTo(centerX + shoulderWidth / 2, size.height * 0.30); // Right shoulder
    path.lineTo(centerX + shoulderWidth / 2 + 30, size.height * 0.50); // Right hand

    canvas.drawPath(path, silhouettePaint);
  }

  void _drawCornerMarkers(Canvas canvas, Size size, Paint paint) {
    final markerPaint = Paint()
      ..color = guidelineColor
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final markerSize = 20.0;
    final corners = [
      Offset(0, 0), // Top-left
      Offset(size.width, 0), // Top-right
      Offset(0, size.height), // Bottom-left
      Offset(size.width, size.height), // Bottom-right
    ];

    for (var corner in corners) {
      // Horizontal line
      canvas.drawLine(
        corner,
        corner + Offset(corner.dx == 0 ? markerSize : -markerSize, 0),
        markerPaint,
      );
      // Vertical line
      canvas.drawLine(
        corner,
        corner + Offset(0, corner.dy == 0 ? markerSize : -markerSize),
        markerPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant PoseOverlayPainter oldDelegate) {
    return oldDelegate.showGuidelines != showGuidelines ||
        oldDelegate.guidelineColor != guidelineColor;
  }
}

// Widget wrapper for the overlay
class PoseOverlay extends StatelessWidget {
  final bool showGuidelines;
  final Color guidelineColor;

  const PoseOverlay({
    super.key,
    this.showGuidelines = true,
    this.guidelineColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: PoseOverlayPainter(
        showGuidelines: showGuidelines,
        guidelineColor: guidelineColor,
      ),
      child: Container(),
    );
  }
}
