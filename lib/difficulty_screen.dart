// import 'package:flutter/material.dart';
// import 'package:flutter/cupertino.dart';
// import 'dart:math' as math;
// import 'main.dart';
// import 'bot_ai.dart';
// import 'mode_selection_screen.dart';
// import 'back_arrow_button.dart';

// class DifficultyScreen extends StatefulWidget {
//   const DifficultyScreen({super.key});

//   @override
//   State<DifficultyScreen> createState() => _DifficultyScreenState();
// }

// class _DifficultyScreenState extends State<DifficultyScreen> {
//   int _selectedIndex = 1; // 0: Easy, 1: Normal, 2: Hard
//   final FixedExtentScrollController _scrollController =
//       FixedExtentScrollController(initialItem: 1);

//   final List<DifficultyData> _difficulties = [
//     DifficultyData(
//       label: 'EASY',
//       mainColor: const Color(0xFF2CDFA2),
//       accentColor: const Color(0xFF52EBB6),
//       lipColor: const Color(0xFF1C9B71),
//       difficulty: BotDifficulty.easy,
//     ),
//     DifficultyData(
//       label: 'NORMAL',
//       mainColor: const Color(0xFFFFB300),
//       accentColor: const Color(0xFFFFCA28),
//       lipColor: const Color(0xFFC67C00),
//       difficulty: BotDifficulty.medium,
//     ),
//     DifficultyData(
//       label: 'HARD',
//       mainColor: const Color(0xFFAA29C1),
//       accentColor: const Color(0xFFBA68C8),
//       lipColor: const Color(0xFF8E24AA),
//       difficulty: BotDifficulty.hard,
//     ),
//   ];

//   @override
//   void dispose() {
//     _scrollController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: LayoutBuilder(
//         builder: (context, constraints) {
//           final screenWidth = constraints.maxWidth;
//           final screenHeight = constraints.maxHeight;
//           final scale = math.min(
//             screenWidth / GameConfig.baseWidth,
//             screenHeight / GameConfig.baseHeight,
//           );

//           final currentDifficulty = _difficulties[_selectedIndex];

//           return Container(
//             width: double.infinity,
//             height: double.infinity,
//             decoration: const BoxDecoration(
//               gradient: LinearGradient(
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//                 colors: [
//                   Color(0xFF1a1a2e),
//                   Color(0xFF16213e),
//                   Color(0xFF0f3460),
//                 ],
//               ),
//             ),
//             child: SafeArea(
//               child: Stack(
//                 children: [
//                   // Back Arrow
//                   Positioned(
//                     top: 16 * scale,
//                     left: 16 * scale,
//                     child: BackArrowButton(
//                       onTap: () => Navigator.of(context).pop(),
//                       scale: scale,
//                     ),
//                   ),
//                   // Main Content
//                   Center(
//                     child: Padding(
//                       padding: EdgeInsets.symmetric(horizontal: 32 * scale),
//                       child: Column(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         crossAxisAlignment: CrossAxisAlignment.center,
//                         children: [
//                           // Title
//                           Text(
//                             'SELECT DIFFICULTY',
//                             style: TextStyle(
//                               fontSize: 14 * scale,
//                               fontWeight: FontWeight.w700,
//                               color: Colors.white.withValues(alpha: 0.5),
//                               fontFamily: 'Montserrat',
//                             ),
//                           ),
//                           SizedBox(height: 40 * scale),
//                           // iOS-style Cupertino Picker
//                           SizedBox(
//                             height: 280 * scale,
//                             child: CupertinoPicker(
//                               magnification: 1.0,
//                               useMagnifier: false,
//                               itemExtent: 85 * scale,
//                               scrollController: _scrollController,
//                               onSelectedItemChanged: (int index) {
//                                 setState(() {
//                                   _selectedIndex = index;
//                                 });
//                               },
//                               children: List<Widget>.generate(
//                                 _difficulties.length,
//                                 (int index) {
//                                   final difficulty = _difficulties[index];
//                                   return Center(
//                                     child: SizedBox(
//                                       width: 230 * scale,
//                                       height: 64 * scale,
//                                       child: GameButton(
//                                         label: difficulty.label,
//                                         mainColor: difficulty.mainColor,
//                                         accentColor: difficulty.accentColor,
//                                         lipColor: difficulty.lipColor,
//                                         icon: [
//                                           GameButtonIcon.easy,
//                                           GameButtonIcon.normal,
//                                           GameButtonIcon.hard,
//                                         ][index],
//                                         scale: scale,
//                                         onTap: () {
//                                           setState(() {
//                                             _selectedIndex = index;
//                                             _scrollController.animateToItem(
//                                               index,
//                                               duration: const Duration(
//                                                 milliseconds: 250,
//                                               ),
//                                               curve: Curves.easeInOut,
//                                             );
//                                           });
//                                         },
//                                       ),
//                                     ),
//                                   );
//                                 },
//                               ),
//                             ),
//                           ),
//                           SizedBox(height: 60 * scale),
//                           // Play Text
//                           GestureDetector(
//                             onTap: () {
//                               Navigator.of(context).pushReplacement(
//                                 MaterialPageRoute(
//                                   builder: (context) => GamePage(
//                                     isBotMode: true,
//                                     botDifficulty: currentDifficulty.difficulty,
//                                   ),
//                                 ),
//                               );
//                             },
//                             child: Text(
//                               'PLAY',
//                               style: TextStyle(
//                                 color: Colors.white,
//                                 fontSize: 40 * scale,
//                                 fontWeight: FontWeight.w900,
//                                 fontFamily: 'Montserrat',
//                                 shadows: [
//                                   Shadow(
//                                     color: Colors.black.withValues(alpha: 0.2),
//                                     offset: const Offset(0, 1),
//                                     blurRadius: 3,
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }
// }

