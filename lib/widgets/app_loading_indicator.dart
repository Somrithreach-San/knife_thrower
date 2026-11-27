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
    final baseRadius = (size.width - strokeWidth) / 2 - strokeWidth * 0.5;

    // Active wave properties
    const int wavesCount = 8; // Number of sinusoidal undulations around circle
    final double waveAmplitude = strokeWidth * 0.55;

    // Rotating overall angle + dynamic expansion/contraction of arc length.
    // Integer multiplier (2.0) ensures that at progress = 1.0 (wrap to 0.0),
    // baseRotation is an exact multiple of 2*pi, avoiding any snap/jump!
    final double baseRotation = progress * 2 * math.pi * 2.0;
    // Length oscillates smoothly between 0.35pi and 1.35pi, completing exactly 2 cycles
    final double arcLength =
        (0.35 + 0.50 * (0.5 + 0.5 * math.sin(progress * 4 * math.pi))) *
        math.pi;

    // Draw background track arc only where the squiggle is NOT present,
    // leaving a clean gap at both ends so the squiggle never overlaps the track.
    final double gapAngle = (strokeWidth * 1.4) / baseRadius;
    final double trackSweep = 2 * math.pi - arcLength - 2 * gapAngle;
    if (trackSweep > 0.05) {
      final trackPaint = Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 0.7
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: baseRadius),
        baseRotation + arcLength + gapAngle,
        trackSweep,
        false,
        trackPaint,
      );
    }

    final wavePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final path = Path();
    const int steps = 90;
    bool started = false;

    // Integer wave frequency on progress (e.g. 4.0 cycles) so the wave phase
    // wraps seamlessly without any jump when progress loops from 1.0 -> 0.0.
    final double wavePhase = progress * 2 * math.pi * 4.0;

    for (int i = 0; i <= steps; i++) {
      final double fraction = i / steps;
      final double theta = baseRotation + fraction * arcLength;

      // Squiggle wave calculation: offset radius by sine of wave frequency
      // Phase travels along the wave creating the signature Google Play wobble/ripple
      final double radiusOffset =
          math.sin(theta * wavesCount - wavePhase) * waveAmplitude;
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
