import 'dart:math' as math;
import 'main.dart';
import 'utils.dart';

enum BotDifficulty { easy, medium, hard }

class BotController {
  final KnifeThrowerGame game;
  final BotDifficulty difficulty;
  final math.Random _rng = math.Random();

  double _botTimer = 0.0;
  double _nextBotActionDelay = 0.0;
  double _botWaitingTimer = 0.0;

  // Per-difficulty tuning
  late final double _minThrowDelay;
  late final double _maxThrowDelay;
  late final double _maxWaitBeforeRisk;
  late final double _safetyBuffer;
  late final double _missChance; // 0.0 = never misses, 1.0 = always misses

  BotController(this.game, {this.difficulty = BotDifficulty.medium}) {
    _applyDifficultySettings();
  }

  void _applyDifficultySettings() {
    switch (difficulty) {
      case BotDifficulty.easy:
        _minThrowDelay = 0.8;
        _maxThrowDelay = 2.2;
        _maxWaitBeforeRisk = 2.5;
        _safetyBuffer = 0.12;
        _missChance = 0.1;
        break;
      case BotDifficulty.medium:
        _minThrowDelay = 0.4;
        _maxThrowDelay = 1.0;
        _maxWaitBeforeRisk = 1.2;
        _safetyBuffer = 0.05;
        _missChance = 0.0;
        break;
      case BotDifficulty.hard:
        _minThrowDelay = 0.2;
        _maxThrowDelay = 0.6;
        _maxWaitBeforeRisk = 0.8;
        _safetyBuffer = 0.02; // Extreme precision
        _missChance = 0.0;
        break;
    }
  }

  void update(double dt) {
    if (!game.isBotMode ||
        game.isGameOver ||
        game.isTransitioning ||
        game.isCountingDown) {
      return;
    }

    final bool canThrow =
        game.p2ThrowsMade < GameConfig.knivesPerRound &&
        !game.p2Knife.isThrowing &&
        !game.p2Knife.isMoving;

    if (!canThrow) {
      _botWaitingTimer = 0.0; // Reset if we can't throw anyway
      return;
    }

    // Accumulate waiting time if we are past the initial decision delay
    if (_botTimer >= _nextBotActionDelay) {
      _botWaitingTimer += dt;
    }

    _botTimer += dt;

    if (_botTimer < _nextBotActionDelay) {
      return;
    }

    // Dynamic safety reduction: as we wait longer, we become less picky about the gap
    final safetyReduction = (_botWaitingTimer / _maxWaitBeforeRisk).clamp(0.0, 1.0);
    final effectiveSafetyBuffer = _safetyBuffer * (1.0 - safetyReduction);

    final bool safe = _checkBotSafety(extraBuffer: effectiveSafetyBuffer);
    final bool forcedByTimeout = _botWaitingTimer >= _maxWaitBeforeRisk;

    if (safe || forcedByTimeout) {
      _executeThrow();
    } else {
      // Not safe yet — keep waiting, timer is already accumulating above
      _botTimer = _nextBotActionDelay; // Keep us at the "decision ready" state
    }
  }

  void _executeThrow() {
    _botTimer = 0.0;
    _botWaitingTimer = 0.0;
    _nextBotActionDelay =
        _minThrowDelay + _rng.nextDouble() * (_maxThrowDelay - _minThrowDelay);

    // Simulate occasional human error on lower difficulties
    if (_rng.nextDouble() < _missChance) {
      _simulateMissThrow();
      return;
    }

    game.handleInput(2);
  }

  /// On easy mode the bot occasionally throws slightly off-rhythm,
  /// by scheduling a real throw after a small extra random hesitation.
  void _simulateMissThrow() {
    // Add a natural-feeling extra hesitation (0.2–0.7s) before the real throw,
    // giving the impression the bot "flinched" or second-guessed itself.
    _nextBotActionDelay += 0.2 + _rng.nextDouble() * 0.5;
  }

  bool _checkBotSafety({double extraBuffer = 0.0}) {
    // Player 2 (top) always impacts straight down in world space
    const double worldImpactAngle = -math.pi / 2;
    final double impactLocalAngle = normalizeAngle(
      worldImpactAngle - game.target.angle,
    );

    for (final child in game.target.children) {
      if (child is StuckKnife) {
        double diff = (impactLocalAngle - child.localAngle).abs();
        diff = diff % (2 * math.pi);
        if (diff > math.pi) diff = 2 * math.pi - diff;

        if (diff < GameConfig.collisionAngle + extraBuffer) {
          return false;
        }
      }
    }
    return true;
  }

  void reset() {
    _botTimer = 0.0;
    _botWaitingTimer = 0.0;
    // Give a natural startup delay so bot doesn't throw on frame 1
    _nextBotActionDelay = _minThrowDelay;
  }
}