// class DifficultyData {
//   final String label;
//   final Color mainColor;
//   final Color accentColor;
//   final Color lipColor;
//   final BotDifficulty difficulty;

//   DifficultyData({
//     required this.label,
//     required this.mainColor,
//     required this.accentColor,
//     required this.lipColor,
//     required this.difficulty,
//   });
// }

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:math' as math;
import 'main.dart';
import 'bot_ai.dart';
import 'mode_selection_screen.dart';
import 'back_arrow_button.dart';

class _NoiseOverlayPainter extends CustomPainter {
  final _rng = math.Random(
    42,
  ); // fixed seed = same pattern every frame, no flicker

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    // Sparse, very faint dots — just enough to break up banding
    for (int i = 0; i < (size.width * size.height / 120).round(); i++) {
      final dx = _rng.nextDouble() * size.width;
      final dy = _rng.nextDouble() * size.height;
      paint.color = (_rng.nextBool() ? Colors.white : Colors.black).withValues(
        alpha: 0.015,
      );
      canvas.drawRect(Rect.fromLTWH(dx, dy, 1, 1), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _NoiseOverlayPainter oldDelegate) => false;
}

class DifficultyScreen extends StatefulWidget {
  const DifficultyScreen({super.key});

  @override
  State<DifficultyScreen> createState() => _DifficultyScreenState();
}

class _DifficultyScreenState extends State<DifficultyScreen> {
  int _selectedIndex = 1; // 0: Easy, 1: Normal, 2: Hard
  final FixedExtentScrollController _scrollController =
      FixedExtentScrollController(initialItem: 1);

  final List<DifficultyData> _difficulties = [
    DifficultyData(
      label: 'EASY',
      mainColor: const Color(0xFF2CDFA2),
      accentColor: const Color(0xFF52EBB6),
      lipColor: const Color(0xFF1C9B71),
      difficulty: BotDifficulty.easy,
    ),
    DifficultyData(
      label: 'NORMAL',
      mainColor: const Color(0xFFFFB300),
      accentColor: const Color(0xFFFFCA28),
      lipColor: const Color(0xFFC67C00),
      difficulty: BotDifficulty.medium,
    ),
    DifficultyData(
      label: 'HARD',
      mainColor: const Color(0xFFAA29C1),
      accentColor: const Color(0xFFBA68C8),
      lipColor: const Color(0xFF8E24AA),
      difficulty: BotDifficulty.hard,
    ),
  ];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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

