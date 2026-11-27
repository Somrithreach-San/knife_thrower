import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'main.dart'; // To access GamePage and GameConfig
import 'friend_mode_screen.dart';
import 'difficulty_screen.dart';
import 'back_arrow_button.dart';
import 'widgets/app_loading_indicator.dart';

enum GameButtonIcon { vsFriend, vsBot, local, online, easy, normal, hard }

class GameButton extends StatefulWidget {
  final String label;
  final Color mainColor;
  final Color accentColor;
  final Color lipColor;
  final GameButtonIcon? icon;
  final VoidCallback? onTap;
  final double scale;
  final double fontSize;
  final double? width;
  final double? height;

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
    this.width,
    this.height,
  });

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    const defaultWidth = 230.0;
    const defaultHeight = 64.0;
    const defaultLipHeight = 8.0;

    final width = (widget.width ?? defaultWidth) * widget.scale;
    final height = (widget.height ?? defaultHeight) * widget.scale;
    final lipHeight = defaultLipHeight * widget.scale;
    const borderRadius = 6.0; // Matches Figma spec (not scaled — px value is absolute)

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            children: [
              // 3D bottom lip (full-height rounded base behind face so corners have no gap)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: height - lipHeight,
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.lipColor,
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                ),
              ),
              // Main face with press animation
              AnimatedPositioned(
                duration: _pressed
                    ? const Duration(milliseconds: 50)
                    : const Duration(milliseconds: 100),
                curve: Curves.easeOutCubic,
                top: _pressed ? lipHeight : 0,
                left: 0,
                right: 0,
                bottom: _pressed ? 0 : lipHeight,
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.mainColor,
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(borderRadius),
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
                        // Icon (only if exists) - centered within accent zone
                        if (widget.icon != null)
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            width: width * 0.28,
                            child: Center(
                              child: ConstrainedBox(
                                // maxWidth keeps icon inside the accent zone.
                                // maxHeight is relaxed (1.8×) so vs_friend's large
                                // transparent padding doesn't shrink the actual figures —
                                // the outer ClipRRect already clips visual overflow.
                                constraints: BoxConstraints(
                                  maxWidth: width * 0.28,
                                  maxHeight: (height - lipHeight) * 2.2,
                                ),
                                child: FittedBox(
                                  fit: BoxFit.contain,
                                  child: _buildIcon(),
                                ),
                              ),
                            ),
                          ),
                        // Text - centered horizontally
                        Positioned(
                          left: widget.icon != null ? width * 0.28 : 0,
                          top: 0,
                          right: 0,
                          bottom: 0,
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.0 * widget.scale,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  widget.label,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: widget.fontSize * widget.scale,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'Montserrat',
                                    letterSpacing: 0.5 * widget.scale,
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
      ),
    );
  }

  Widget _buildIcon() {
    switch (widget.icon) {
      case GameButtonIcon.vsFriend:
        // vs_friend.png has ~50% empty transparent padding around its content
        // whereas vs_bot fills ~90% of its canvas. Sized up to match visual height & weight.
        return SizedBox(
          width: 90 * widget.scale,
          height: 90 * widget.scale,
          child: Image.asset(
            'assets/images/vs_friend.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        );
      case GameButtonIcon.vsBot:
        return SizedBox(
          width: 24 * widget.scale,
          height: 24 * widget.scale,
          child: Image.asset(
            'assets/images/vs_bot.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        );
      case GameButtonIcon.local:
        return SizedBox(
          width: 30 * widget.scale,
          height: 30 * widget.scale,
          child: Image.asset(
            'assets/images/vs_friend_local.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        );
      case GameButtonIcon.easy:
        return SizedBox(
          width: 24 * widget.scale,
          height: 24 * widget.scale,
          child: Image.asset(
            'assets/images/easy_mode.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        );
      case GameButtonIcon.normal:
        return SizedBox(
          width: 24 * widget.scale,
          height: 24 * widget.scale,
          child: Image.asset(
            'assets/images/normal_mode.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        );
      case GameButtonIcon.online:
        return SizedBox(
          width: 24 * widget.scale,
          height: 24 * widget.scale,
          child: Image.asset(
            'assets/images/vs_friend_online.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        );
      case GameButtonIcon.hard:
        return SizedBox(
          width: 24 * widget.scale,
          height: 24 * widget.scale,
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
  bool shouldRepaint(covariant _AccentPanelPainter oldDelegate) {
    return oldDelegate.accentColor != accentColor ||
        oldDelegate.lipColor != lipColor;
  }
}

class ModeSelectionScreen extends StatefulWidget {
  const ModeSelectionScreen({super.key});

  @override
  State<ModeSelectionScreen> createState() => _ModeSelectionScreenState();
}

class _ModeSelectionScreenState extends State<ModeSelectionScreen> {
  bool _isLoading = true;
  bool _assetsPrecached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_assetsPrecached) {
      _assetsPrecached = true;
      _loadAssets();
    }
  }

  Future<void> _loadAssets() async {
    try {
      await Future.wait([
        precacheImage(
          const AssetImage('assets/images/Home_page_logo.png'),
          context,
        ),
        precacheImage(const AssetImage('assets/images/vs_friend.png'), context),
        precacheImage(const AssetImage('assets/images/vs_bot.png'), context),
      ]);
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AppLoadingScreen();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF182842),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final screenHeight = constraints.maxHeight;

          final bool isDesktop = screenWidth >= 768 && screenHeight >= 500;
          final double effectiveContentWidth = isDesktop ? 400.0 : screenWidth;
          final scale = isDesktop
              ? math.min(1.1, screenHeight / GameConfig.baseHeight)
              : math.min(
                  screenWidth / GameConfig.baseWidth,
                  screenHeight / GameConfig.baseHeight,
                );

          final double logoWidth = isDesktop
              ? math.min(380.0, screenWidth * 0.35)
              : screenWidth * 0.7;

          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1A3050),
                  Color(0xFF162844),
                  Color(0xFF122038),
                ],
              ),
            ),
            child: Stack(
              children: [
                // Top Centered Logo
                Align(
                  alignment: Alignment.topCenter,
                  child: Image.asset(
                    'assets/images/Home_page_logo.png',
                    width: logoWidth,
                    fit: BoxFit.contain,
                  ),
                ),

                // Centered Main Content
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: effectiveContentWidth,
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32 * scale),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Spacer(flex: 7),

                          // Subtitle
                          Text(
                            'CHOOSE YOUR MODE',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13 * scale,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.6),
                              fontFamily: 'Montserrat',
                              letterSpacing: 1.2,
                            ),
                          ),
                          SizedBox(height: 8 * scale),

                          // Title
                          Text(
                            'START PLAYING',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 30 * scale,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              fontFamily: 'Montserrat',
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 36 * scale),

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
                                  builder: (context) =>
                                      const FriendModeScreen(),
                                ),
                              );
                            },
                          ),
                          SizedBox(height: 20 * scale),

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
                                  builder: (context) =>
                                      const DifficultyScreen(),
                                ),
                              );
                            },
                          ),
                          const Spacer(flex: 3),
                        ],
                      ),
                    ),
                  ),
                ),

                // Back Arrow Button
                Positioned(
                  top: 24,
                  left: 24,
                  child: SafeArea(
                    child: BackArrowButton(
                      onTap: () => Navigator.of(context).pop(),
                      scale: scale,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
