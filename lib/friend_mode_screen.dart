import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'main.dart';
import 'mode_selection_screen.dart';
import 'back_arrow_button.dart';
import 'online_lobby_screen.dart';
import 'widgets/app_loading_indicator.dart';

class FriendModeScreen extends StatefulWidget {
  const FriendModeScreen({super.key});

  @override
  State<FriendModeScreen> createState() => _FriendModeScreenState();
}

class _FriendModeScreenState extends State<FriendModeScreen> {
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
        precacheImage(
          const AssetImage('assets/images/vs_friend_local.png'),
          context,
        ),
        precacheImage(
          const AssetImage('assets/images/vs_friend_online.png'),
          context,
        ),
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
      backgroundColor: const Color(0xFF0A1628),
      body: _buildLayout(context),
    );
  }

  Widget _buildLayout(BuildContext context) {
    return LayoutBuilder(
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

        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFF0A1628),
          ),
          child: Stack(
            children: [
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
                          'VS. FRIEND',
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
                        Text(
                          'CHOOSE MODE',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 30 * scale,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            fontFamily: 'Montserrat',
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 60 * scale),
                        GameButton(
                          label: 'LOCAL',
                          mainColor: const Color(0xFF2CDFA2),
                          accentColor: const Color(0xFF52EBB6),
                          lipColor: const Color(0xFF1C9B71),
                          icon: GameButtonIcon.local,
                          scale: scale,
                          fontSize: 18,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const GamePage(),
                              ),
                            );
                          },
                        ),
                        SizedBox(height: 20 * scale),
                        GameButton(
                          label: 'ONLINE',
                          mainColor: const Color(0xFFAA29C1),
                          accentColor: const Color(0xFFBA68C8),
                          lipColor: const Color(0xFF8E24AA),
                          icon: GameButtonIcon.online,
                          scale: scale,
                          fontSize: 18,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    const OnlineLobbyScreen(),
                              ),
                            );
                          },
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
    );
  }
}