          final currentDifficulty = _difficulties[_selectedIndex];

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
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: _NoiseOverlayPainter()),
                  ),
                ),
                SafeArea(
                  child: Stack(
                    children: [
                      // Back Arrow
                      Positioned(
                        top: 16 * scale,
                        left: 16 * scale,
                        child: BackArrowButton(
                          onTap: () => Navigator.of(context).pop(),
                          scale: scale,
                        ),
                      ),
                      // Main Content
                      Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32 * scale),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Title
                              Text(
                                'SELECT DIFFICULTY',
                                style: TextStyle(
                                  fontSize: 14 * scale,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontFamily: 'Montserrat',
                                ),
                              ),
                              SizedBox(height: 40 * scale),
                              // Flat (non-3D) scrolling list, no wheel tilt
                              SizedBox(
                                height: 280 * scale,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Highlight box behind the centered/selected item
                                    IgnorePointer(
                                      child: Container(
                                        width: 250 * scale,
                                        height: 78 * scale,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.06,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            16 * scale,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.25,
                                            ),
                                            width: 1.5 * scale,
                                          ),
                                        ),
                                      ),
                                    ),
                                    ListWheelScrollView.useDelegate(
                                      itemExtent: 85 * scale,
                                      diameterRatio:
                                          100.0, // very large -> flattens curvature
                                      perspective:
                                          0.0000001, // minimal -> removes 3D depth/tilt
                                      physics: const FixedExtentScrollPhysics(),
                                      controller: _scrollController,
                                      onSelectedItemChanged: (int index) {
                                        setState(() {
                                          _selectedIndex = index;
                                        });
                                      },
                                      childDelegate: ListWheelChildListDelegate(
                                        children: List<Widget>.generate(
                                          _difficulties.length,
                                          (int index) {
                                            final difficulty =
                                                _difficulties[index];
                                            final bool isSelected =
                                                index == _selectedIndex;
                                            return Center(
                                              child: AnimatedOpacity(
                                                duration: const Duration(
                                                  milliseconds: 200,
                                                ),
                                                opacity: isSelected
                                                    ? 1.0
                                                    : 0.35,
                                                child: AnimatedScale(
                                                  duration: const Duration(
                                                    milliseconds: 200,
                                                  ),
                                                  scale: isSelected ? 1.0 : 0.9,
                                                  child: SizedBox(
                                                    width: 230 * scale,
                                                    height: 64 * scale,
                                                    child: ColorFiltered(
                                                      colorFilter: isSelected
                                                          ? const ColorFilter.mode(
                                                              Colors
                                                                  .transparent,
                                                              BlendMode
                                                                  .multiply,
                                                            )
                                                          : ColorFilter.mode(
                                                              Colors.black
                                                                  .withValues(
                                                                    alpha: 0.45,
                                                                  ),
                                                              BlendMode.srcATop,
                                                            ),
                                                      child: GameButton(
                                                        label: difficulty.label,
                                                        mainColor: difficulty
                                                            .mainColor,
                                                        accentColor: difficulty
                                                            .accentColor,
                                                        lipColor:
                                                            difficulty.lipColor,
                                                        icon: [
                                                          GameButtonIcon.easy,
                                                          GameButtonIcon.normal,
                                                          GameButtonIcon.hard,
                                                        ][index],
                                                        scale: scale,
                                                        onTap: () {
                                                          setState(() {
                                                            _selectedIndex =
                                                                index;
                                                            _scrollController
                                                                .animateToItem(
                                                                  index,
                                                                  duration:
                                                                      const Duration(
                                                                        milliseconds:
                                                                            250,
                                                                      ),
                                                                  curve: Curves
                                                                      .easeInOut,
                                                                );
                                                          });
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 60 * scale),
                              // Play Text
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
                                child: Text(
                                  'PLAY',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 40 * scale,
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
                            ],
                          ),
                        ),
                      ),
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

class DifficultyData {
  final String label;
  final Color mainColor;
  final Color accentColor;
  final Color lipColor;
  final BotDifficulty difficulty;

  DifficultyData({
    required this.label,
    required this.mainColor,
    required this.accentColor,
    required this.lipColor,
    required this.difficulty,
  });
}
