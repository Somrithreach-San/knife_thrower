import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'main.dart';
import 'bot_ai.dart';

class DifficultyScreen extends StatefulWidget {
  const DifficultyScreen({super.key});

  @override
  State<DifficultyScreen> createState() => _DifficultyScreenState();
}

class _DifficultyScreenState extends State<DifficultyScreen> {
  double _currentValue = 1.0; // 0.0: Easy, 1.0: Normal, 2.0: Hard

  final List<DifficultyData> _difficulties = [
    DifficultyData(
      label: 'EASY',
      color: const Color(0xFF4CAF50),
      difficulty: BotDifficulty.easy,
    ),
    DifficultyData(
      label: 'NORMAL',
      color: const Color(0xFFFFA000),
      difficulty: BotDifficulty.medium,
    ),
    DifficultyData(
      label: 'HARD',
      color: const Color(0xFFAA29C1),
      difficulty: BotDifficulty.hard,
    ),
  ];

  Color _getInterpolatedColor(double value) {
    if (value <= 1.0) {
      return Color.lerp(_difficulties[0].color, _difficulties[1].color, value)!;
    } else {
      return Color.lerp(
        _difficulties[1].color,
        const Color(0xFFAA29C1),
        value - 1.0,
      )!;
    }
  }

  String _getInterpolatedLabel(double value) {
    if (value < 0.5) return 'EASY';
    if (value < 1.5) return 'NORMAL';
    return 'HARD';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;
        final scale = math.min(
          screenWidth / GameConfig.baseWidth,
          screenHeight / GameConfig.baseHeight,
        );

        final currentIndex = _currentValue.round();
        final currentDifficulty = _difficulties[currentIndex];
        final activeColor = _getInterpolatedColor(_currentValue);

        return Scaffold(
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(color: Color(0xFFE3F2FD)),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: screenHeight * 0.4,
                  child: Image.asset(
                    'assets/images/header_bagckground_image.png',
                    fit: BoxFit.cover,
                  ),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      SizedBox(height: 80 * scale),
                      Text(
                        'DIFFICULTY',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Programme',
                          fontSize: 48 * scale,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 0.9,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              offset: const Offset(0, 4),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16 * scale),
                      const Spacer(),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24 * scale),
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.topCenter,
                          children: [
                            Container(
                              width: double.infinity,
                              height: screenHeight * 0.6,
                              padding: EdgeInsets.all(24 * scale),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(32 * scale),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  SizedBox(height: 50 * scale),
                                  Text(
                                    _getInterpolatedLabel(_currentValue),
                                    style: TextStyle(
                                      fontFamily: 'Programme',
                                      fontSize: 36 * scale,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const Spacer(),
                                  _CustomSlider(
                                    value: _currentValue,
                                    activeColor: activeColor,
                                    onChanged: (val) {
                                      setState(() {
                                        _currentValue = val;
                                      });
                                    },
                                  ),
                                  SizedBox(height: 12 * scale),
                                  Text(
                                    'Drag to adjust difficulty',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'Programme',
                                      fontSize: 16 * scale,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const Spacer(),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.of(context).pushReplacement(
                                        MaterialPageRoute(
                                          builder: (context) => GamePage(
                                            isBotMode: true,
                                            botDifficulty:
                                                currentDifficulty.difficulty,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      width: double.infinity,
                                      padding: EdgeInsets.symmetric(
                                        vertical: 16 * scale,
                                      ),
                                      decoration: BoxDecoration(
                                        color: activeColor,
                                        borderRadius: BorderRadius.circular(
                                          20 * scale,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.15,
                                            ),
                                            offset: Offset(0, 4 * scale),
                                            blurRadius: 0,
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          'PLAY',
                                          style: TextStyle(
                                            fontFamily: 'Programme',
                                            fontSize: 24 * scale,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              top: -55 * scale,
                              child: _DynamicBotIcon(
                                value: _currentValue,
                                color: activeColor,
                                scale: scale,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: EdgeInsets.only(bottom: 24 * scale),
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              vertical: 12 * scale,
                              horizontal: 40 * scale,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF78909C),
                              borderRadius: BorderRadius.circular(16 * scale),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF546E7A,
                                  ).withValues(alpha: 0.3),
                                  offset: Offset(0, 4 * scale),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                            child: Text(
                              'BACK',
                              style: TextStyle(
                                fontFamily: 'Programme',
                                fontSize: 18 * scale,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class DifficultyData {
  final String label;
  final Color color;
  final BotDifficulty difficulty;

  DifficultyData({
    required this.label,
    required this.color,
    required this.difficulty,
  });
}

class _DynamicBotIcon extends StatelessWidget {
  final double value;
  final Color color;
  final double scale;

  const _DynamicBotIcon({
    required this.value,
    required this.color,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120 * scale,
      height: 120 * scale,
      child: CustomPaint(
        painter: _BotFacePainter(value: value, color: color, scale: scale),
      ),
    );
  }
}

class _BotFacePainter extends CustomPainter {
  final double value;
  final Color color;
  final double scale;

  _BotFacePainter({
    required this.value,
    required this.color,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final headRadius = 40.0 * scale;

    final blackPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final whiteOutlinePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6 * scale;

    // --- Silhouette (Just Head) ---
    final fullPath = Path();
    fullPath.addOval(Rect.fromCircle(center: center, radius: headRadius));

    // Draw Fill
    canvas.drawPath(fullPath, fillPaint);

    // Draw White Border
    canvas.drawPath(fullPath, whiteOutlinePaint);

    // --- EYES ---
    void drawEye(Offset eyeCenter, bool left) {
      canvas.save();
      canvas.translate(eyeCenter.dx, eyeCenter.dy);

      if (value < 0.5) {
        // EASY: Large round eyes with sparkle
        final eyeSize = 24.0 * scale;
        canvas.drawCircle(Offset.zero, eyeSize / 2, blackPaint);
        canvas.drawCircle(
          Offset(0, -eyeSize * 0.15),
          eyeSize * 0.25,
          Paint()..color = Colors.white,
        );
      } else {
        // NORMAL/HARD: Focused angry eyes
        final angryProgress = (value - 0.5).clamp(0.0, 1.5) / 1.5;
        final eyeSize = (22.0 - 2.0 * angryProgress) * scale;

        canvas.rotate(
          left ? (math.pi / 8 * angryProgress) : (-math.pi / 8 * angryProgress),
        );

        final eyePath = Path();
        eyePath.addArc(
          Rect.fromCenter(center: Offset.zero, width: eyeSize, height: eyeSize),
          0,
          math.pi,
        );
        eyePath.close();
        canvas.drawPath(eyePath, blackPaint);

        // White pupils for NORMAL and HARD
        if (value >= 0.8) {
          final pupilProgress = (value - 0.8).clamp(0.0, 1.2) / 1.2;
          canvas.drawCircle(
            Offset(0, eyeSize * 0.1),
            (2 + 2 * pupilProgress) * scale,
            Paint()..color = Colors.white,
          );
        }
      }
      canvas.restore();
    }

    drawEye(center + Offset(-15 * scale, -5 * scale), true);
    drawEye(center + Offset(15 * scale, -5 * scale), false);

    // --- MOUTH ---
    canvas.save();
    canvas.translate(center.dx, center.dy + 22 * scale);

    final mouthPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * scale
      ..strokeCap = StrokeCap.round;

    if (value < 0.5) {
      // EASY: Frown
      final frownWidth = 20.0 * scale;
      final frownPath = Path();
      frownPath.moveTo(-frownWidth / 2, 5 * scale);
      frownPath.quadraticBezierTo(0, -2 * scale, frownWidth / 2, 5 * scale);
      canvas.drawPath(frownPath, mouthPaint);
    } else if (value < 1.5) {
      // NORMAL: Strange/Wavy mouth
      final mouthWidth = 22.0 * scale;
      final strangePath = Path();
      strangePath.moveTo(-mouthWidth / 2, 0);
      // Create a "wobble" or "strange" look
      strangePath.quadraticBezierTo(-mouthWidth / 4, -3 * scale, 0, 0);
      strangePath.quadraticBezierTo(
        mouthWidth / 4,
        3 * scale,
        mouthWidth / 2,
        0,
      );
      canvas.drawPath(strangePath, mouthPaint);
    } else {
      // HARD: Villain Smile (Upward Curve)
      final smileWidth = 36.0 * scale;
      final smileDepth = 10.0 * scale;

      final smilePath = Path();
      smilePath.moveTo(-smileWidth / 2, 0);
      smilePath.quadraticBezierTo(0, smileDepth, smileWidth / 2, 0);

      canvas.drawPath(smilePath, mouthPaint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BotFacePainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.color != color;
}

class _CustomSlider extends StatelessWidget {
  final double value;
  final Color activeColor;
  final ValueChanged<double> onChanged;

  const _CustomSlider({
    required this.value,
    required this.activeColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Determine track colors based on difficulty
    Color inactiveTrackColor = Colors.grey[300]!;

    return Container(
      width: double.infinity,
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: SliderTheme(
        data: SliderThemeData(
          trackHeight: 32,
          activeTrackColor: activeColor,
          inactiveTrackColor: inactiveTrackColor,
          thumbColor: Colors.white,
          overlayColor: activeColor.withValues(alpha: 0.2),
          thumbShape: _CustomThumbShape(color: activeColor),
          trackShape: const _CustomTrackShape(),
        ),
        child: Slider(
          value: value,
          min: 0.0,
          max: 2.0,
          divisions: 2,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _CustomThumbShape extends SliderComponentShape {
  final Color color;
  const _CustomThumbShape({required this.color});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(44, 44);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;

    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawCircle(center.translate(0, 2), 22, shadowPaint);
    canvas.drawCircle(center, 22, whitePaint);
    canvas.drawCircle(center, 22, borderPaint);

    final innerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 14, innerPaint);
  }
}

class _CustomTrackShape extends RoundedRectSliderTrackShape {
  const _CustomTrackShape();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = sliderTheme.trackHeight!;
    final double trackLeft = offset.dx;
    final double trackTop =
        offset.dy + (parentBox.size.height - trackHeight) / 2;
    final double trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}
