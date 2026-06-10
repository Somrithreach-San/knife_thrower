import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'main.dart'; // To access GamePage and GameConfig
import 'difficulty_screen.dart';

import 'package:flame_audio/flame_audio.dart';

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
    // Precache the header image for Flutter's ImageCache
    precacheImage(
      const AssetImage('assets/images/header_bagckground_image.png'),
      context,
    );

    try {
      // 1. Pre-load Images into Flame's cache for the game
      final tempGame = KnifeThrowerGame();
      await tempGame.images.loadAll([
        'blue_knife.png',
        'red_knife.png',
        'pre_placed_knife.png',
        'tree_truck_target.png',
        'initial_cracked_tree_truck_target.png',
        'super_cracked_tree_truck_target.png',
        'mystery_box.png',
        'broken_red_knife.png',
        'broken_blue_knife.png',
      ]);

      // 2. Pre-load Audio Cache
      await FlameAudio.audioCache.loadAll([
        'Arrow_Hit_1.ogg',
        'Arrow_Hit_2.ogg',
        'Arrow_Hit_3.ogg',
        'Arrow_Throw_1.ogg',
        'Arrow_Throw_2.ogg',
        'Arrow_Throw_3.ogg',
        'Metal_Clashed.ogg',
        'Mystery_Box_Recieved.mp3',
        'Tree_trunk_target_cracking_1.mp3',
        'Tree_trunk_target_cracking_2.mp3',
      ]);
    } catch (error) {
      debugPrint('Asset load error: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD),
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
              color: Color(
                0xFFE3F2FD,
              ), // Base light blue color for the bottom half
            ),
            child: Stack(
              children: [
                // Header Background Image
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: screenHeight * 0.4, // Match the hard split height
                  child: Image.asset(
                    'assets/images/header_bagckground_image.png',
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      SizedBox(height: 80 * scale),
                      // Title
                      Text(
                        'KNIFE\nTHROWER',
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
                      // Main Card
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24 * scale),
                        child: Container(
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
                              SizedBox(height: 16 * scale),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Tap to throw knives. Land in\nthe wood, avoiding other\nknives. First to 20 wins.',
                                  textAlign: TextAlign.left,
                                  style: TextStyle(
                                    fontFamily: 'Programme',
                                    fontSize: 18 * scale,
                                    fontWeight: FontWeight.w900,
                                    height: 1.2,
                                    color: Colors.black.withValues(alpha: 0.85),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              // How to Play Button
                              Container(
                                padding: EdgeInsets.symmetric(
                                  vertical: 8 * scale,
                                  horizontal: 16 * scale,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF78909C),
                                  borderRadius: BorderRadius.circular(
                                    12 * scale,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(4 * scale),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF4CAF50),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.play_arrow,
                                        size: 16 * scale,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(width: 8 * scale),
                                    Text(
                                      'HOW TO PLAY',
                                      style: TextStyle(
                                        fontFamily: 'Programme',
                                        fontSize: 16 * scale,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              // Play vs Friend Button
                              _MenuButton(
                                label: 'FRIEND',
                                scale: scale,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => const GamePage(),
                                    ),
                                  );
                                },
                              ),
                              SizedBox(height: 16 * scale),
                              // Play vs Bot Button
                              _MenuButton(
                                label: 'BOT',
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
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 24 * scale),
                      // QUIT Button (Outside Card)
                      GestureDetector(
                        onTap: () => SystemNavigator.pop(),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            vertical: 12 * scale,
                            horizontal: 40 * scale,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE57373),
                            borderRadius: BorderRadius.circular(16 * scale),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFFC62828,
                                ).withValues(alpha: 0.3),
                                offset: Offset(0, 4 * scale),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: Text(
                            'QUIT',
                            style: TextStyle(
                              fontFamily: 'Programme',
                              fontSize: 18 * scale,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                    ],
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

class _MenuButton extends StatelessWidget {
  final String label;
  final double scale;
  final VoidCallback onTap;

  const _MenuButton({
    required this.label,
    required this.scale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          vertical: 16 * scale,
          horizontal: 20 * scale,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF1E88E5), // Blue button
          borderRadius: BorderRadius.circular(20 * scale),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0D47A1).withValues(alpha: 0.3),
              offset: Offset(0, 4 * scale),
              blurRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'PLAY VS.',
              style: TextStyle(
                fontFamily: 'Programme',
                fontSize: 12 * scale,
                fontWeight: FontWeight.w900,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Programme',
                fontSize: 28 * scale,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
