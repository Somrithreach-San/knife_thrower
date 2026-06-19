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
              child: Padding(
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
                      '2 PLAYER GAME',
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
                      'KNIFE THROWER',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30 * scale,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                    SizedBox(height: 40 * scale),
                    // Play Button
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
                            builder: (context) => const ModeSelectionScreen(),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 25 * scale),
                    // Customization Button
                    GameButton(
                      label: 'CUSTOMIZATION',
                      mainColor: const Color(0xFF999999),
                      accentColor: const Color(0xFF404040),
                      lipColor: const Color(0xFF747373),
                      scale: scale,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const CustomizationPage(),
                          ),
                        );
                      },
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
