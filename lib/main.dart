import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/particles.dart';
import 'package:flame/effects.dart';
import 'package:flame_audio/flame_audio.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'dart:ui';
import 'home_screen.dart';
import 'utils.dart';
import 'bot_ai.dart';
import 'customization_service.dart';
import 'back_arrow_button.dart';
import 'services/online_game_service.dart';
import 'mode_selection_screen.dart';
import 'widgets/app_loading_indicator.dart';

// ─────────────────────────────────────────────
//  SYNC DEBUG
//  Set enabled = true temporarily to trace online events in the Flutter
//  debug console. Always false in production — zero overhead when off.
// ─────────────────────────────────────────────
class SyncDebug {
  static const bool enabled = false; // ← flip to true to enable logging

  // ignore: avoid_print
  static void log(String msg) {
    if (enabled) debugPrint('[SYNC] $msg');
  }
}

// ─────────────────────────────────────────────
//  CONSTANTS
// ─────────────────────────────────────────────
class GameConfig {
  static const double baseWidth = 375.0;
  static const double baseHeight = 812.0;

  static const double targetRadius = 125.0;
  static const double knifeLength = 140.0; // Adjust if knife is too short/long
  static const double knifeSpeed = 1600.0;
  static const double baseTargetSpeed = 2.0;
  static const double collisionAngle =
      0.22; // Larger = more space between stuck knives
  static const double embedDepth =
      0.55; // Adjust if knife sticks too far out/in (0 = none, 1 = all)
  static const double swipeMinDistance = 18.0;
  static const int knivesPerRound = 7; // 7 throws per player per round
  static const int winningScore = 20; // First to 20 wins
  static const double targetSlideDuration =
      800; // ms for smooth slide transition
  static const Curve slideCurve = Curves.easeInOutCubic;

  // Extra scale for the base target asset because it's slightly smaller than the cracked versions
  static const double baseTargetExtraScale = 1.05;

  static const double targetOffsetX = 0.0;
  static const double targetOffsetY = 0.0;
}

// ─────────────────────────────────────────────
//  ENTRY POINT
// ─────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure audio context to use Low Latency (SoundPool) on Android
  // This prevents the "(1, -19)" MediaPlayer limit exhaustion error
  AudioPlayer.global.setAudioContext(
    AudioContextConfig(respectSilence: true, stayAwake: false).build(),
  );
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const KnifeThrowerApp());
}

class KnifeThrowerApp extends StatelessWidget {
  const KnifeThrowerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Knife Thrower',
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.trackpad,
        },
      ),
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Programme',
        scaffoldBackgroundColor: const Color(0xFF0F1727),
        useMaterial3: true,
      ),
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        // Detect mobile phone rotated in landscape mode (low height, wide aspect ratio)
        final isMobileLandscape =
            mediaQuery.size.height < 500 &&
            mediaQuery.size.width > mediaQuery.size.height;

        if (isMobileLandscape) {
          return Scaffold(
            backgroundColor: const Color(0xFF0A1628),
            body: Container(
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
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.screen_rotation_rounded,
                      size: 48,
                      color: Color(0xFF2CDFA2),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'PORTRAIT ONLY',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Montserrat',
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
          );
        }

        return child!;
      },
      home: const HomeScreen(),
    );
  }
}

class GamePage extends StatefulWidget {
  final bool isBotMode;
  final BotDifficulty botDifficulty;
  final bool isOnlineMode;
  final OnlineGameService? onlineService;
  final String? roomCode;
  final int localPlayerNumber;
  final int? matchSeed;

  const GamePage({
    super.key,
    this.isBotMode = false,
    this.botDifficulty = BotDifficulty.medium,
    this.isOnlineMode = false,
    this.onlineService,
    this.roomCode,
    this.localPlayerNumber = 1,
    this.matchSeed,
  });

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  KnifeThrowerGame? _game;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGame();
  }

  @override
  void dispose() {
    _game?.isReadyNotifier.removeListener(_onGameReady);
    super.dispose();
  }

  void _onGameReady() {
    if (_game != null && _game!.isReadyNotifier.value && mounted) {
      setState(() {
        _isLoading = false;
      });
      // Start 3-2-1 countdown after all assets and HUD elements are 100% visible on screen
      _game!.startCountdown();
    }
  }

  Future<void> _loadGame() async {
    try {
      final selections = await CustomizationService.loadSelections();
      if (!mounted) return;
      await precacheImage(
        const AssetImage('assets/images/Tap_the_screen.gif'),
        context,
      );
      debugPrint(
        'Game loading with knife index: ${selections.knifeIndex}, knife: ${selections.knifeAsset}, target: ${selections.targetAsset}',
      );
      if (mounted) {
        final game = KnifeThrowerGame(
          isBotMode: widget.isBotMode,
          botDifficulty: widget.botDifficulty,
          isOnlineMode: widget.isOnlineMode,
          selectedKnifeAsset: selections.knifeAsset,
          selectedTargetAsset: selections.targetAsset,
          selectedKnifeIndex: selections.knifeIndex,
          onlineService: widget.onlineService,
          roomCode: widget.roomCode,
          localPlayerNumber: widget.localPlayerNumber,
          matchSeed: widget.matchSeed,
        );
        game.isReadyNotifier.addListener(_onGameReady);
        setState(() {
          _game = game;
        });
      }
    } catch (e) {
      debugPrint('Error loading game: $e');
      if (mounted) {
        final game = KnifeThrowerGame(
          isBotMode: widget.isBotMode,
          botDifficulty: widget.botDifficulty,
          isOnlineMode: widget.isOnlineMode,
          selectedKnifeAsset: CustomizationService.knives[0],
          selectedTargetAsset: CustomizationService.targets[0],
          selectedKnifeIndex: 0,
          onlineService: widget.onlineService,
          roomCode: widget.roomCode,
          localPlayerNumber: widget.localPlayerNumber,
          matchSeed: widget.matchSeed,
        );
        game.isReadyNotifier.addListener(_onGameReady);
        setState(() {
          _game = game;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_game == null) {
      return const AppLoadingScreen();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            final key = event.logicalKey;
            if (widget.isOnlineMode) {
              if (key == LogicalKeyboardKey.space ||
                  key == LogicalKeyboardKey.arrowUp ||
                  key == LogicalKeyboardKey.arrowDown ||
                  key == LogicalKeyboardKey.keyW ||
                  key == LogicalKeyboardKey.keyS) {
                _game?.handleInput(widget.localPlayerNumber);
                return KeyEventResult.handled;
              }
            } else {
              if (key == LogicalKeyboardKey.space ||
                  key == LogicalKeyboardKey.arrowDown ||
                  key == LogicalKeyboardKey.keyS) {
                _game?.handleInput(1);
                return KeyEventResult.handled;
              } else if (key == LogicalKeyboardKey.arrowUp ||
                  key == LogicalKeyboardKey.keyW) {
                _game?.handleInput(2);
                return KeyEventResult.handled;
              }
            }
          }
          return KeyEventResult.ignored;
        },
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0D1D36), Color(0xFF0B172A), Color(0xFF091222)],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                child: GameWidget(
                  game: _game!,
                  loadingBuilder: (context) => const AppLoadingIndicator(),
                  initialActiveOverlays: const ['hud'],
                  overlayBuilderMap: {
                    'hud': (ctx, g) => HudOverlay(game: g as KnifeThrowerGame),
                    'gameOver': (ctx, g) =>
                        GameOverOverlay(game: g as KnifeThrowerGame),
                    'countdown': (ctx, g) =>
                        CountdownOverlay(game: g as KnifeThrowerGame),
                    'opponentDisconnected': (ctx, g) =>
                        OpponentDisconnectedOverlay(
                          game: g as KnifeThrowerGame,
                        ),
                  },
                ),
              ),
              // Unified loading screen stays on top until all assets, HUD, and audio are ready
              if (_isLoading)
                const Positioned.fill(child: AppLoadingIndicator()),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  PARTICLES
// ─────────────────────────────────────────────
class TriangleParticle extends Particle {
  final Paint paint;
  final double radius;
  late final Path _path;

  TriangleParticle({
    required this.paint,
    required this.radius,
    super.lifespan,
  }) {
    _path = Path()
      ..moveTo(0, -radius * 2.0)
      ..lineTo(radius * 0.5, radius)
      ..lineTo(-radius * 0.5, radius)
      ..close();
  }

  @override
  void render(Canvas canvas) {
    canvas.drawPath(_path, paint);
  }
}

