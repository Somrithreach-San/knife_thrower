import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'mode_selection_screen.dart';
import 'customization_page.dart';
import 'main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
      await precacheImage(
        const AssetImage('assets/images/Home_page_logo.png'),
        context,
      );
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A1628),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0D1D36), Color(0xFF0B172A), Color(0xFF091222)],
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF2CDFA2),
              strokeWidth: 3,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final screenHeight = constraints.maxHeight;

          // For desktop/wide screens, scale content cleanly up to 1.1x without ballooning
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
                  Color(0xFF0D1D36),
                  Color(0xFF0B172A),
                  Color(0xFF091222),
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
                            '2 PLAYER GAME',
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
                            'KNIFE THROWER',
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

                          // Play Button (Green)
                          GameButton(
                            label: 'PLAY',
                            mainColor: const Color(0xFF2CDFA2),
                            accentColor: const Color(0xFF52EBB6),
                            lipColor: const Color(0xFF1C9B71),
                            scale: scale,
                            fontSize: 20,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ModeSelectionScreen(),
                                ),
                              );
                            },
                          ),
                          SizedBox(height: 20 * scale),

                          // Customization Button (Orange/Yellow - matching Figma)
                          GameButton(
                            label: 'CUSTOMIZATION',
                            mainColor: const Color(0xFFFFA000),
                            accentColor: const Color(0xFFFFB74D),
                            lipColor: const Color(0xFFD97706),
                            scale: scale,
                            fontSize: 16,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const CustomizationPage(),
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
              ],
            ),
          );
        },
      ),
    );
  }
}
