import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/particles.dart';
import 'package:flame/effects.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'home_screen.dart';
import 'utils.dart';
import 'bot_ai.dart';

// ─────────────────────────────────────────────
//  CONSTANTS
// ─────────────────────────────────────────────
class GameConfig {
  static const double baseWidth = 375.0;
  static const double baseHeight = 812.0;

  static const double targetRadius = 125.0;
  static const double knifeLength = 130.0;
  static const double knifeSpeed = 1600.0;
  static const double baseTargetSpeed = 1.5;
  static const double collisionAngle = 0.15;
  static const double embedDepth = 0.70;
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
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Programme',
        scaffoldBackgroundColor: const Color(0xFF0F1727),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class GamePage extends StatefulWidget {
  final bool isBotMode;
  final BotDifficulty botDifficulty;
  const GamePage({
    super.key,
    this.isBotMode = false,
    this.botDifficulty = BotDifficulty.medium,
  });

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final KnifeThrowerGame _game;

  @override
  void initState() {
    super.initState();
    _game = KnifeThrowerGame(
      isBotMode: widget.isBotMode,
      botDifficulty: widget.botDifficulty,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(
        game: _game,
        overlayBuilderMap: {
          'hud': (ctx, g) => HudOverlay(game: g as KnifeThrowerGame),
          'gameOver': (ctx, g) => GameOverOverlay(game: g as KnifeThrowerGame),
          'countdown': (ctx, g) =>
              CountdownOverlay(game: g as KnifeThrowerGame),
        },
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

  TriangleParticle({required this.paint, required this.radius, super.lifespan});

  @override
  void render(Canvas canvas) {
    final path = Path();
    // Create an elongated "spike" triangle
    path.moveTo(0, -radius * 2.0); // Tip
    path.lineTo(radius * 0.5, radius); // Bottom right
    path.lineTo(-radius * 0.5, radius); // Bottom left
    path.close();
    canvas.drawPath(path, paint);
  }
}

// ─────────────────────────────────────────────
//  GAME
// ─────────────────────────────────────────────
class KnifeThrowerGame extends FlameGame
    with TapCallbacks, MultiTouchDragDetector {
  final bool isBotMode;
  final BotDifficulty botDifficulty;
  KnifeThrowerGame({
    this.isBotMode = false,
    this.botDifficulty = BotDifficulty.medium,
  });

  static final _rng = math.Random();
  late Target target;
  late Knife p1Knife;
  late Knife p2Knife;

  // Screen shake variables for satisfying hit feedback
  double _shakeIntensity = 0.0;
  double _shakeDuration = 0.0;
  Vector2 _originalTargetPosition = Vector2.zero();

  late Sprite knifeBlueSprite;
  late Sprite knifeRedSprite;
  late Sprite prePlacedKnifeSprite;
  late Sprite targetSprite;
  late Sprite targetCrackedInitialSprite;
  late Sprite targetCrackedSuperSprite;
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

  final Map<int, Vector2> _activeDragStart = {};

  // Audio pools for low-latency playback
  final Map<String, AudioPool> _audioPools = {};

  // Scaling factors
  double get scaleFactor =>
      math.min(size.x / GameConfig.baseWidth, size.y / GameConfig.baseHeight);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Initialize audio pools for high-frequency sound effects only
    // This reduces resource usage and avoids initialization delays
    final highFreqSounds = [
      'Arrow_Hit_1.ogg',
      'Arrow_Hit_2.ogg',
      'Arrow_Hit_3.ogg',
      'Arrow_Throw_1.ogg',
      'Arrow_Throw_2.ogg',
      'Arrow_Throw_3.ogg',
      'Metal_Clashed.ogg',
      'Tree_trunk_target_cracking_1.mp3',
      'Tree_trunk_target_cracking_2.mp3',
    ];

    for (final sound in highFreqSounds) {
      try {
        _audioPools[sound] = await AudioPool.create(
          source: AssetSource('audio/$sound'),
          maxPlayers: 4,
        );
      } catch (e) {
        debugPrint('Error creating AudioPool for $sound: $e');
      }
    }

    await images.loadAll([
      'blue_knife.png',
      'red_knife.png',
      'pre_placed_knife.png',
      'tree_truck_target.png',
      'initial_cracked_tree_truck_target.png',
      'super_cracked_tree_truck_target.png',
      'broken_red_knife.png',
      'broken_blue_knife.png',
    ]);

    knifeBlueSprite = await loadSprite('blue_knife.png');
    knifeRedSprite = await loadSprite('red_knife.png');
    prePlacedKnifeSprite = await loadSprite('pre_placed_knife.png');
    targetSprite = await loadSprite('tree_truck_target.png');
    targetCrackedInitialSprite = await loadSprite(
      'initial_cracked_tree_truck_target.png',
    );
    targetCrackedSuperSprite = await loadSprite(
      'super_cracked_tree_truck_target.png',
    );
    brokenRedSprite = await loadSprite('broken_red_knife.png');
    brokenBlueSprite = await loadSprite('broken_blue_knife.png');

    knifeSizeRed = _calcKnifeSize(knifeRedSprite);
    knifeSizeBlue = _calcKnifeSize(knifeBlueSprite);
    prePlacedKnifeSize = _calcKnifeSize(prePlacedKnifeSprite);
    brokenKnifeSize = _calcKnifeSize(
      brokenRedSprite,
    ); // Assuming both broken knives have similar aspect ratio

    target = Target();
    add(target);

    if (isBotMode) {
      botController = BotController(this, difficulty: botDifficulty);
    }

    // Add initial pre-thrown knives to target (round 1 adds 0, which is correct)
    _addPreThrownKnivesToTarget();

    _spawnInitialKnives();
    overlays.add('hud');
    startCountdown();
  }

  Future<void> startCountdown() async {
    isCountingDown = true;
    overlays.add('countdown');
    for (int i = 3; i > 0; i--) {
      countdownNotifier.value = i;
      // You can add a "tick" sound here if you have one
      await Future.delayed(const Duration(seconds: 1));
    }
    overlays.remove('countdown');
    isCountingDown = false;
  }

  void playPoolSound(String sound, {double volume = 1.0}) {
    if (_audioPools.containsKey(sound)) {
      _audioPools[sound]?.start(volume: volume);
    } else {
      // Fallback for sounds not in pool or if pool initialization failed
      FlameAudio.play(sound, volume: volume);
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
  Color backgroundColor() => const Color(0xFF35526C);

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

    final random = math.Random();
    // Use a random starting offset so the pattern isn't always at the same fixed orientation
    final startOffset = random.nextDouble() * 2 * math.pi;

    final List<double> preThrownAngles = [];

    final scale = scaleFactor;

    for (int i = 0; i < numPreThrown; i++) {
      // Create symmetrical placement (mirroring each other)
      // For 2 knives: 0 and 180 degrees
      // For 4 knives: 0, 90, 180, 270 degrees
      final angleStep = (2 * math.pi) / numPreThrown;
      final localAngle = startOffset + (i * angleStep);
      preThrownAngles.add(normalizeAngle(localAngle));

      // Use the pre-placed knife asset for initial stuck knives
      final player = random.nextBool() ? 1 : 2;
      final stuckKnife = StuckKnife(
        player: player,
        sprite: prePlacedKnifeSprite,
        size: prePlacedKnifeSize * scale,
        localAngle: localAngle,
        radius: target.radius,
      );
      target.add(stuckKnife);
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

  void _spawnReplacement(int player) {
    if (isGameOver || isTransitioning) return;
    if (player == 1 && p1ThrowsMade >= GameConfig.knivesPerRound) return;
    if (player == 2 && p2ThrowsMade >= GameConfig.knivesPerRound) return;

    final k = Knife(player: player);
    add(k);
    if (player == 1) {
      p1Knife = k;
    } else {
      p2Knife = k;
    }
  }

  void recordHit(int player) {
    if (player == 1) {
      p1ScoreNotifier.value++;
      final newResults = List<int?>.from(p1ThrowResults.value);
      newResults[p1ThrowsMade] = 1; // hit
      p1ThrowResults.value = newResults;
      p1ThrowsMade++;

      // Check if Player 1 has won immediately after scoring
      if (p1ScoreNotifier.value >= GameConfig.winningScore) {
        winnerNotifier.value = 'RED';
        gameOver();
        return;
      }
    } else {
      p2ScoreNotifier.value++;
      final newResults = List<int?>.from(p2ThrowResults.value);
      newResults[p2ThrowsMade] = 1;
      p2ThrowResults.value = newResults;
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
      _spawnReplacement(player);
    }
  }

  void recordMiss(int player) {
    if (player == 1) {
      final newResults = List<int?>.from(p1ThrowResults.value);
      newResults[p1ThrowsMade] = 0; // miss
      p1ThrowResults.value = newResults;
      p1ThrowsMade++;
    } else {
      final newResults = List<int?>.from(p2ThrowResults.value);
      newResults[p2ThrowsMade] = 0;
      p2ThrowResults.value = newResults;
      p2ThrowsMade++;
    }
    _checkGameOver();
    if (!isGameOver && !isTransitioning) _spawnReplacement(player);
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
    if (isGameOver) return;

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
          children.whereType<Knife>().forEach((k) => k.removeFromParent());
          target.children.whereType<StuckKnife>().forEach(
            (k) => k.removeFromParent(),
          );

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

  void handleInput(int player) {
    if (isGameOver) {
      restartGame();
      return;
    }

    if (isTransitioning || isCountingDown) {
      return; // Block all inputs during transition or countdown
    }

    if (player == 1) {
      if (p1ThrowsMade < GameConfig.knivesPerRound &&
          !p1Knife.isThrowing &&
          !p1Knife.isMoving) {
        p1Knife.throwKnife();
      }
    } else {
      if (p2ThrowsMade < GameConfig.knivesPerRound &&
          !p2Knife.isThrowing &&
          !p2Knife.isMoving) {
        p2Knife.throwKnife();
      }
    }
  }

  void restartGame() {
    isGameOver = false;
    isTransitioning = false;
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

    target.children.whereType<StuckKnife>().toList().forEach(
      (k) => k.removeFromParent(),
    );
    children.whereType<Knife>().toList().forEach((k) => k.removeFromParent());

    target.resetBehavior();
    overlays.remove('gameOver');
    _addPreThrownKnivesToTarget();
    _spawnInitialKnives();
    startCountdown();
  }

  // Particle effect for a successful hit on the target
  void triggerHitParticles(Vector2 impactPoint, Color color, int player) {
    final scale = scaleFactor;
    add(
      ParticleSystemComponent(
        particle: Particle.generate(
          count: 6,
          lifespan: 0.4,
          generator: (i) {
            final spreadAngle =
                (player == 1 ? math.pi / 2 : -math.pi / 2) +
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
                paint: Paint()..color = color,
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
    final scale = scaleFactor;

    add(
      ParticleSystemComponent(
        particle: Particle.generate(
          count:
              1, // Spawning 1 broken blade piece (the original knife is removed)
          lifespan: 0.8,
          generator: (i) {
            // Player 1 (Red, bottom): angles between pi/4 and 3pi/4 (bounces down)
            // Player 2 (Blue, top): angles between -pi/4 and -3pi/4 (bounces up)
            final angle = player == 1
                ? (math.pi / 4 + _rng.nextDouble() * math.pi / 2)
                : (-math.pi / 4 - _rng.nextDouble() * math.pi / 2);

            final speed = (250.0 + _rng.nextDouble() * 350.0) * scale;
            final rotationSpeed = (_rng.nextDouble() - 0.5) * 15;

            return AcceleratedParticle(
              position: clashPoint.clone(),
              speed: Vector2(math.cos(angle) * speed, math.sin(angle) * speed),
              // Gravity should pull red DOWN (positive Y) and blue UP (negative Y)
              acceleration: Vector2(0, (player == 1 ? 1500 : -1500) * scale),
              child: RotatingParticle(
                from: player == 2 ? math.pi : 0, // Initial flip for blue side
                to: rotationSpeed + (player == 2 ? math.pi : 0),
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
          count: 3,
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
                  paint: Paint()
                    ..color = const Color(0xFFADC1D6).withValues(alpha: 0.4)
                    ..style = PaintingStyle.fill,
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
        // Apply random shake offset
        final offsetX = (_rng.nextDouble() - 0.5) * 2 * _shakeIntensity;
        final offsetY = (_rng.nextDouble() - 0.5) * 2 * _shakeIntensity;
        target.position = _originalTargetPosition + Vector2(offsetX, offsetY);
        // Gradually reduce shake intensity
        _shakeIntensity *= 0.85;
      }
    }

    // Bot AI Logic
    botController?.update(dt);
  }

  void gameOver() {
    isGameOver = true;

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
    p1ScoreNotifier.dispose();
    p2ScoreNotifier.dispose();
    p1ThrowResults.dispose();
    p2ThrowResults.dispose();
    winnerNotifier.dispose();
    super.onRemove();
  }
}

// ─────────────────────────────────────────────
//  TARGET
// ─────────────────────────────────────────────
class Target extends PositionComponent with HasGameReference<KnifeThrowerGame> {
  double get radius => GameConfig.targetRadius * game.scaleFactor;

  double _behaviorTimer = 0.0;
  double _nextChangeInterval = 3.0;
  double _directionSign = 1.0;
  late SpriteComponent _visual;
  int stuckKnifeCount = 0;
  int roundHits =
      0; // Track only player-thrown knives in current round for cracking logic

  Target() : super(anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    position = game.size / 2;
    size = Vector2.all(radius * 2);

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
    _generateNextBehaviorInterval();
  }

  void updateVisual({int? totalStuck, int? playerHits}) {
    if (totalStuck != null) {
      stuckKnifeCount = totalStuck;
    }

    if (playerHits != null) {
      final oldRoundHits = roundHits;
      roundHits = playerHits;

      if (roundHits >= 10) {
        if (oldRoundHits < 10) {
          game.playPoolSound('Tree_trunk_target_cracking_2.mp3', volume: 0.4);
        }
        _visual.sprite = game.targetCrackedSuperSprite;
        _visual.scale = Vector2.all(1.0); // Reset scale for cracked versions
      } else if (roundHits >= 5) {
        if (oldRoundHits < 5) {
          game.playPoolSound('Tree_trunk_target_cracking_1.mp3', volume: 0.4);
        }
        _visual.sprite = game.targetCrackedInitialSprite;
        _visual.scale = Vector2.all(1.0); // Reset scale for cracked versions
      } else {
        _visual.sprite = game.targetSprite;
        _visual.scale = Vector2.all(GameConfig.baseTargetExtraScale);
      }
    }
  }

  void resetBehavior() {
    angle = 0;
    _directionSign = 1.0;
    _behaviorTimer = 0.0;
    stuckKnifeCount = 0;
    roundHits = 0;
    _visual.sprite = game.targetSprite;
    _visual.scale = Vector2.all(GameConfig.baseTargetExtraScale);
    _generateNextBehaviorInterval();
  }

  void _generateNextBehaviorInterval() {
    _nextChangeInterval = 2.0 + KnifeThrowerGame._rng.nextDouble() * 2.5;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    position = size / 2;
    this.size = Vector2.all(radius * 2);
    _visual.size = this.size;
    _visual.position = this.size / 2;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.isGameOver || game.isCountingDown) return;

    _behaviorTimer += dt;
    if (_behaviorTimer >= _nextChangeInterval) {
      _behaviorTimer = 0.0;
      _generateNextBehaviorInterval();

      if (KnifeThrowerGame._rng.nextDouble() < 0.60) {
        _directionSign *= -1.0;
      }
    }

    final computedSpeed = GameConfig.baseTargetSpeed * _directionSign;
    angle = (angle + computedSpeed * dt) % (2 * math.pi);
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
class Knife extends SpriteComponent with HasGameReference<KnifeThrowerGame> {
  final int player;
  bool isThrowing = false;
  bool isMoving = false;

  final Vector2 _nextPos = Vector2.zero();

  Knife({required this.player}) : super(anchor: Anchor.center);

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
    final scale = game.scaleFactor;
    size = (player == 1 ? game.knifeSizeRed : game.knifeSizeBlue) * scale;
    if (player == 1) {
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

    if (!isMoving) return;

    _nextPos.setFrom(position);
    final direction = player == 1 ? -1.0 : 1.0;
    final scale = game.scaleFactor;
    _nextPos.y += direction * GameConfig.knifeSpeed * scale * dt;

    final dist = _nextPos.distanceTo(game.target.position);

    if (dist < game.target.radius + size.y / 2) {
      _hitTarget();
    } else {
      bool missed = player == 1
          ? (_nextPos.y + size.y / 2 < 0)
          : (_nextPos.y - size.y / 2 > game.size.y);

      if (missed) {
        removeFromParent();
        game.recordMiss(player);
      } else {
        position.y = _nextPos.y;
      }
    }
  }

  void _hitTarget() {
    isMoving = false;

    final worldAngle = player == 1 ? (math.pi / 2) : (-math.pi / 2);
    final impactLocalAngle = normalizeAngle(worldAngle - game.target.angle);

    // Check for collision with already stuck knives
    for (final stuck in game.target.children.whereType<StuckKnife>()) {
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
        final clashVector = Vector2(
          math.cos(impactWorldAngle) * game.target.radius,
          math.sin(impactWorldAngle) * game.target.radius,
        );
        final clashPoint = targetCenter + clashVector;
        game.triggerClashParticles(clashPoint, player);

        // Remove the original knife immediately and record a miss
        removeFromParent();
        game.recordMiss(player);
        return;
      }
    }

    // Successful hit
    game.playPoolSound('Arrow_Hit_${_r3()}.ogg');

    // Record hit immediately to trigger cracking sound/visuals without delay
    game.recordHit(player);

    final targetCenter = game.target.position;
    // Calculate the actual impact point based on the target's current rotation
    // Adjust radius to account for embedDepth (knife penetrates into the target)
    final impactWorldAngle = game.target.angle + impactLocalAngle;
    final embeddedRadius =
        game.target.radius - (size.y * GameConfig.embedDepth * 0.5);
    final contactVector = Vector2(
      math.cos(impactWorldAngle) * embeddedRadius,
      math.sin(impactWorldAngle) * embeddedRadius,
    );
    final preciseImpactPoint = targetCenter + contactVector;

    final particleColor = player == 1
        ? const Color(0xFFD32F2F)
        : const Color(0xFF1976D2);
    game.triggerHitParticles(preciseImpactPoint, particleColor, player);

    // Add satisfying feedback: screen shake + haptics
    game.triggerHitShake();
    HapticFeedback.mediumImpact(); // Trigger phone vibration

    game.target.add(
      StuckKnife(
        player: player,
        sprite: sprite!,
        size: size,
        localAngle: impactLocalAngle,
        radius: game.target.radius,
      ),
    );

    removeFromParent();
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
        final text = '$count';

        return Container(
          color: Colors.black.withValues(alpha: 0.5), // Soft dark overlay
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white,
                fontSize: 120 * scale,
                fontWeight: FontWeight.w900,
                fontFamily: 'Programme',
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
        final scale = math.min(
          screenWidth / GameConfig.baseWidth,
          screenHeight / GameConfig.baseHeight,
        );

        return Stack(
          children: [
            // Blue player (top) dots - Wrapped in SafeArea
            Positioned(
              right: 20 * scale,
              top: 0,
              bottom: screenHeight / 2,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.only(top: 20 * scale),
                  child: _DotColumn(
                    notifier: game.p2ThrowResults,
                    baseColor: Colors.blueAccent,
                    isTop: true,
                    scale: scale,
                  ),
                ),
              ),
            ),
            // Red player (bottom) dots - Wrapped in SafeArea
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
                    child: _DotColumn(
                      notifier: game.p1ThrowResults,
                      baseColor: Colors.redAccent,
                      isTop: false,
                      scale: scale,
                    ),
                  ),
                ),
              ),
            ),
            // Score display
            Positioned(
              left: -40 * scale,
              top: (screenHeight - 120 * scale) / 2,
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
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(2, 2),
                      ),
                    ],
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
                              valueListenable: game.p1ScoreNotifier,
                              builder: (_, v, _) => Text(
                                '$v',
                                style: const TextStyle(
                                  fontFamily: 'Programme',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                '.',
                                style: TextStyle(
                                  fontFamily: 'Programme',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                            ValueListenableBuilder<int>(
                              valueListenable: game.p2ScoreNotifier,
                              builder: (_, v, _) => Text(
                                '$v',
                                style: const TextStyle(
                                  fontFamily: 'Programme',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.blueAccent,
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
            // Exit button
            Positioned(
              right: -40 * scale,
              top: (screenHeight - 120 * scale) / 2,
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.centerRight,
                child: const HoldToExitButton(),
              ),
            ),
          ],
        );
      },
    );
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
    // 0.8 seconds to fully fill and exit (made more responsive)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
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
    // Jump to 20% immediately so the user sees the red bar and knows it's a hold button
    if (_controller.value < 0.2) {
      _controller.value = 0.2;
    }
    _controller.forward();
    HapticFeedback.lightImpact();
  }

  void _onHoldEnd() {
    _controller.reverse();
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
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(-2, 2),
            ),
          ],
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
                    fontFamily: 'Programme',
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

class _DotColumn extends StatelessWidget {
  final ValueNotifier<List<int?>> notifier;
  final Color baseColor;
  final bool isTop;
  final double scale;

  const _DotColumn({
    required this.notifier,
    required this.baseColor,
    required this.isTop,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<int?>>(
      valueListenable: notifier,
      builder: (context, results, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(GameConfig.knivesPerRound, (index) {
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
              margin: EdgeInsets.symmetric(vertical: 4 * scale),
              width: 12 * scale,
              height: 12 * scale,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black12, width: 1 * scale),
              ),
            );
          }),
        );
      },
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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: widget.game.winnerNotifier,
      builder: (context, winner, _) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (!_canRestart) return;
              widget.game.restartGame();
              widget.game.overlays.remove('gameOver');
              widget.game.overlays.add('hud');
            },
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  // Top half (Blue player)
                  Expanded(
                    child: RotatedBox(
                      quarterTurns: 2,
                      child: _GameOverPlayerSection(
                        player: 2,
                        winner: winner,
                        canRestart: _canRestart,
                      ),
                    ),
                  ),
                  // Bottom half (Red player)
                  Expanded(
                    child: _GameOverPlayerSection(
                      player: 1,
                      winner: winner,
                      canRestart: _canRestart,
                    ),
                  ),
                ],
              ),
            ),
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

  const _GameOverPlayerSection({
    required this.player,
    required this.winner,
    required this.canRestart,
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
                        'TAP TO PLAY AGAIN',
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