// ─────────────────────────────────────────────
//  GAME
// ─────────────────────────────────────────────
class KnifeThrowerGame extends FlameGame
    with TapCallbacks, MultiTouchDragDetector {
  final bool isBotMode;
  final BotDifficulty botDifficulty;
  final bool isOnlineMode;
  final String selectedKnifeAsset;
  final String selectedTargetAsset;
  final int selectedKnifeIndex;
  final OnlineGameService? onlineService;
  final String? roomCode; // For online multiplayer
  final int localPlayerNumber; // 1 = Red/Bottom, 2 = Blue/Top
  int? matchSeed;

  late math.Random _matchRng;

  KnifeThrowerGame({
    this.isBotMode = false,
    this.botDifficulty = BotDifficulty.medium,
    required this.selectedKnifeAsset,
    required this.selectedTargetAsset,
    required this.selectedKnifeIndex,
    this.isOnlineMode = false,
    this.onlineService,
    this.roomCode,
    this.localPlayerNumber = 1,
    this.matchSeed,
  }) {
    _matchRng = matchSeed != null ? math.Random(matchSeed) : math.Random();
  }

  static final _rng = math.Random();
  late Target target;
  late Knife p1Knife;
  late Knife p2Knife;

  // ── Online sync state ─────────────────────────────────────────────────────
  // Tracks the last processed remote-throw sequence number so out-of-order
  // network packets are discarded rather than applied to the wrong throw.
  int _lastRemoteThrowSeq = 0;

  // Screen shake variables for satisfying hit feedback
  double _shakeIntensity = 0.0;
  double _shakeDuration = 0.0;
  Vector2 _originalTargetPosition = Vector2.zero();

  late Sprite knifeBlueSprite;
  late Sprite knifeRedSprite;
  late Sprite prePlacedKnifeSprite;
  late Sprite targetSprite;
  late Sprite brokenRedSprite;
  late Sprite brokenBlueSprite;

  late Vector2 knifeSizeRed;
  late Vector2 knifeSizeBlue;
  late Vector2 prePlacedKnifeSize;
  late Vector2 brokenKnifeSize;

  bool isGameOver = false;
  bool isTransitioning = false; // Block inputs during target slide transition
  bool isCountingDown = false; // Block inputs during 3-2-1 countdown

  int currentRound = 1;

  final ValueNotifier<int> p1ScoreNotifier = ValueNotifier(0);
  final ValueNotifier<int> p2ScoreNotifier = ValueNotifier(0);
  final ValueNotifier<int> countdownNotifier = ValueNotifier(0);

  // Track throw results per knife: null = unused, 1 = hit, 0 = miss
  final ValueNotifier<List<int?>> p1ThrowResults = ValueNotifier(
    List.filled(GameConfig.knivesPerRound, null),
  );
  final ValueNotifier<List<int?>> p2ThrowResults = ValueNotifier(
    List.filled(GameConfig.knivesPerRound, null),
  );

  int p1ThrowsMade = 0;
  int p2ThrowsMade = 0;

  BotController? botController;

  final ValueNotifier<String> winnerNotifier = ValueNotifier('');
  double _idleTime = 0.0;
  bool _hasShownTapHelperThisGame = false;
  final ValueNotifier<bool> showTapHelperNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isReadyNotifier = ValueNotifier(false);

  final Map<int, Vector2> _activeDragStart = {};

  // Pre-allocated reusable audio players for Web (avoids creating/destroying DOM audio elements on mobile web)
  final List<AudioPlayer> _webAudioPlayers = [];
  int _currentWebPlayerIndex = 0;

  // Audio pools for low-latency playback
  final Map<String, AudioPool> _audioPools = {};

  // Pre-allocated Paint objects for particles (avoids GC pressure)
  static final Paint _hitPaintRed = Paint()..color = const Color(0xFFD32F2F);
  static final Paint _hitPaintBlue = Paint()..color = const Color(0xFF1976D2);
  static final Paint _clashTrianglePaint = Paint()
    ..color = const Color(0xFFADC1D6).withValues(alpha: 0.4)
    ..style = PaintingStyle.fill;

  // Cached scaling factor — updated only in onGameResize()
  double _cachedScaleFactor = 1.0;
  double get scaleFactor => _cachedScaleFactor;

  /// Whether [player] (1 = Red, 2 = Blue) is rendered at the bottom of this
  /// device's screen.
  /// - Local / Bot modes: Player 1 is always bottom, Player 2 is always top.
  /// - Online mode: the local player is always at the bottom, opponent at top.
  bool isPlayerAtBottom(int player) =>
      isOnlineMode ? (player == localPlayerNumber) : (player == 1);

  /// Visual rotation offset (in radians) applied to the target so that
  /// Player 2's online view is rotated 180° relative to canonical world coords.
  double get viewRotationOffset =>
      (isOnlineMode && localPlayerNumber == 2) ? math.pi : 0.0;

  String _getFilenameFromAssetPath(String path) {
    return path.split('/').last;
  }

  @override
  Future<void> onLoad() async {
    try {
      await super.onLoad();

      // Preload all high-frequency sounds into memory cache for zero-latency playback on Web
      final highFreqSounds = [
        'Arrow_Hit_1.ogg',
        'Arrow_Hit_2.ogg',
        'Arrow_Hit_3.ogg',
        'Arrow_Throw_1.ogg',
        'Arrow_Throw_2.ogg',
        'Arrow_Throw_3.ogg',
        'Metal_Clashed.ogg',
      ];

      // Parallelize audio pre-caching and asset loading for faster game initialization
      await Future.wait([
        FlameAudio.audioCache.loadAll(highFreqSounds),
        if (kIsWeb)
          ...List.generate(6, (_) async {
            try {
              final p = AudioPlayer();
              await p.setReleaseMode(ReleaseMode.stop);
              _webAudioPlayers.add(p);
            } catch (e) {
              debugPrint('Error creating web audio player: $e');
            }
          })
        else
          ...highFreqSounds.map((sound) async {
            try {
              _audioPools[sound] = await AudioPool.create(
                source: AssetSource('audio/$sound'),
                maxPlayers: 3,
              );
            } catch (e) {
              debugPrint('Error creating AudioPool for $sound: $e');
            }
          }),
        _loadAssetsAndInit(
          selectedKnifeAsset,
          selectedTargetAsset,
          selectedKnifeIndex,
        ),
      ]);
    } catch (e) {
      debugPrint('Error in onLoad: $e');
      // Fallback to default assets
      await _loadAssetsAndInit(
        CustomizationService.knives[0],
        CustomizationService.targets[0],
        0,
      );
    }
  }

  Future<void> _loadAssetsAndInit(
    String redKnifeAsset,
    String targetAsset,
    int knifeIndex,
  ) async {
    // Get all necessary filenames
    final selectedRedKnifeFilename = _getFilenameFromAssetPath(redKnifeAsset);
    final selectedBlueKnifeFilename = _getFilenameFromAssetPath(
      CustomizationService.getBlueKnife(redKnifeAsset),
    );
    final selectedTargetFilename = _getFilenameFromAssetPath(targetAsset);
    final greyKnifeFilename = _getFilenameFromAssetPath(
      CustomizationService.getGreyKnife(),
    );
    final brokenRedFilename = _getFilenameFromAssetPath(
      CustomizationService.getBrokenRedKnifeByIndex(knifeIndex),
    );
    final brokenBlueFilename = _getFilenameFromAssetPath(
      CustomizationService.getBrokenBlueKnifeByIndex(knifeIndex),
    );

    // Load only the assets we need
    await images.loadAll([
      selectedRedKnifeFilename,
      selectedBlueKnifeFilename,
      selectedTargetFilename,
      greyKnifeFilename,
      brokenRedFilename,
      brokenBlueFilename,
    ]);

    // Create sprites from cache
    knifeRedSprite = Sprite(images.fromCache(selectedRedKnifeFilename));
    knifeBlueSprite = Sprite(images.fromCache(selectedBlueKnifeFilename));
    prePlacedKnifeSprite = Sprite(images.fromCache(greyKnifeFilename));
    targetSprite = Sprite(images.fromCache(selectedTargetFilename));
    brokenRedSprite = Sprite(images.fromCache(brokenRedFilename));
    brokenBlueSprite = Sprite(images.fromCache(brokenBlueFilename));

    // Calculate sizes
    knifeSizeRed = _calcKnifeSize(knifeRedSprite);
    knifeSizeBlue = _calcKnifeSize(knifeBlueSprite);
    prePlacedKnifeSize = _calcKnifeSize(prePlacedKnifeSprite);
    brokenKnifeSize = _calcKnifeSize(
      brokenRedSprite,
    ); // Assuming both broken knives have similar aspect ratio

    // Initialize target and bot
    target = Target();
    add(target);

    if (isBotMode) {
      botController = BotController(this, difficulty: botDifficulty);
    }

    if (isOnlineMode && onlineService != null) {
      onlineService!.onOpponentThrow = (playerNum, targetAngle, seq) {
        _handleRemoteThrow(playerNum, targetAngle, seq);
      };
      onlineService!.onOpponentThrowResult =
          (
            playerNum,
            isHit,
            impactLocalAngle,
            score,
            throwsMade,
            remoteGameOver,
            winner,
          ) {
            _handleRemoteThrowResult(
              playerNum,
              isHit,
              impactLocalAngle,
              score,
              throwsMade,
              remoteGameOver,
              winner,
            );
          };
      onlineService!.onTargetSync = (angle, dir) {
        if (!isTransitioning && !isGameOver) {
          target.applyRemoteSync(angle, dir);
        }
      };
      onlineService!.onGameOver = (winner, p1Score, p2Score) {
        SyncDebug.log('← game_over winner=$winner p1=$p1Score p2=$p2Score');
        p1ScoreNotifier.value = p1Score;
        p2ScoreNotifier.value = p2Score;
        winnerNotifier.value = winner;
        if (!isGameOver) {
          isGameOver = true;
          isCountingDown = false;
          _idleTime = 0.0;
          showTapHelperNotifier.value = false;
          overlays.remove('countdown');
          overlays.add('gameOver');
        }
      };
      onlineService!.onRematchStart = (newSeed) {
        matchSeed = newSeed;
        _matchRng = math.Random(newSeed);
        restartGame();
      };
      onlineService!.onOpponentDisconnected = () {
        if (!overlays.isActive('opponentDisconnected')) {
          isGameOver = true;
          isCountingDown = false;
          overlays.remove('countdown');
          overlays.remove('gameOver');
          overlays.add('opponentDisconnected');
        }
      };
    }

    // Add initial pre-thrown knives and prepare game
    _addPreThrownKnivesToTarget();
    _spawnInitialKnives();
    overlays.add('hud');
    isReadyNotifier.value = true;
  }

  Future<void> startCountdown() async {
    isCountingDown = true;
    overlays.add('countdown');
    for (int i = 3; i > 0; i--) {
      countdownNotifier.value = i;
      // You can add a "tick" sound here if you have one
      await Future.delayed(const Duration(seconds: 1));
      if (!isMounted || isGameOver) return;
    }
    if (!isMounted || isGameOver) return;
    overlays.remove('countdown');
    isCountingDown = false;
  }

  void playPoolSound(String sound, {double volume = 1.0}) {
    try {
      if (kIsWeb && _webAudioPlayers.isNotEmpty) {
        // Fire-and-forget: pick next player from circular pool and play immediately.
        // Avoids stop().then(play()) microtask jank that caused frame stutter on mobile web.
        final player = _webAudioPlayers[_currentWebPlayerIndex];
        _currentWebPlayerIndex =
            (_currentWebPlayerIndex + 1) % _webAudioPlayers.length;
        player.play(AssetSource('audio/$sound'), volume: volume);
        return;
      }

      if (_audioPools.containsKey(sound)) {
        _audioPools[sound]?.start(volume: volume);
      } else {
        FlameAudio.play(sound, volume: volume);
      }
    } catch (e) {
      debugPrint('Audio error playing $sound: $e');
    }
  }

  Vector2 _calcKnifeSize(Sprite sprite) {
    final img = sprite.image;
    final ratio = img.width / img.height;
    const long = GameConfig.knifeLength;
    return ratio > 1
        ? Vector2(long, long / ratio)
        : Vector2(long * ratio, long);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _cachedScaleFactor = math.min(
      size.x / GameConfig.baseWidth,
      size.y / GameConfig.baseHeight,
    );
  }

  @override
  Color backgroundColor() => Colors.transparent;

  void _addPreThrownKnivesToTarget() {
    // Calculate how many pre-thrown knives to add based on current round
    int numPreThrown = 0;
    if (currentRound >= 3) {
      numPreThrown = 4; // Round 3+: 4 pre-thrown knives
    } else if (currentRound >= 2) {
      numPreThrown = 2; // Round 2: 2 pre-thrown knives
    }

    // Always update target visual at start of round, even if 0 pre-thrown
    // Reset playerHits for the new round
    target.updateVisual(totalStuck: numPreThrown, playerHits: 0);

    if (numPreThrown == 0) return;

    final random = _matchRng;
    // Use a random starting offset so the pattern isn't always at the same fixed orientation
    final startOffset = random.nextDouble() * 2 * math.pi;

    final scale = scaleFactor;

    for (int i = 0; i < numPreThrown; i++) {
      // Create symmetrical placement (mirroring each other)
      // For 2 knives: 0 and 180 degrees
      // For 4 knives: 0, 90, 180, 270 degrees
      final angleStep = (2 * math.pi) / numPreThrown;
      final localAngle = startOffset + (i * angleStep);

      // Use the pre-placed knife asset for initial stuck knives
      final player = random.nextBool() ? 1 : 2;
      final stuckKnife = StuckKnife(
        player: player,
        sprite: prePlacedKnifeSprite,
        size: prePlacedKnifeSize * scale,
        localAngle: localAngle,
        radius: target.radius,
      );
      target.addStuckKnife(stuckKnife);
    }
  }

  void _spawnInitialKnives() {
    if (p1ThrowsMade < GameConfig.knivesPerRound) {
      p1Knife = Knife(player: 1);
      add(p1Knife);
    }
    if (p2ThrowsMade < GameConfig.knivesPerRound) {
      p2Knife = Knife(player: 2);
      add(p2Knife);
    }
  }

  int _lastHapticTime = 0;

  void triggerHapticFeedback() {
    if (kIsWeb) {
      return; // Skip haptic vibration on web to prevent main thread JS interop stalls
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastHapticTime > 50) {
      // 50ms debounce
      HapticFeedback.mediumImpact();
      _lastHapticTime = now;
    }
  }

  void _prepareNextKnife(int player) {
    final k = player == 1 ? p1Knife : p2Knife;

    if (isGameOver ||
        isTransitioning ||
        (player == 1 && p1ThrowsMade >= GameConfig.knivesPerRound) ||
        (player == 2 && p2ThrowsMade >= GameConfig.knivesPerRound)) {
      // Hide the knife off-screen when no more throws are allowed
      k.position.y = 999999;
      return;
    }

    // Instantly snap the existing knife back to the throwing position
    k.resetPosition();
  }

  void recordHit(int player) {
    if (isGameOver) return;
    if (player == 1) {
      p1ScoreNotifier.value++;
      p1ThrowResults.value[p1ThrowsMade] = 1; // hit
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      p1ThrowResults.notifyListeners();
      p1ThrowsMade++;

      // Check if Player 1 has won immediately after scoring
      if (p1ScoreNotifier.value >= GameConfig.winningScore) {
        winnerNotifier.value = 'RED';
        gameOver();
        return;
      }
    } else {
      p2ScoreNotifier.value++;
      p2ThrowResults.value[p2ThrowsMade] = 1;
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      p2ThrowResults.notifyListeners();
      p2ThrowsMade++;

      // Check if Player 2 has won immediately after scoring
      if (p2ScoreNotifier.value >= GameConfig.winningScore) {
        winnerNotifier.value = 'BLUE';
        gameOver();
        return;
      }
    }
    _checkGameOver();
    if (!isGameOver && !isTransitioning) {
      // Update target visual based on player hits in the current round
      target.updateVisual(
        totalStuck: target.stuckKnifeCount + 1,
        playerHits: target.roundHits + 1,
      );
    }
    _prepareNextKnife(player);
  }

  void recordMiss(int player) {
    if (isGameOver) return;
    if (player == 1) {
      p1ThrowResults.value[p1ThrowsMade] = 0; // miss
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      p1ThrowResults.notifyListeners();
      p1ThrowsMade++;
    } else {
      p2ThrowResults.value[p2ThrowsMade] = 0;
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      p2ThrowResults.notifyListeners();
      p2ThrowsMade++;
    }
    _checkGameOver();
    _prepareNextKnife(player);
  }

  // ─────────────────────────────────────────────
  //  ROUND MANAGEMENT & TARGET SLIDING
  // ─────────────────────────────────────────────
  void _checkRoundComplete() {
    // Only check if both players have used all their 7 knives for this round
    if (p1ThrowsMade >= GameConfig.knivesPerRound &&
        p2ThrowsMade >= GameConfig.knivesPerRound &&
        !isTransitioning &&
        !isGameOver) {
      // First check if someone already won (hit 20 points)
      if (p1ScoreNotifier.value >= GameConfig.winningScore) {
        winnerNotifier.value = 'RED';
        gameOver();
        return;
      }
      if (p2ScoreNotifier.value >= GameConfig.winningScore) {
        winnerNotifier.value = 'BLUE';
        gameOver();
        return;
      }

      // If no winner, start new round with sliding transition
      _startNewRoundWithSlide();
    }
  }

  Future<void> _startNewRoundWithSlide() async {
    isTransitioning = true;

    // Wait for 1.5s before starting the transition to let the final action settle
    // The target will continue spinning during this pause as rotation is in Target.update()
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!isMounted || isGameOver) return;

    final screenWidth = size.x;
    final originalTargetY = target.position.y;
    final halfDurationSeconds = (GameConfig.targetSlideDuration / 2) / 1000;

    // Use Flame's Effect system for smooth movement that doesn't block the update loop
    // Slide current target out to the left
    target.add(
      MoveToEffect(
        Vector2(-GameConfig.targetRadius, originalTargetY),
        EffectController(
          duration: halfDurationSeconds,
          curve: GameConfig.slideCurve,
        ),
        onComplete: () {
          // Remove all knives from the board to clean up
          for (final k in children.whereType<Knife>().toList(growable: false)) {
            k.removeFromParent();
          }
          target.clearStuckKnives();

          // Position target off-screen to the right for sliding back in
          target.position = Vector2(
            screenWidth + GameConfig.targetRadius,
            originalTargetY,
          );

          // Increment round before adding pre-thrown knives
          currentRound++;

          // Reset throw counters for new round
          p1ThrowsMade = 0;
          p2ThrowsMade = 0;
          p1ThrowResults.value = List.filled(GameConfig.knivesPerRound, null);
          p2ThrowResults.value = List.filled(GameConfig.knivesPerRound, null);

          // Add pre-thrown knives based on current round to increase difficulty
          _addPreThrownKnivesToTarget();

          // Slide new target into center position
          target.add(
            MoveToEffect(
              Vector2(
                screenWidth / 2 + GameConfig.targetOffsetX,
                originalTargetY,
              ),
              EffectController(
                duration: halfDurationSeconds,
                curve: GameConfig.slideCurve,
              ),
              onComplete: () {
                // Spawn fresh knives for both players and resume game
                _spawnInitialKnives();
                isTransitioning = false;
              },
            ),
          );
        },
      ),
    );
  }

  void _checkGameOver() {
    _checkRoundComplete();
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (isOnlineMode) {
      handleInput(localPlayerNumber);
      return;
    }
    final y = event.localPosition.y;
    handleInput(y < size.y / 2 ? 2 : 1);
  }

  @override
  void onDragStart(int pointerId, DragStartInfo info) {
    _activeDragStart[pointerId] = info.eventPosition.global.clone();
  }

  @override
  void onDragUpdate(int pointerId, DragUpdateInfo info) {
    final start = _activeDragStart[pointerId];
    if (start == null) return;

    final gy = info.eventPosition.global.y;
    if (isOnlineMode) {
      if ((start.y - gy).abs() > GameConfig.swipeMinDistance) {
        handleInput(localPlayerNumber);
        _activeDragStart.remove(pointerId);
      }
      return;
    }

    if (start.y > size.y / 2) {
      if ((start.y - gy) > GameConfig.swipeMinDistance) {
        handleInput(1);
        _activeDragStart.remove(pointerId);
      }
    } else {
      if ((gy - start.y) > GameConfig.swipeMinDistance) {
        handleInput(2);
        _activeDragStart.remove(pointerId);
      }
    }
  }

  @override
  void onDragEnd(int pointerId, DragEndInfo info) {
    _activeDragStart.remove(pointerId);
  }

  @override
  void onDragCancel(int pointerId) {
    _activeDragStart.remove(pointerId);
  }

  void _handleRemoteThrow(int player, double targetAngle, int seq) {
    // Discard out-of-order packets — seq must always advance
    if (seq > 0 && seq <= _lastRemoteThrowSeq) {
      SyncDebug.log('⚠ Discarded stale opponent_throw seq=$seq (last=$_lastRemoteThrowSeq)');
      return;
    }
    _lastRemoteThrowSeq = seq;

    if (isGameOver || isTransitioning || isCountingDown) {
      SyncDebug.log('⚠ Dropped remote throw (game not accepting input): gameOver=$isGameOver transitioning=$isTransitioning counting=$isCountingDown');
      return;
    }

    // Snap canonical target angle BEFORE triggering the throw so collision math
    // uses the exact angle the sender computed at throw time.
    SyncDebug.log('← opponent_throw p$player angle=${targetAngle.toStringAsFixed(3)} seq=$seq');
    target.setCanonicalAngle(targetAngle);
    handleInput(player, isRemote: true);
  }

  void _handleRemoteThrowResult(
    int player,
    bool isHit,
    double impactLocalAngle,
    int score,
    int throwsMade,
    bool remoteGameOver,
    String winner,
  ) {
    SyncDebug.log(
      '← opponent_throw_result p$player hit=$isHit score=$score throws=$throwsMade gameOver=$remoteGameOver',
    );
    final knife = player == 1 ? p1Knife : p2Knife;
    if (knife.isMoving && !knife.awaitingRemoteResult) {
      knife.setPendingRemoteResult(
        RemoteThrowResult(
          isHit: isHit,
          impactLocalAngle: impactLocalAngle,
          score: score,
          throwsMade: throwsMade,
          isGameOver: remoteGameOver,
          winner: winner,
        ),
      );
    } else {
      knife.applyRemoteResult(
        isHit,
        impactLocalAngle,
        score,
        throwsMade,
        remoteGameOver,
        winner,
      );
    }
  }

  void handleInput(int player, {bool isRemote = false}) {
    if (isOnlineMode && !isRemote && player != localPlayerNumber) {
      return;
    }

    // Only human input should reset the idle timer (ignore automated bot/remote actions)
    final bool isHumanInput = isOnlineMode
        ? !isRemote
        : (player == 1) || (!isBotMode && player == 2);
    if (isHumanInput) {
      _idleTime = 0.0;
      if (showTapHelperNotifier.value) {
        showTapHelperNotifier.value = false;
      }
    }

    if (isGameOver) {
      if (!isOnlineMode) {
        restartGame();
      }
      return;
    }

    if (isTransitioning || isCountingDown) {
      return; // Block all inputs during transition or countdown
    }

    if (player == 1) {
      if (p1ThrowsMade < GameConfig.knivesPerRound &&
          !p1Knife.isThrowing &&
          !p1Knife.isMoving) {
        if (isOnlineMode && !isRemote) {
          SyncDebug.log('→ throw_knife p1 angle=${target.canonicalAngle.toStringAsFixed(3)}');
          onlineService?.sendThrow(target.canonicalAngle);
        }
        p1Knife.throwKnife();
      }
    } else {
      if (p2ThrowsMade < GameConfig.knivesPerRound &&
          !p2Knife.isThrowing &&
          !p2Knife.isMoving) {
        if (isOnlineMode && !isRemote) {
          SyncDebug.log('→ throw_knife p2 angle=${target.canonicalAngle.toStringAsFixed(3)}');
          onlineService?.sendThrow(target.canonicalAngle);
        }
        p2Knife.throwKnife();
      }
    }
  }

  void restartGame() {
    if (matchSeed != null) {
      _matchRng = math.Random(matchSeed);
    }
    isGameOver = false;
    isTransitioning = false;
    _hasShownTapHelperThisGame = false;
    _idleTime = 0.0;
    _lastRemoteThrowSeq = 0; // Reset seq counter for fresh match
    if (showTapHelperNotifier.value) {
      showTapHelperNotifier.value = false;
    }
    currentRound = 1;
    p1ScoreNotifier.value = 0;
    p2ScoreNotifier.value = 0;
    p1ThrowsMade = 0;
    p2ThrowsMade = 0;
    botController?.reset();
    p1ThrowResults.value = List.filled(GameConfig.knivesPerRound, null);
    p2ThrowResults.value = List.filled(GameConfig.knivesPerRound, null);
    winnerNotifier.value = '';

    // Reset target to center position for fresh start
    target.position = Vector2(
      size.x / 2 + GameConfig.targetOffsetX,
      size.y / 2,
    );

    target.clearStuckKnives();
    for (final k in children.whereType<Knife>().toList(growable: false)) {
      k.removeFromParent();
    }

    target.resetBehavior();
    overlays.remove('gameOver');
    _addPreThrownKnivesToTarget();
    _spawnInitialKnives();
    startCountdown();
  }

  // Particle effect for a successful hit on the target
  void triggerHitParticles(Vector2 impactPoint, Color color, int player) {
    final scale = _cachedScaleFactor;
    final hitPaint = player == 1 ? _hitPaintRed : _hitPaintBlue;
    add(
      ParticleSystemComponent(
        particle: Particle.generate(
          count: kIsWeb ? 3 : 6,
          lifespan: 0.4,
          generator: (i) {
            final spreadAngle =
                (isPlayerAtBottom(player) ? math.pi / 2 : -math.pi / 2) +
                (_rng.nextDouble() - 0.5) *
                    (math.pi / 2); // Wider spread: 90 degrees instead of 36
            final speed =
                (80.0 + _rng.nextDouble() * 120.0) *
                scale; // Higher speed: 80-200 instead of 35-95

            return AcceleratedParticle(
              position: impactPoint.clone(),
              speed: Vector2(
                math.cos(spreadAngle) * speed,
                math.sin(spreadAngle) * speed,
              ),
              acceleration: Vector2.zero(),
              child: CircleParticle(
                radius: (1.8 + _rng.nextDouble() * 1.2) * scale,
                paint: hitPaint,
              ),
            );
          },
        ),
      ),
    );
  }

  // Particle effect for a clash (knife vs stuck knife)
  void triggerClashParticles(Vector2 clashPoint, int player) {
    final brokenSprite = player == 1 ? brokenRedSprite : brokenBlueSprite;
    final scale = _cachedScaleFactor;

    add(
      ParticleSystemComponent(
        particle: Particle.generate(
          count:
              1, // Spawning 1 broken blade piece (the original knife is removed)
          lifespan: 0.8,
          generator: (i) {
            final bool atBottom = isPlayerAtBottom(player);
            // Bottom side: angles between pi/4 and 3pi/4 (bounces down)
            // Top side: angles between -pi/4 and -3pi/4 (bounces up)
            final angle = atBottom
                ? (math.pi / 4 + _rng.nextDouble() * math.pi / 2)
                : (-math.pi / 4 - _rng.nextDouble() * math.pi / 2);

            final speed = (250.0 + _rng.nextDouble() * 350.0) * scale;
            final rotationSpeed = (_rng.nextDouble() - 0.5) * 15;

            return AcceleratedParticle(
              position: clashPoint.clone(),
              speed: Vector2(math.cos(angle) * speed, math.sin(angle) * speed),
              // Gravity pulls bottom player DOWN (+Y) and top player UP (-Y)
              acceleration: Vector2(0, (atBottom ? 1500 : -1500) * scale),
              child: RotatingParticle(
                from: atBottom ? 0 : math.pi, // Initial flip for top side
                to: rotationSpeed + (atBottom ? 0 : math.pi),
                child: SpriteParticle(
                  sprite: brokenSprite,
                  size:
                      brokenKnifeSize *
                      0.95 *
                      scale, // Reduced slightly more for a better match
                ),
              ),
            );
          },
        ),
      ),
    );

    // Keep the small spike triangles for extra "clash" impact
    add(
      ParticleSystemComponent(
        particle: Particle.generate(
          count: kIsWeb ? 2 : 3,
          lifespan: 0.4,
          generator: (i) {
            final angle = _rng.nextDouble() * 2 * math.pi;
            final speed = (180.0 + _rng.nextDouble() * 250.0) * scale;
            final rotationSpeed = (_rng.nextDouble() - 0.5) * 8;

            return AcceleratedParticle(
              position: clashPoint.clone(),
              speed: Vector2(math.cos(angle) * speed, math.sin(angle) * speed),
              acceleration: Vector2(0, 800 * scale),
              child: RotatingParticle(
                to: rotationSpeed,
                child: TriangleParticle(
                  radius: (5.0 + _rng.nextDouble() * 4.0) * scale,
                  paint: _clashTrianglePaint,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Trigger screen shake for satisfying hit feedback
  void triggerHitShake() {
    _shakeIntensity = 8.0; // Max shake offset
    _shakeDuration = 0.15; // Shake lasts 0.15 seconds
    _originalTargetPosition = target.position.clone();
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Handle screen shake effect
    if (_shakeDuration > 0) {
      _shakeDuration -= dt;
      if (_shakeDuration <= 0) {
        // Reset position when shake ends
        target.position.setFrom(_originalTargetPosition);
        _shakeIntensity = 0;
      } else {
        // Apply random shake offset without vector allocations
        final offsetX = (_rng.nextDouble() - 0.5) * 2 * _shakeIntensity;
        final offsetY = (_rng.nextDouble() - 0.5) * 2 * _shakeIntensity;
        target.position.setValues(
          _originalTargetPosition.x + offsetX,
          _originalTargetPosition.y + offsetY,
        );
        // Gradually reduce shake intensity
        _shakeIntensity *= 0.85;
      }
    }

    // Bot AI Logic
    botController?.update(dt);

    // Track user idle time for "Tap the screen" hand gesture GIF helper (>10s)
    // Only show once per game unless a new game is restarted
    final bool canHumanThrow = isOnlineMode
        ? ((localPlayerNumber == 1 ? p1ThrowsMade : p2ThrowsMade) <
              GameConfig.knivesPerRound)
        : (isBotMode
              ? (p1ThrowsMade < GameConfig.knivesPerRound)
              : (p1ThrowsMade < GameConfig.knivesPerRound ||
                    p2ThrowsMade < GameConfig.knivesPerRound));

    if (!_hasShownTapHelperThisGame &&
        canHumanThrow &&
        !isGameOver &&
        !isTransitioning &&
        !isCountingDown) {
      _idleTime += dt;
      if (_idleTime >= 10.0 && !showTapHelperNotifier.value) {
        showTapHelperNotifier.value = true;
        _hasShownTapHelperThisGame = true;
      }
    } else {
      if (!canHumanThrow || isGameOver || isTransitioning || isCountingDown) {
        _idleTime = 0.0;
        if (showTapHelperNotifier.value) {
          showTapHelperNotifier.value = false;
        }
      }
    }
  }

  void gameOver() {
    isGameOver = true;
    _idleTime = 0.0;
    if (showTapHelperNotifier.value) {
      showTapHelperNotifier.value = false;
    }

    final p1Score = p1ScoreNotifier.value;
    final p2Score = p2ScoreNotifier.value;

    if (p1Score > p2Score) {
      winnerNotifier.value = 'RED';
    } else if (p2Score > p1Score) {
      winnerNotifier.value = 'BLUE';
    } else {
      winnerNotifier.value = 'TIE';
    }

    overlays.add('gameOver');
  }

  @override
  void onRemove() {
    onlineService?.clearInGameCallbacks();
    p1ScoreNotifier.dispose();
    p2ScoreNotifier.dispose();
    p1ThrowResults.dispose();
    p2ThrowResults.dispose();
    winnerNotifier.dispose();
    showTapHelperNotifier.dispose();
    isReadyNotifier.dispose();
    for (final p in _webAudioPlayers) {
      p.dispose();
    }
    _webAudioPlayers.clear();
    super.onRemove();
  }
}

// ─────────────────────────────────────────────
//  TARGET
// ─────────────────────────────────────────────
class Target extends PositionComponent with HasGameReference<KnifeThrowerGame> {
  // Cached radius — updated only in onGameResize()
  double _cachedRadius = GameConfig.targetRadius;
  double get radius => _cachedRadius;

  double _behaviorTimer = 0.0;
  double _nextChangeInterval = 3.0;
  double _directionSign = 1.0;
  /// Canonical target rotation in world coordinates (shared by both clients).
  /// Visual [angle] adds [KnifeThrowerGame.viewRotationOffset] (pi for online P2).
  double canonicalAngle = 0.0;
  late SpriteComponent _visual;
  int stuckKnifeCount = 0;
  int roundHits =
      0; // Track only player-thrown knives in current round for cracking logic

  // ── Behavior RNG is intentionally SEPARATE from _matchRng ────────────────
  // _matchRng must only be consumed by _addPreThrownKnivesToTarget so both
  // clients consume it in identical order (placement is seeded identically).
  // P2 never runs the behavior-change block, so if we used _matchRng here,
  // P1 would call nextDouble() for direction flips that P2 never calls —
  // causing _matchRng to diverge after the first direction change and making
  // pre-thrown knife placement desync on subsequent rounds.
  late math.Random _behaviorRng;

  // Cached list of stuck knives — avoids whereType iteration overhead
  final List<StuckKnife> _stuckKnives = [];
  List<StuckKnife> get stuckKnives => _stuckKnives;

  Target() : super(anchor: Anchor.center);

  /// Add a stuck knife and track it in the cached list
  void addStuckKnife(StuckKnife knife) {
    _stuckKnives.add(knife);
    add(knife);
  }

  /// Remove all stuck knives efficiently
  void clearStuckKnives() {
    for (final k in _stuckKnives) {
      k.removeFromParent();
    }
    _stuckKnives.clear();
  }

  @override
  Future<void> onLoad() async {
    _cachedRadius = GameConfig.targetRadius * game.scaleFactor;
    position = game.size / 2;
    size = Vector2.all(_cachedRadius * 2);

    // Initialize behavior RNG from match seed so it's deterministic,
    // but offset by 1 so it doesn't collide with _matchRng's first value.
    // Both clients derive the same _behaviorRng sequence since they share the seed.
    _behaviorRng = game.matchSeed != null
        ? math.Random(game.matchSeed! ^ 0xDEAD)
        : math.Random();

    _visual = SpriteComponent(
      sprite: game.targetSprite,
      size: size,
      anchor: Anchor.center,
      position: size / 2,
      priority: 10,
    );
    // Apply extra scale to normal target
    _visual.scale = Vector2.all(GameConfig.baseTargetExtraScale);
    add(_visual);
    canonicalAngle = 0.0;
    angle = game.viewRotationOffset;
    _generateNextBehaviorInterval();
  }

  void updateVisual({int? totalStuck, int? playerHits}) {
    if (totalStuck != null) {
      stuckKnifeCount = totalStuck;
    }

    if (playerHits != null) {
      roundHits = playerHits;
      _visual.sprite = game.targetSprite;
      _visual.scale = Vector2.all(1.0);
    }
  }

  void resetBehavior() {
    canonicalAngle = 0.0;
    angle = game.viewRotationOffset;
    _directionSign = 1.0;
    _behaviorTimer = 0.0;
    stuckKnifeCount = 0;
    roundHits = 0;
    _stuckKnives.clear();
    _visual.sprite = game.targetSprite;
    _visual.scale = Vector2.all(1.0);
    // Re-seed behavior RNG on rematch so both clients stay in sync
    if (game.matchSeed != null) {
      _behaviorRng = math.Random(game.matchSeed! ^ 0xDEAD);
    }
    _generateNextBehaviorInterval();
  }

  void _generateNextBehaviorInterval() {
    // Uses _behaviorRng (NOT _matchRng) so placement RNG is never consumed here.
    // P2 also calls this from onLoad/resetBehavior, keeping sequences identical.
    _nextChangeInterval = 1.2 + _behaviorRng.nextDouble() * 2.0;
  }

  void setCanonicalAngle(double value) {
    canonicalAngle = value % (2 * math.pi);
    angle = (canonicalAngle + game.viewRotationOffset) % (2 * math.pi);
  }

  void applyRemoteSync(double remoteAngle, double remoteDirectionSign) {
    _directionSign = remoteDirectionSign;
    // Shortest angular delta in [-pi, pi] to prevent 0.5s micro-stutters from jitter
    double diff = (remoteAngle - canonicalAngle) % (2 * math.pi);
    if (diff > math.pi) diff -= 2 * math.pi;
    if (diff < -math.pi) diff += 2 * math.pi;

    if (diff.abs() > 0.45) {
      canonicalAngle = remoteAngle; // Large gap → hard snap
    } else if (diff.abs() > 0.03) {
      canonicalAngle =
          (canonicalAngle + diff * 0.35) % (2 * math.pi); // Small gap → smooth lerp
    }
    angle = (canonicalAngle + game.viewRotationOffset) % (2 * math.pi);
    SyncDebug.log('↔ target_sync angle=${remoteAngle.toStringAsFixed(3)} dir=$remoteDirectionSign diff=${diff.toStringAsFixed(3)}');
  }

  double _syncAccumulator = 0.0;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _cachedRadius = GameConfig.targetRadius * game.scaleFactor;
    position = size / 2;
    this.size = Vector2.all(_cachedRadius * 2);
    _visual.size = this.size;
    _visual.position = this.size / 2;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.isGameOver || game.isCountingDown) return;

    // In online mode, only the host (P1) drives direction changes.
    // P2's direction is set entirely via applyRemoteSync() — it never runs
    // this block, so _behaviorRng is NOT consumed on P2 during gameplay.
    // Both clients consume _behaviorRng only in onLoad + resetBehavior,
    // keeping the sequences identical across the match.
    if (!game.isOnlineMode || game.localPlayerNumber == 1) {
      _behaviorTimer += dt;
      if (_behaviorTimer >= _nextChangeInterval) {
        _behaviorTimer = 0.0;
        _generateNextBehaviorInterval(); // uses _behaviorRng

        if (_behaviorRng.nextDouble() < 0.75) {
          _directionSign *= -1.0;
        }
        if (game.isOnlineMode && game.localPlayerNumber == 1) {
          game.onlineService?.sendTargetSync(canonicalAngle, _directionSign);
          _syncAccumulator = 0.0;
        }
      }

      if (game.isOnlineMode && game.localPlayerNumber == 1) {
        _syncAccumulator += dt;
        if (_syncAccumulator >= 0.5) {
          _syncAccumulator = 0.0;
          game.onlineService?.sendTargetSync(canonicalAngle, _directionSign);
        }
      }
    }

    final computedSpeed = GameConfig.baseTargetSpeed * _directionSign;
    canonicalAngle = (canonicalAngle + computedSpeed * dt) % (2 * math.pi);
    angle = (canonicalAngle + game.viewRotationOffset) % (2 * math.pi);
  }
}

// ─────────────────────────────────────────────
//  STUCK KNIFE
// ─────────────────────────────────────────────
class StuckKnife extends SpriteComponent
    with HasGameReference<KnifeThrowerGame> {
  final int player;
  final double localAngle;
  final Vector2 _baseSize;

  StuckKnife({
    required this.player,
    required Sprite sprite,
    required Vector2 size,
    required this.localAngle,
    required double radius,
  }) : _baseSize =
           size /
           (radius / GameConfig.targetRadius), // Store unscaled logical size
       super(sprite: sprite, size: size, anchor: Anchor.center, priority: 0) {
    _updatePosition(radius);
    angle = localAngle - math.pi / 2;
  }

  void _updatePosition(double radius) {
    final embed = size.y * GameConfig.embedDepth;
    final inset = size.y / 2 - embed;

    position.setValues(
      radius + math.cos(localAngle) * (radius + inset),
      radius + math.sin(localAngle) * (radius + inset),
    );
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    final scale = game.scaleFactor;
    this.size = _baseSize * scale;
    _updatePosition(game.target.radius);
  }
}

// ─────────────────────────────────────────────
//  FLYING / DEFLECTING KNIFE
// ─────────────────────────────────────────────
class RemoteThrowResult {
  final bool isHit;
  final double impactLocalAngle;
  final int score;
  final int throwsMade;
  final bool isGameOver;
  final String winner;

  const RemoteThrowResult({
    required this.isHit,
    required this.impactLocalAngle,
    required this.score,
    required this.throwsMade,
    required this.isGameOver,
    required this.winner,
  });
}

class Knife extends SpriteComponent with HasGameReference<KnifeThrowerGame> {
  final int player;
  bool isThrowing = false;
  bool isMoving = false;
  bool awaitingRemoteResult = false;
  RemoteThrowResult? _pendingRemoteResult;

  final Vector2 _nextPos = Vector2.zero();

  Knife({required this.player}) : super(anchor: Anchor.center);

  void setPendingRemoteResult(RemoteThrowResult result) {
    _pendingRemoteResult = result;
  }

  @override
  void onLoad() {
    sprite = player == 1 ? game.knifeRedSprite : game.knifeBlueSprite;
    size = player == 1 ? game.knifeSizeRed : game.knifeSizeBlue;
    resetPosition();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // Reposition knives if they are not moving
    if (!isMoving) {
      resetPosition();
    }
  }

  void resetPosition() {
    isThrowing = false;
    isMoving = false;
    awaitingRemoteResult = false;
    _pendingRemoteResult = null;
    final scale = game.scaleFactor;
    size = (player == 1 ? game.knifeSizeRed : game.knifeSizeBlue) * scale;
    if (game.isPlayerAtBottom(player)) {
      position = Vector2(game.size.x / 2, game.size.y - 120 * scale);
      angle = 0;
    } else {
      position = Vector2(game.size.x / 2, 120 * scale);
      angle = math.pi;
    }
  }

  void throwKnife() {
    isThrowing = true;
    isMoving = true;
    game.playPoolSound('Arrow_Throw_${_r3()}.ogg');
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (!isMoving || game.isGameOver) return;

    _nextPos.setFrom(position);
    final bool atBottom = game.isPlayerAtBottom(player);
    final bool isRemoteOnlineKnife =
        game.isOnlineMode && player != game.localPlayerNumber;
    final direction = atBottom ? -1.0 : 1.0;
    final scale = game.scaleFactor;
    _nextPos.y += direction * GameConfig.knifeSpeed * scale * dt;

    final distY = (_nextPos.y - game.target.position.y).abs();
    final hitThreshold = game.target.radius + size.y * 0.5;

    if (distY < hitThreshold) {
      if (isRemoteOnlineKnife) {
        isMoving = false;
        final pending = _pendingRemoteResult;
        if (pending != null) {
          _pendingRemoteResult = null;
          applyRemoteResult(
            pending.isHit,
            pending.impactLocalAngle,
            pending.score,
            pending.throwsMade,
            pending.isGameOver,
            pending.winner,
          );
        } else {
          awaitingRemoteResult = true;
        }
      } else {
        _hitTarget();
      }
    } else {
      bool missed = atBottom
          ? (_nextPos.y + size.y / 2 < 0)
          : (_nextPos.y - size.y / 2 > game.size.y);

      if (missed) {
        if (isRemoteOnlineKnife) {
          isMoving = false;
          final pending = _pendingRemoteResult;
          if (pending != null) {
            _pendingRemoteResult = null;
            applyRemoteResult(
              pending.isHit,
              pending.impactLocalAngle,
              pending.score,
              pending.throwsMade,
              pending.isGameOver,
              pending.winner,
            );
          } else {
            awaitingRemoteResult = true;
          }
        } else {
          game.recordMiss(player);
          _emitLocalResult(isHit: false, impactLocalAngle: 0.0);
        }
      } else {
        position.y = _nextPos.y;
      }
    }
  }

  void _emitLocalResult({
    required bool isHit,
    required double impactLocalAngle,
  }) {
    if (!game.isOnlineMode || player != game.localPlayerNumber) return;
    final score = player == 1
        ? game.p1ScoreNotifier.value
        : game.p2ScoreNotifier.value;
    final throwsMade = player == 1 ? game.p1ThrowsMade : game.p2ThrowsMade;
    SyncDebug.log(
      '→ throw_result p$player hit=$isHit score=$score throws=$throwsMade gameOver=${game.isGameOver}',
    );
    game.onlineService?.sendThrowResult(
      isHit: isHit,
      impactLocalAngle: impactLocalAngle,
      score: score,
      throwsMade: throwsMade,
      isGameOver: game.isGameOver,
      winner: game.winnerNotifier.value,
    );
  }

  void applyRemoteResult(
    bool isHit,
    double impactLocalAngle,
    int score,
    int throwsMade,
    bool remoteGameOver,
    String winner,
  ) {
    awaitingRemoteResult = false;
    isMoving = false;

    if (isHit) {
      game.playPoolSound('Arrow_Hit_${_r3()}.ogg');
      game.recordHit(player);
      // Authoritatively align score with thrower's score
      if (player == 1) {
        game.p1ScoreNotifier.value = score;
      } else {
        game.p2ScoreNotifier.value = score;
      }

      final targetCenter = game.target.position;
      final impactWorldAngle = game.target.angle + impactLocalAngle;
      final embeddedRadius =
          game.target.radius - (size.y * GameConfig.embedDepth * 0.5);
      final preciseImpactPoint = Vector2(
        targetCenter.x + math.cos(impactWorldAngle) * embeddedRadius,
        targetCenter.y + math.sin(impactWorldAngle) * embeddedRadius,
      );
      final particleColor = player == 1
          ? const Color(0xFFD32F2F)
          : const Color(0xFF1976D2);

      final stuckSprite = sprite!;
      final stuckSize = size.clone();
      final targetRadius = game.target.radius;

      Future.microtask(() {
        if (!game.isMounted || game.isGameOver) return;
        game.triggerHitParticles(preciseImpactPoint, particleColor, player);
        game.triggerHitShake();
        game.target.addStuckKnife(
          StuckKnife(
            player: player,
            sprite: stuckSprite,
            size: stuckSize,
            localAngle: impactLocalAngle,
            radius: targetRadius,
          ),
        );
      });
    } else {
      game.playPoolSound('Metal_Clashed.ogg');
      final targetCenter = game.target.position;
      final impactWorldAngle = game.target.angle + impactLocalAngle;
      final clashPoint = Vector2(
        targetCenter.x + math.cos(impactWorldAngle) * game.target.radius,
        targetCenter.y + math.sin(impactWorldAngle) * game.target.radius,
      );
      Future.microtask(() => game.triggerClashParticles(clashPoint, player));
      game.recordMiss(player);
    }

    if (remoteGameOver && !game.isGameOver) {
      game.winnerNotifier.value = winner;
      game.gameOver();
    }
  }

  void _hitTarget() {
    isMoving = false;

    // Canonical world angle: Player 1 (Red) always hits +pi/2, Player 2 (Blue) -pi/2
    final worldAngle = player == 1 ? (math.pi / 2) : (-math.pi / 2);
    final impactLocalAngle =
        normalizeAngle(worldAngle - game.target.canonicalAngle);

    // Check for collision with already stuck knives (uses cached list)
    for (final stuck in game.target.stuckKnives) {
      final a2 = stuck.localAngle;
      double diff = (impactLocalAngle - a2).abs();
      diff = diff % (2 * math.pi);
      if (diff > math.pi) diff = 2 * math.pi - diff;

      if (diff < GameConfig.collisionAngle) {
        // CLASH! – play sound, spawn particles, deflect
        game.playPoolSound('Metal_Clashed.ogg');

        // Calculate world position for clash particles
        final targetCenter = game.target.position;
        final impactWorldAngle = game.target.angle + impactLocalAngle;
        final clashPoint = Vector2(
          targetCenter.x + math.cos(impactWorldAngle) * game.target.radius,
          targetCenter.y + math.sin(impactWorldAngle) * game.target.radius,
        );
        // Defer particle spawning to next frame to spread component tree rebuild cost
        Future.microtask(() => game.triggerClashParticles(clashPoint, player));

        // Record a miss
        game.recordMiss(player);
        _emitLocalResult(isHit: false, impactLocalAngle: impactLocalAngle);
        return;
      }
    }

    // Successful hit
    game.playPoolSound('Arrow_Hit_${_r3()}.ogg');

    // Record hit immediately to trigger cracking sound/visuals without delay
    game.recordHit(player);
    _emitLocalResult(isHit: true, impactLocalAngle: impactLocalAngle);

    final targetCenter = game.target.position;
    // Calculate the actual impact point based on the target's current rotation
    // Adjust radius to account for embedDepth (knife penetrates into the target)
    final impactWorldAngle = game.target.angle + impactLocalAngle;
    final embeddedRadius =
        game.target.radius - (size.y * GameConfig.embedDepth * 0.5);
    final preciseImpactPoint = Vector2(
      targetCenter.x + math.cos(impactWorldAngle) * embeddedRadius,
      targetCenter.y + math.sin(impactWorldAngle) * embeddedRadius,
    );

    final particleColor = player == 1
        ? const Color(0xFFD32F2F)
        : const Color(0xFF1976D2);

    // Add satisfying feedback: screen shake + haptics
    game.triggerHapticFeedback(); // Debounced phone vibration

    // Defer heavy component additions and particle generation to next microtask/frame
    // to keep the hit detection frame completely smooth and avoid multi-component rebuild spikes
    final stuckSprite = sprite!;
    final stuckSize = size.clone();
    final targetRadius = game.target.radius;

    Future.microtask(() {
      if (!game.isMounted || game.isGameOver) return;
      game.triggerHitParticles(preciseImpactPoint, particleColor, player);
      game.triggerHitShake();
      game.target.addStuckKnife(
        StuckKnife(
          player: player,
          sprite: stuckSprite,
          size: stuckSize,
          localAngle: impactLocalAngle,
          radius: targetRadius,
        ),
      );
    });
  }

  int _r3() => KnifeThrowerGame._rng.nextInt(3) + 1;
}

// ─────────────────────────────────────────────
//  COUNTDOWN OVERLAY
// ─────────────────────────────────────────────
class CountdownOverlay extends StatelessWidget {
  final KnifeThrowerGame game;
  const CountdownOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scale = math.min(
      size.width / GameConfig.baseWidth,
      size.height / GameConfig.baseHeight,
    );

    return ValueListenableBuilder<int>(
      valueListenable: game.countdownNotifier,
      builder: (context, count, _) {
        if (count <= 0) return const SizedBox.shrink();
        final text = '$count';

        return IgnorePointer(
          child: Container(
            color: Colors.black.withValues(alpha: 0.35), // Soft dark overlay
            child: Center(
              child: Text(
                text,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 120 * scale,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Montserrat',
                  shadows: const [
                    Shadow(
                      color: Colors.black45,
                      blurRadius: 15,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
//  HUD OVERLAY
// ─────────────────────────────────────────────
class HudOverlay extends StatelessWidget {
  final KnifeThrowerGame game;
  const HudOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;
        final bool isWidescreen =
            screenWidth >= 768 &&
            screenHeight >= 500 &&
            screenWidth > screenHeight * 0.85;

        final scale = isWidescreen
            ? math.min(1.1, screenHeight / GameConfig.baseHeight)
            : math.min(
                screenWidth / GameConfig.baseWidth,
                screenHeight / GameConfig.baseHeight,
              );

        // Local/Bot: P1 (Red) at bottom, P2 (Blue) at top.
        // Online: local player at bottom, opponent at top, keeping fixed Red/Blue colors.
        final int bottomPlayer =
            game.isOnlineMode ? game.localPlayerNumber : 1;
        final int topPlayer = bottomPlayer == 1 ? 2 : 1;

        final bottomResults =
            bottomPlayer == 1 ? game.p1ThrowResults : game.p2ThrowResults;
        final topResults =
            topPlayer == 1 ? game.p1ThrowResults : game.p2ThrowResults;
        final bottomColor =
            bottomPlayer == 1 ? Colors.redAccent : Colors.blueAccent;
        final topColor =
            topPlayer == 1 ? Colors.redAccent : Colors.blueAccent;
        final bottomScore =
            bottomPlayer == 1 ? game.p1ScoreNotifier : game.p2ScoreNotifier;
        final topScore =
            topPlayer == 1 ? game.p1ScoreNotifier : game.p2ScoreNotifier;

        return SizedBox(
          width: screenWidth,
          height: screenHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Top player dots (opponent in online, P2 in local/bot)
              if (isWidescreen)
                Positioned(
                  right: 48 * scale,
                  top: 36 * scale,
                  child: SafeArea(
                    child: _DotIndicator(
                      notifier: topResults,
                      baseColor: topColor,
                      isRow: true,
                      scale: scale,
                    ),
                  ),
                )
              else
                Positioned(
                  right: 20 * scale,
                  top: 0,
                  bottom: screenHeight / 2,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: EdgeInsets.only(top: 20 * scale),
                      child: _DotIndicator(
                        notifier: topResults,
                        baseColor: topColor,
                        isRow: false,
                        scale: scale,
                      ),
                    ),
                  ),
                ),

              // Bottom player dots (local player in online, P1 in local/bot)
              if (isWidescreen)
                Positioned(
                  left: 48 * scale,
                  bottom: 36 * scale,
                  child: SafeArea(
                    child: _DotIndicator(
                      notifier: bottomResults,
                      baseColor: bottomColor,
                      isRow: true,
                      scale: scale,
                    ),
                  ),
                )
              else
                Positioned(
                  left: 20 * scale,
                  top: screenHeight / 2,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 20 * scale),
                        child: _DotIndicator(
                          notifier: bottomResults,
                          baseColor: bottomColor,
                          isRow: false,
                          scale: scale,
                        ),
                      ),
                    ),
                  ),
                ),

              // Score display (always on left edge)
              Positioned(
                left: -40 * scale,
                top: (screenHeight - 120 * scale) / 2,
                child: RepaintBoundary(
                  child: Transform.scale(
                    scale: scale,
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 80,
                      height: 120,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(60),
                          bottomRight: Radius.circular(60),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 40),
                        child: Center(
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ValueListenableBuilder<int>(
                                  valueListenable: bottomScore,
                                  builder: (_, v, _) => Text(
                                    '$v',
                                    style: TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: bottomColor,
                                    ),
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    '.',
                                    style: TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                                ValueListenableBuilder<int>(
                                  valueListenable: topScore,
                                  builder: (_, v, _) => Text(
                                    '$v',
                                    style: TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: topColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Exit button (always on right edge)
              Positioned(
                right: -40 * scale,
                top: (screenHeight - 120 * scale) / 2,
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.centerRight,
                  child: const HoldToExitButton(),
                ),
              ),

              // Player / Bot corner indicators
              ..._buildPlayerIndicators(scale, isWidescreen),

              // Tap the screen helper animation when idle for > 10s
              ValueListenableBuilder<bool>(
                valueListenable: game.showTapHelperNotifier,
                builder: (context, showHelper, _) {
                  if (!showHelper) return const SizedBox.shrink();
                  final gifSize = 140.0 * scale;
                  const bool showBottom = true;
                  final bool showTop = !game.isOnlineMode && !game.isBotMode;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      // Bottom player Tap Helper (local player in online, P1 in local/bot)
                      if (showBottom)
                        Positioned(
                          left: (screenWidth / 2) + 20 * scale,
                          bottom: 45 * scale,
                          child: IgnorePointer(
                            child: Image.asset(
                              'assets/images/Tap_the_screen.gif',
                              width: gifSize,
                              height: gifSize,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      // Top player Tap Helper (local 2-player mode only)
                      if (showTop)
                        Positioned(
                          right: (screenWidth / 2) + 20 * scale,
                          top: 45 * scale,
                          child: IgnorePointer(
                            child: RotatedBox(
                              quarterTurns: 2,
                              child: Image.asset(
                                'assets/images/Tap_the_screen.gif',
                                width: gifSize,
                                height: gifSize,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildPlayerIndicators(double scale, bool isWidescreen) {
    final double hPad = (isWidescreen ? 48 : 20) * scale;
    final double vPad = (isWidescreen ? 36 : 20) * scale;
    final double iconSize = 34 * scale;

    String? topAsset;
    bool rotateTop = false;
    final String bottomAsset;

    if (game.isOnlineMode) {
      // Online: local player is always at the bottom on their own device
      bottomAsset = 'assets/images/You_Indicator.png';
    } else if (game.isBotMode) {
      // Bot mode: only show You for the human player, nothing for bot
      bottomAsset = 'assets/images/You_Indicator.png';
    } else {
      // Local 2-player: show P1 and P2
      bottomAsset = 'assets/images/P1_Indicator.png';
      topAsset = 'assets/images/P2_Indicator.png';
      rotateTop = true;
    }

    return [
      if (topAsset != null)
        Positioned(
          left: hPad,
          top: vPad,
          child: SafeArea(
            bottom: false,
            child: IgnorePointer(
              child: RotatedBox(
                quarterTurns: rotateTop ? 2 : 0,
                child: Image.asset(
                  topAsset,
                  width: iconSize,
                  height: iconSize,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      Positioned(
        right: hPad,
        bottom: vPad,
        child: SafeArea(
          top: false,
          child: IgnorePointer(
            child: Image.asset(
              bottomAsset,
              width: iconSize,
              height: iconSize,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    ];
  }
}

// Hold-to-exit button with progress fill effect
class HoldToExitButton extends StatefulWidget {
  const HoldToExitButton({super.key});

  @override
  State<HoldToExitButton> createState() => _HoldToExitButtonState();
}

class _HoldToExitButtonState extends State<HoldToExitButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Pop the game and return to home screen
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHoldStart() {
    _controller.forward();
  }

  void _onHoldEnd() {
    if (_controller.status != AnimationStatus.completed) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _onHoldStart(),
      onTapUp: (_) => _onHoldEnd(),
      onTapCancel: () => _onHoldEnd(),
      child: Container(
        width: 80,
        height: 120,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(60),
            bottomLeft: Radius.circular(60),
          ),
        ),
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            // Circular progression arc circling the visible edge
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  size: const Size(80, 120),
                  painter: _ExitProgressPainter(progress: _controller.value),
                );
              },
            ),
            // EXIT text - always stays on top
            const Padding(
              padding: EdgeInsets.only(left: 10),
              child: RotatedBox(
                quarterTurns: 3,
                child: Text(
                  'EXIT',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                    letterSpacing: 3.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DotIndicator extends StatelessWidget {
  final ValueNotifier<List<int?>> notifier;
  final Color baseColor;
  final bool isRow;
  final double scale;

  const _DotIndicator({
    required this.notifier,
    required this.baseColor,
    this.isRow = false,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ValueListenableBuilder<List<int?>>(
        valueListenable: notifier,
        builder: (context, results, _) {
          final children = List.generate(GameConfig.knivesPerRound, (index) {
            final result = results[index];
            Color dotColor;
            if (result == null) {
              dotColor = baseColor;
            } else if (result == 1) {
              dotColor = Colors.green;
            } else {
              dotColor = Colors.grey;
            }

            return Container(
              margin: isRow
                  ? EdgeInsets.symmetric(horizontal: 4 * scale)
                  : EdgeInsets.symmetric(vertical: 4 * scale),
              width: 12 * scale,
              height: 12 * scale,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black12, width: 1 * scale),
              ),
            );
          });

          if (isRow) {
            return Row(mainAxisSize: MainAxisSize.min, children: children);
          }

          return Column(mainAxisSize: MainAxisSize.min, children: children);
        },
      ),
    );
  }
}

class _GameOverBackgroundPainter extends CustomPainter {
  final Color color;
  _GameOverBackgroundPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..color = color.withValues(alpha: 0.10);

    for (var i = 0; i < 4; i++) {
      canvas.drawCircle(center, size.width * (0.22 + i * 0.12), basePaint);
    }

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color.withValues(alpha: 0.08);

    for (var i = 0; i < 8; i++) {
      final angle = (math.pi * 2 / 8) * i;
      final start =
          center + Offset(math.cos(angle), math.sin(angle)) * size.width * 0.10;
      final end =
          center + Offset(math.cos(angle), math.sin(angle)) * size.width * 0.42;
      canvas.drawLine(start, end, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GameOverBackgroundPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _ExitProgressPainter extends CustomPainter {
  final double progress;
  _ExitProgressPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    // The button is 80x120 with radius 60 on the left.
    // The left edge is a semi-circle centered at (60, 60).
    // Radius 57 to ensure the 6px stroke stays within the container's 60px curve bounds
    final radius = 57.0;
    final center = Offset(60, 60);

    // Draw the background circle track (only the visible part)
    final bgPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    // Draw the visible semi-circle on the left side
    // From 90 degrees (bottom) to 270 degrees (top) counter-clockwise
    // In drawArc, start angle is 0.5 * pi, sweep is pi
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0.5 * math.pi,
      math.pi,
      false,
      bgPaint,
    );

    // Draw the progress arc along that same semi-circle
    // We want the progress to "fill" from bottom to top along the curve
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0.5 * math.pi,
      math.pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ExitProgressPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class GameOverOverlay extends StatefulWidget {
  final KnifeThrowerGame game;
  const GameOverOverlay({super.key, required this.game});

  @override
  State<GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<GameOverOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _canRestart = false;
  bool _rematchRequested = false;
  bool _opponentRematchReady = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800), // Smooth fade-in animation
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    if (widget.game.isOnlineMode && widget.game.onlineService != null) {
      widget.game.onlineService!.onOpponentRematchReady = () {
        if (mounted) {
          setState(() => _opponentRematchReady = true);
        }
      };
    }

    // Wait 1.5s before showing the overlay to let final game action settle
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _fadeController.forward();
        // Allow restart only after the overlay has fully faded in
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            setState(() => _canRestart = true);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  String get _onlinePromptText {
    if (_rematchRequested) return 'WAITING FOR FRIEND...';
    if (_opponentRematchReady) return 'FRIEND READY - TAP TO REMATCH';
    return 'TAP TO REMATCH';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: widget.game.winnerNotifier,
      builder: (context, winner, _) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scale = math.min(
                constraints.maxWidth / GameConfig.baseWidth,
                constraints.maxHeight / GameConfig.baseHeight,
              );
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (!_canRestart) return;
                  if (widget.game.isOnlineMode) {
                    if (!_rematchRequested) {
                      setState(() => _rematchRequested = true);
                      widget.game.onlineService?.sendRematchRequest();
                    }
                    return;
                  }
                  widget.game.restartGame();
                  widget.game.overlays.remove('gameOver');
                  widget.game.overlays.add('hud');
                },
                child: Material(
                  color: Colors.transparent,
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          // Top half (opponent in online, Blue P2 in local/bot)
                          Expanded(
                            child: RotatedBox(
                              quarterTurns: widget.game.isOnlineMode ? 0 : 2,
                              child: _GameOverPlayerSection(
                                player: widget.game.isOnlineMode
                                    ? (widget.game.localPlayerNumber == 1
                                          ? 2
                                          : 1)
                                    : 2,
                                winner: winner,
                                canRestart: _canRestart,
                                promptText: widget.game.isOnlineMode
                                    ? _onlinePromptText
                                    : 'TAP TO PLAY AGAIN',
                              ),
                            ),
                          ),
                          // Bottom half (local player in online, Red P1 in local/bot)
                          Expanded(
                            child: _GameOverPlayerSection(
                              player: widget.game.isOnlineMode
                                  ? widget.game.localPlayerNumber
                                  : 1,
                              winner: winner,
                              canRestart: _canRestart,
                              promptText: widget.game.isOnlineMode
                                  ? _onlinePromptText
                                  : 'TAP TO PLAY AGAIN',
                            ),
                          ),
                        ],
                      ),
                      // Single exit button on the right (same as game screen)
                      Positioned(
                        right: -40 * scale,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Transform.scale(
                            scale: scale,
                            alignment: Alignment.centerRight,
                            child: const HoldToExitButton(),
                          ),
                        ),
                      ),
                      // Top-left Back Arrow button
                      Positioned(
                        left: 24,
                        top: 24,
                        child: SafeArea(
                          child: BackArrowButton(
                            onTap: () {
                              Navigator.of(context).pop();
                            },
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
      },
    );
  }
}

class _GameOverPlayerSection extends StatelessWidget {
  final int player;
  final String winner;
  final bool canRestart;
  final String promptText;

  const _GameOverPlayerSection({
    required this.player,
    required this.winner,
    required this.canRestart,
    this.promptText = 'TAP TO PLAY AGAIN',
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;
        // Use a combined scale that respects the smaller dimension relative to our base player half
        final scale = math.min(
          screenWidth / GameConfig.baseWidth,
          (screenHeight * 2) / GameConfig.baseHeight,
        );

        List<Color> gradientColors;
        String statusText;
        Color accentColor = Colors.white;

        final bool isBlue = player == 2;
        final bool didWin =
            (isBlue && winner == 'BLUE') || (!isBlue && winner == 'RED');
        final bool isTie = winner == 'TIE';

        // Lock colors: Blue section is always blue, Red section is always red
        gradientColors = isBlue
            ? const [Color(0xFF1E88E5), Color(0xFF0D47A1)]
            : const [Color(0xFFE53935), Color(0xFF8D0E0E)];

        if (isTie) {
          statusText = 'TIE';
        } else if (didWin) {
          statusText = isBlue ? 'BLUE WIN' : 'RED WIN';
        } else {
          statusText = isBlue ? 'BLUE LOSE' : 'RED LOSE';
          accentColor = Colors.white70;
        }

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: gradientColors,
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: 0.1,
                  child: CustomPaint(
                    painter: _GameOverBackgroundPainter(color: accentColor),
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        fontFamily: 'Programme',
                        fontSize: 54 * scale,
                        fontWeight: FontWeight.w900,
                        color: accentColor,
                        height: 1.1,
                      ),
                    ),
                    SizedBox(height: 24 * scale),
                    AnimatedOpacity(
                      opacity: canRestart ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 500),
                      child: Text(
                        promptText,
                        style: TextStyle(
                          fontFamily: 'Programme',
                          fontSize: 16 * scale,
                          fontWeight: FontWeight.w700,
                          color: accentColor.withValues(alpha: 0.8),
                          letterSpacing: 1.5 * scale,
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
    );
  }

}

class OpponentDisconnectedOverlay extends StatelessWidget {
  final KnifeThrowerGame game;
  const OpponentDisconnectedOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0A1628).withValues(alpha: 0.88),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                color: Color(0xFFFF8A80),
                size: 52,
              ),
              const SizedBox(height: 16),
              const Text(
                'OPPONENT DISCONNECTED',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your friend left the match.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 28),
              GameButton(
                label: 'BACK TO LOBBY',
                mainColor: const Color(0xFF2CDFA2),
                accentColor: const Color(0xFF52EBB6),
                lipColor: const Color(0xFF1C9B71),
                fontSize: 16,
                onTap: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
