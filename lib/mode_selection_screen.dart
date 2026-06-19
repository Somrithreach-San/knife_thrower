import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'main.dart'; // To access GamePage and GameConfig
import 'difficulty_screen.dart';
import 'back_arrow_button.dart';

enum GameButtonIcon { vsFriend, vsBot, easy, normal, hard }

class GameButton extends StatefulWidget {
  final String label;
  final Color mainColor;
  final Color accentColor;
  final Color lipColor;
  final GameButtonIcon? icon;
  final VoidCallback? onTap;
  final double scale;
  final double fontSize;

  const GameButton({
    super.key,
    required this.label,
    required this.mainColor,
    required this.accentColor,
    required this.lipColor,
    this.icon,
    this.onTap,
    this.scale = 1.0,
    this.fontSize = 16,
  });

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    const lipHeight = 2.0;
    const baseWidth = 230.0;
    const baseHeight = 64.0;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: SizedBox(
        width: baseWidth * widget.scale,
        height: baseHeight * widget.scale,
        child: Stack(
          children: [
            // 3D bottom lip
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 60 * widget.scale,
              child: Container(
                decoration: BoxDecoration(
                  color: widget.lipColor,
                  borderRadius: BorderRadius.circular(8 * widget.scale),
                ),
              ),
            ),
            // Main face
            AnimatedPositioned(
              duration: _pressed
                  ? const Duration(milliseconds: 50)
                  : const Duration(milliseconds: 100),
              top: _pressed ? lipHeight * widget.scale : 0,
              left: 0,
              right: 0,
              bottom: _pressed ? 0 : lipHeight * widget.scale,
              child: Container(
                decoration: BoxDecoration(
                  color: widget.mainColor,
                  borderRadius: BorderRadius.circular(8 * widget.scale),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8 * widget.scale),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Angled accent panel (only if icon exists)
                      if (widget.icon != null)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _AccentPanelPainter(
                              accentColor: widget.accentColor,
                              lipColor: widget.lipColor,
                            ),
                          ),
                        ),
                      // Icon (only if exists)
                      if (widget.icon != null)
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: baseWidth * 0.28 * widget.scale,
                          child: Center(child: _buildIcon()),
                        ),
                      // Text
                      Positioned(
                        left: widget.icon != null
                            ? baseWidth * 0.28 * widget.scale
                            : 0,
                        top: 0,
                        right: 0,
                        bottom: 0,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8 * widget.scale,
                          ),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                widget.label,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: widget.fontSize * widget.scale,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'Montserrat',
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.2,
                                      ),
                                      offset: const Offset(0, 1),
                                      blurRadius: 3,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    switch (widget.icon) {
      case GameButtonIcon.vsFriend:
        return SizedBox(
          width: 28 * widget.scale,
          height: 28 * widget.scale,
          child: Image.asset(
            'assets/images/vs_friend.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        );
      case GameButtonIcon.vsBot:
        return SizedBox(
          width: 28 * widget.scale,
          height: 28 * widget.scale,
          child: Image.asset(
            'assets/images/vs_bot.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        );
      case GameButtonIcon.easy:
        return SizedBox(
          width: 28 * widget.scale,
          height: 28 * widget.scale,
          child: Image.asset(
            'assets/images/easy_mode.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        );
      case GameButtonIcon.normal:
        return SizedBox(
          width: 28 * widget.scale,
          height: 28 * widget.scale,
          child: Image.asset(
            'assets/images/normal_mode.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        );
      case GameButtonIcon.hard:
        return SizedBox(
          width: 28 * widget.scale,
          height: 28 * widget.scale,
          child: Image.asset(
            'assets/images/hard_mode.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        );
      case null:
        return const SizedBox.shrink();
    }
  }
}

class _AccentPanelPainter extends CustomPainter {
  final Color accentColor;
  final Color lipColor;

  _AccentPanelPainter({required this.accentColor, required this.lipColor});

  @override
  void paint(Canvas canvas, Size size) {
    final accentPaint = Paint()..color = accentColor;
    final dividerPaint = Paint()..color = lipColor.withValues(alpha: 0.7);

    // Accent zone polygon
    final accentPath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.28 * (100 / 85), 0)
      ..lineTo(size.width * 0.28, size.height)
      ..lineTo(0, size.height)
      ..close();

    // Divider strip polygon
    final dividerPath = Path()
      ..moveTo(size.width * 0.28 * (96 / 85), 0)
      ..lineTo(size.width * 0.28 * (100 / 85), 0)
      ..lineTo(size.width * 0.28, size.height)
      ..lineTo(size.width * 0.28 * (81 / 85), size.height)
      ..close();

    canvas.drawPath(accentPath, accentPaint);
    canvas.drawPath(dividerPath, dividerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ModeSelectionScreen extends StatefulWidget {
  const ModeSelectionScreen({super.key});

  @override
  State<ModeSelectionScreen> createState() => _ModeSelectionScreenState();
}

class _ModeSelectionScreenState extends State<ModeSelectionScreen> {
  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    // Precache the logo for Flutter's ImageCache
    precacheImage(
      const AssetImage('assets/images/Home_page_logo.png'),
      context,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final screenHeight = constraints.maxHeight;
          final scale = math.min(
            screenWidth / GameConfig.baseWidth,
            screenHeight / GameConfig.baseHeight,
          );

          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1a1a2e),
                  Color(0xFF16213e),
                  Color(0xFF0f3460),
                ],
              ),
            ),
            child: SafeArea(
              bottom: true,
              left: true,
              right: true,
              top: false,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Main Content
                  Padding(
                    padding: EdgeInsets.only(
                      left: 32 * scale,
                      right: 32 * scale,
                      bottom: 32 * scale,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Logo at very top
                        Image.asset(
                          'assets/images/Home_page_logo.png',
                          width: screenWidth * 0.7,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                        // Spacer to push buttons to center
                        const Spacer(),
                        // Title
                        Text(
                          'CHOOSE YOUR MODE',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14 * scale,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.5),
                            fontFamily: 'Montserrat',
                          ),
                        ),
                        SizedBox(height: 6 * scale),
                        Text(
                          'START PLAYING',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 30 * scale,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                        SizedBox(height: 40 * scale),
                        // Play vs Friend Button
                        GameButton(
                          label: 'VS. FRIEND',
                          mainColor: const Color(0xFF2CDFA2),
                          accentColor: const Color(0xFF52EBB6),
                          lipColor: const Color(0xFF1C9B71),
                          icon: GameButtonIcon.vsFriend,
                          scale: scale,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const GamePage(),
                              ),
                            );
                          },
                        ),
                        SizedBox(height: 25 * scale),
                        // Play vs Bot Button
                        GameButton(
                          label: 'VS. BOT',
                          mainColor: const Color(0xFFFFB300),
                          accentColor: const Color(0xFFFFCA28),
                          lipColor: const Color(0xFFC67C00),
                          icon: GameButtonIcon.vsBot,
                          scale: scale,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const DifficultyScreen(),
                              ),
                            );
                          },
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                  // Back Arrow (on top of content)
                  Positioned(
                    top: 16 * scale,
                    left: 16 * scale,
                    child: SafeArea(
                      child: BackArrowButton(
                        onTap: () => Navigator.of(context).pop(),
                        scale: scale,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
