import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Unified single loading indicator for the entire application.
/// Styled after the Android / Google Play Store wavy / squiggle circular installation progress indicator.
class AppLoadingIndicator extends StatefulWidget {
  final double size;
  final Color color;
  final Color? trackColor;

  const AppLoadingIndicator({
    super.key,
    this.size = 40.0,
    this.color = const Color(0xFF2CDFA2),
    this.trackColor,
  });

  @override
  State<AppLoadingIndicator> createState() => _AppLoadingIndicatorState();
}

class _AppLoadingIndicatorState extends State<AppLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A3050), Color(0xFF162844), Color(0xFF122038)],
        ),
      ),
      child: Center(
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: _PlayStoreSquigglePainter(
                  progress: _controller.value,
                  color: widget.color,
                  trackColor: widget.trackColor ??
                      widget.color.withValues(alpha: 0.15),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PlayStoreSquigglePainter extends CustomPainter {
  final double progress; // 0.0 -> 1.0
  final Color color;
  final Color trackColor;

  _PlayStoreSquigglePainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final strokeWidth = size.width * 0.09;
    // baseRadius: the fixed orbit radius — squiggle wiggles around this
    final baseRadius = (size.width - strokeWidth) / 2 - strokeWidth * 0.5;

    // No background track ring — matches Google Play style (just the traveling squiggle)

    // Active wave properties
    const int wavesCount = 6; // undulations around the arc
    // Amplitude kept well under half-strokeWidth so squiggle never touches
    // the track-ring radius from outside the arc band.
    final double waveAmplitude = strokeWidth * 0.22;

    // Rotating overall angle + dynamic expansion/contraction of arc length
    final double baseRotation = progress * 2 * math.pi * 1.5;
    // Arc length oscillates smoothly between ~0.4π and ~1.4π
    final double arcLength =
        (0.40 + 0.50 * (0.5 + 0.5 * math.sin(progress * 2 * math.pi))) *
        math.pi;

    final wavePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    const int steps = 120; // higher step count for smoother squiggle
    bool started = false;

    for (int i = 0; i <= steps; i++) {
      final double fraction = i / steps;
      final double theta = baseRotation + fraction * arcLength;

      // Phase travels forward creating the Google Play ripple effect
      final double wavePhase = progress * 2 * math.pi * 4.0;
      final double radiusOffset =
          math.sin(fraction * wavesCount * math.pi * 2 - wavePhase) *
          waveAmplitude;
      final double currentRadius = baseRadius + radiusOffset;

      final double x = center.dx + currentRadius * math.cos(theta);
      final double y = center.dy + currentRadius * math.sin(theta);

      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, wavePaint);
  }

  @override
  bool shouldRepaint(covariant _PlayStoreSquigglePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor;
  }
}

/// Fullscreen scaffold wrapper around [AppLoadingIndicator].
class AppLoadingScreen extends StatelessWidget {
  const AppLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF182842),
      body: AppLoadingIndicator(),
    );
  }
}
