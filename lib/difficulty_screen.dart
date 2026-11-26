import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui';
import 'main.dart';
import 'bot_ai.dart';
import 'mode_selection_screen.dart';
import 'back_arrow_button.dart';
import 'widgets/app_loading_indicator.dart';

class DifficultyScreen extends StatefulWidget {
  const DifficultyScreen({super.key});

  @override
  State<DifficultyScreen> createState() => _DifficultyScreenState();
}

class _DifficultyScreenState extends State<DifficultyScreen> {
  int _selectedIndex = 1; // 0: Easy, 1: Normal, 2: Hard
  final FixedExtentScrollController _scrollController =
      FixedExtentScrollController(initialItem: 1);
  bool _isLoading = true;
  bool _assetsPrecached = false;

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
        precacheImage(const AssetImage('assets/images/easy_mode.png'), context),
        precacheImage(
          const AssetImage('assets/images/normal_mode.png'),
          context,
        ),
        precacheImage(const AssetImage('assets/images/hard_mode.png'), context),
      ]);
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AppLoadingScreen();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final screenHeight = constraints.maxHeight;

          final bool isDesktop = screenWidth >= 768 && screenHeight >= 500;
          final scale = isDesktop
              ? math.min(1.1, screenHeight / GameConfig.baseHeight)
              : math.min(
                  screenWidth / GameConfig.baseWidth,
                  screenHeight / GameConfig.baseHeight,
                );

          final currentDifficulty = _difficulties[_selectedIndex];
          final itemExtent = 85.0 * scale;

          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF0A1628),
            ),
            child: Stack(
              children: [
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

                // Main Content Centered
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? 400.0 : screenWidth,
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32 * scale),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'SELECT DIFFICULTY',
                            style: TextStyle(
                              fontSize: 13 * scale,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.6),
                              fontFamily: 'Montserrat',
                              letterSpacing: 1.2,
                            ),
                          ),
                          SizedBox(height: 36 * scale),
                          SizedBox(
                            height: 280 * scale,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
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
                                // Mouse Drag & Touch Enabled Scroll Configuration
                                ScrollConfiguration(
                                  behavior: ScrollConfiguration.of(context)
                                      .copyWith(
                                        dragDevices: {
                                          PointerDeviceKind.touch,
                                          PointerDeviceKind.mouse,
                                          PointerDeviceKind.trackpad,
                                          PointerDeviceKind.stylus,
                                        },
                                      ),
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.translucent,
                                    onVerticalDragUpdate: (details) {
                                      if (_scrollController.hasClients) {
                                        final newOffset =
                                            _scrollController.offset -
                                            details.primaryDelta!;
                                        _scrollController.jumpTo(newOffset);
                                      }
                                    },
                                    onVerticalDragEnd: (details) {
                                      if (_scrollController.hasClients) {
                                        final targetIndex =
                                            (_scrollController.offset /
                                                    itemExtent)
                                                .round()
                                                .clamp(
                                                  0,
                                                  _difficulties.length - 1,
                                                );
                                        _scrollController.animateToItem(
                                          targetIndex,
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          curve: Curves.easeOutCubic,
                                        );
                                      }
                                    },
                                    child: ListWheelScrollView.useDelegate(
                                      itemExtent: itemExtent,
                                      diameterRatio: 100.0,
                                      perspective: 0.0000001,
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
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 50 * scale),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (context) => GamePage(
                                    isBotMode: true,
                                    botDifficulty: currentDifficulty.difficulty,
                                  ),
                                ),
                              );
                            },
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Text(
                                'PLAY',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 38 * scale,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'Montserrat',
                                  letterSpacing: 1.0,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.55,
                                      ),
                                      offset: Offset(0, 3 * scale),
                                      blurRadius: 2.0 * scale,
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
