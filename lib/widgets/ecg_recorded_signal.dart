import 'package:flutter/material.dart';

/// Simple ECG Recorded Signal Display
/// Matches the style of live monitoring display for consistency
class RecordedECGSignal extends StatelessWidget {
  final List<int> ecgData;
  final int samplingRate;

  const RecordedECGSignal({
    super.key,
    required this.ecgData,
    required this.samplingRate,
  });

  @override
  Widget build(BuildContext context) {
    if (ecgData.isEmpty) {
      return Container(
        height: 240,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.signal_cellular_off, color: Colors.grey, size: 48),
              SizedBox(height: 16),
              Text(
                "No recorded ECG available",
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    // Downsample to ~150 points for smooth display (same as live monitoring)
    final List<double> displayPoints = _downsampleSignal(ecgData, 150);

    return Container(
      height: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CustomPaint(
          painter: _RecordedECGPainter(displayPoints),
          size: Size.infinite,
        ),
      ),
    );
  }

  /// Downsample ECG data to a manageable number of points
  List<double> _downsampleSignal(List<int> rawData, int targetPoints) {
    if (rawData.length <= targetPoints) {
      // If data is already small, just scale it
      return rawData.map((e) => e / 50.0).toList();
    }

    final int step = (rawData.length / targetPoints).ceil();
    final List<double> downsampled = [];

    for (int i = 0; i < rawData.length; i += step) {
      downsampled.add(rawData[i] / 50.0);
    }

    return downsampled;
  }
}

class _RecordedECGPainter extends CustomPainter {
  final List<double> points;

  _RecordedECGPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    // ===== BACKGROUND WITH GRADIENT =====
    final backgroundPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF0F172A), // Dark blue-grey
          const Color(0xFF1E293B), // Slightly lighter
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      backgroundPaint,
    );

    // ===== GRID LINES (Medical ECG style) =====
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 0.5;

    // Vertical grid lines
    const gridSpacing = 20.0;
    for (double x = 0; x < size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // Horizontal grid lines
    for (double y = 0; y < size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // ===== MINOR GRID LINES =====
    final minorGridPaint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 0.3;

    const minorSpacing = 4.0;
    for (double x = 0; x < size.width; x += minorSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), minorGridPaint);
    }

    for (double y = 0; y < size.height; y += minorSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), minorGridPaint);
    }

    // ===== BASELINE (Center Line) =====
    final baselinePaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 1.5;

    final midY = size.height / 2;
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), baselinePaint);

    // ===== ECG WAVEFORM =====
    if (points.isEmpty) return;

    final waveformPaint = Paint()
      ..color = Colors
          .cyanAccent // Bright cyan for visibility
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();

    // Fit entire signal across width
    final stepX = size.width / points.length;

    for (int i = 0; i < points.length; i++) {
      final x = i * stepX;
      final y = midY - points[i];

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Draw waveform with glow effect
    // Glow layer
    final glowPaint = Paint()
      ..color = Colors.cyan.withOpacity(0.2)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, glowPaint);

    // Main waveform
    canvas.drawPath(path, waveformPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
