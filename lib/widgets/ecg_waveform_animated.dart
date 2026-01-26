import 'dart:async';
import 'package:flutter/material.dart';

class AnimatedECG extends StatefulWidget {
  final bool isRunning;
  final Stream<int>? dataStream; // Receiving external stream

  const AnimatedECG({super.key, required this.isRunning, this.dataStream});

  @override
  State<AnimatedECG> createState() => _AnimatedECGState();
}

class _AnimatedECGState extends State<AnimatedECG> {
  final List<double> _points = [];
  StreamSubscription<int>? _subscription;

  @override
  void initState() {
    super.initState();
    if (widget.dataStream != null) {
      _subscribeToStream();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedECG oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Re-subscribe if stream changes
    if (widget.dataStream != oldWidget.dataStream) {
      _subscription?.cancel();
      if (widget.dataStream != null) {
        _subscribeToStream();
      }
    }
  }

  void _subscribeToStream() {
    _subscription = widget.dataStream!.listen((data) {
      if (!widget.isRunning) return; // ignore data if stopped

      if (_points.length > 150) {
        // Increase buffer size for longer trace if needed, keeping 150 as original
        _points.removeAt(0);
      }

      // Scaling: Fixed scale as originally requested
      // /50.0 was the original value the user liked
      double value = data / 50.0;

      _points.add(value);

      // Force repaint
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: CustomPaint(painter: _ECGPainter(_points), size: Size.infinite),
    );
  }
}

class _ECGPainter extends CustomPainter {
  final List<double> points;

  _ECGPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    final midY = size.height / 2;
    // Fixed step: width / 150
    final stepX = size.width / 150;

    for (int i = 0; i < points.length; i++) {
      final x = i * stepX;
      // Invert Y because canvas Y starts from top
      final y = midY - points[i];

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
