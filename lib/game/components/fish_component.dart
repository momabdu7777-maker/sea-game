import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../art/fish_visual.dart';
import '../../data/cast_result.dart';
import '../../data/fish_species.dart';
import '../sea_hunter_game.dart';
import '../systems/sea_spawner.dart';

enum FishState {
  swimming,

  /// عالقة في صراع السمكة الكبيرة.
  fighting,

  /// قطعت الخيط وتهرب.
  escaping,
  hooked,
  tossed,
  gone,
}

/// سمكة واحدة في البحر: تسبح حسب نمطها، تهرب أحياناً، تُعلّق في الصنارة،
/// ثم تُقذف في الهواء عند السطح.
class FishComponent extends PositionComponent with HasGameReference<SeaHunterGame> {
  FishComponent(FishSpawn spawn, double ppm)
    : species = spawn.species,
      weightKg = spawn.weightKg,
      seed = spawn.seed,
      _rng = math.Random(spawn.seed),
      _dir = spawn.dir,
      _homeY = spawn.depth * ppm,
      super(position: Vector2(spawn.x, spawn.depth * ppm), priority: 2, anchor: Anchor.center) {
    final range = species.maxWeight - species.minWeight;
    final norm = range <= 0 ? 0.5 : (weightKg - species.minWeight) / range;
    // الأثقل أكبر حجماً على الشاشة
    visual = createFishVisual(species, scale: 0.85 + 0.4 * norm);
    _speed = species.speed * (0.85 + _rng.nextDouble() * 0.3);
    _vx = _dir * _speed;
    _face = _dir.toDouble();
    _t = _rng.nextDouble() * 10;
    _bobPhase = _rng.nextDouble() * math.pi * 2;
    _behaviourTimer = 0.5 + _rng.nextDouble() * 2;
    radius = math.max(visual.length * 0.36, visual.height * 0.5);
  }

  final FishSpecies species;
  final double weightKg;

  /// بذرة هذه السمكة (تحدد حركتها وحركة صراعها).
  final int seed;
  late final FishVisual visual;
  late final double radius;
  final math.Random _rng;

  FishState state = FishState.swimming;
  CaughtFish? caught;

  bool get isSwimming => state == FishState.swimming;

  /// هل اصطيادها يحتاج صراعاً؟
  bool get needsFight => species.triggersFight(weightKg);

  int _dir;
  final double _homeY;
  late double _speed;
  double _vx = 0;
  double _face = 1;
  double _t = 0;
  double _bobPhase = 0;
  double _behaviourTimer = 0;
  double _pause = 0;
  double _burst = 1;
  double _yOffset = 0;
  double _yTarget = 0;
  double _evadeCooldown = 0;
  double _evadeBoost = 0;

  // معلّقة بالصنارة
  int _slot = 0;

  // القذف
  double _tossDelay = 0;
  double _tossTime = 0;
  double _tossDuration = 0.75;
  double _spin = 0;
  double _tossTargetX = 0;
  final Vector2 _vel = Vector2.zero();
  static const _gravity = 1400.0;

  void hookOn(int slot, CaughtFish data) {
    state = FishState.hooked;
    caught = data;
    _slot = slot;
    priority = 5;
  }

  // الصراع والهروب
  double _thrash = 0;
  double _escapeTime = 0;

  void startFight() {
    state = FishState.fighting;
    priority = 6;
  }

  /// وضعية الصراع: فم السمكة عند الصنارة وجسمها يتجه نحو جهة سحبها.
  /// [pull] من -1 (يسار) إلى 1 (يمين)، [thrash] شدة التخبط (0..1.5).
  void fightPose(Vector2 hookPos, double pull, double thrash) {
    _thrash = thrash;
    final dx = pull * 0.9, dy = 1.0;
    final len = math.sqrt(dx * dx + dy * dy);
    final ux = dx / len, uy = dy / len;
    position.setValues(hookPos.x + ux * visual.length * 0.42, hookPos.y + uy * visual.length * 0.42);
    _face = 1;
    // الرأس نحو الصنارة مع تخبط سريع
    angle = math.atan2(-uy, -ux) + math.sin(_t * (11 + 9 * thrash)) * (0.1 + 0.22 * thrash);
  }

  /// انقطع الخيط: السمكة تستدير وتهرب بعيداً.
  void escape(double pull) {
    state = FishState.escaping;
    _escapeTime = 0;
    final dx = pull * 0.9 + (pull >= 0 ? 0.25 : -0.25), dy = 1.0;
    final len = math.sqrt(dx * dx + dy * dy);
    _vel.setValues(dx / len * 160, dy / len * 160);
    angle = math.atan2(_vel.y, _vel.x);
    _face = 1;
  }

  void _updateEscape(double dt) {
    _escapeTime += dt;
    // تسارع للأعماق مع ذيل يضرب بقوة
    _vel.scale(1 + 1.6 * dt);
    position.addScaled(_vel, dt);
    angle = math.atan2(_vel.y, _vel.x) + math.sin(_t * 16) * 0.12;
    if (_escapeTime > 2.2) {
      state = FishState.gone;
      removeFromParent();
    }
  }

  void toss({required double delay, required double targetX}) {
    state = FishState.tossed;
    _tossDelay = delay;
    _tossTime = 0;
    _tossTargetX = targetX;
    priority = 9;
  }

  void popNow() {
    if (state == FishState.hooked || state == FishState.tossed) _pop();
  }

  void _pop() {
    state = FishState.gone;
    game.onFishPopped(this);
    removeFromParent();
  }

  @override
  void update(double dt) {
    _t += dt;
    switch (state) {
      case FishState.swimming:
        _swim(dt);
      case FishState.fighting:
        break; // اللعبة تحدد وضعيتها عبر fightPose
      case FishState.escaping:
        _updateEscape(dt);
      case FishState.hooked:
        _hang();
      case FishState.tossed:
        _updateToss(dt);
      case FishState.gone:
        break;
    }
  }

  void _hang() {
    final h = game.hook;
    final spread = (_slot.isEven ? 1 : -1) * ((_slot + 1) ~/ 2) * 7.0;
    position.setValues(h.x + spread, h.y + visual.length * 0.5 + 8 + _slot * 4);
    // تتلوى رأساً للأعلى
    angle = -math.pi / 2 + math.sin(_t * 14 + _slot * 1.7) * 0.32;
    _face = 1;
  }

  void _updateToss(double dt) {
    if (_tossDelay > 0) {
      _tossDelay -= dt;
      _hang();
      if (_tossDelay <= 0) {
        // انطلاق نحو قمة القذفة
        _tossDuration = 0.55 + _rng.nextDouble() * 0.1;
        _vel.setValues((_tossTargetX - x) / _tossDuration, -_gravity * _tossDuration);
        _spin = (_rng.nextBool() ? 1 : -1) * (6 + _rng.nextDouble() * 5);
        game.fx.splash(position, count: 8);
      }
      return;
    }
    _tossTime += dt;
    _vel.y += _gravity * dt;
    position.addScaled(_vel, dt);
    angle += _spin * dt;
    _spin *= math.exp(-2.5 * dt);
    if (_tossTime >= _tossDuration) _pop();
  }

  void _swim(double dt) {
    final w = game.size.x;
    _behaviourTimer -= dt;
    if (_evadeCooldown > 0) _evadeCooldown -= dt;
    if (_evadeBoost > 0) _evadeBoost -= dt;
    var desired = _speed;

    switch (species.movement) {
      case FishMovement.school:
        _yTarget = math.sin(_t * 1.7 + _bobPhase) * 5;
      case FishMovement.cruise:
        if (_behaviourTimer <= 0) {
          _behaviourTimer = 2 + _rng.nextDouble() * 3;
          final r = _rng.nextDouble();
          if (r < 0.25) {
            _dir = -_dir;
          } else if (r < 0.45) {
            _pause = 0.5 + _rng.nextDouble() * 0.8;
          }
          _yTarget = (_rng.nextDouble() - 0.5) * 30;
        }
        if (_pause > 0) {
          _pause -= dt;
          desired *= 0.1;
        }
      case FishMovement.dart:
        // نادرة: اتجاه وسرعة متقلبان بشكل غير متوقع
        if (_behaviourTimer <= 0) {
          _behaviourTimer = 0.45 + _rng.nextDouble() * 1.1;
          if (_rng.nextDouble() < 0.5) _dir = -_dir;
          _burst = 0.5 + _rng.nextDouble() * 1.4;
          _yTarget = (_rng.nextDouble() - 0.5) * 70;
        }
        desired *= _burst;
      case FishMovement.pulse:
        // اندفاعة ثم انزلاق
        final p = (_t * 0.75 + _bobPhase) % 1.0;
        desired *= p < 0.22 ? 2.8 * (1 - p / 0.22) + 0.3 : 0.3;
        if (_behaviourTimer <= 0) {
          _behaviourTimer = 2.5 + _rng.nextDouble() * 2;
          if (_rng.nextDouble() < 0.35) _dir = -_dir;
          _yTarget = (_rng.nextDouble() - 0.5) * 40;
        }
      case FishMovement.crawl:
        if (_behaviourTimer <= 0) {
          _behaviourTimer = 1.5 + _rng.nextDouble() * 2.5;
          _pause = _rng.nextDouble() < 0.4 ? 0.8 : 0;
          if (_rng.nextDouble() < 0.3) _dir = -_dir;
        }
        if (_pause > 0) {
          _pause -= dt;
          desired = 0;
        }
        _yTarget = math.sin(_t * 0.8 + _bobPhase) * 3;
    }

    _maybeEvade();
    if (_evadeBoost > 0) desired *= 2.4;

    // الارتداد عند حواف الشاشة
    final margin = radius * 0.6;
    if (x < margin && _dir < 0) _dir = 1;
    if (x > w - margin && _dir > 0) _dir = -1;

    final target = _dir * desired;
    _vx += (target - _vx) * (1 - math.exp(-5 * dt));
    x += _vx * dt;
    _yOffset += (_yTarget - _yOffset) * (1 - math.exp(-2 * dt));
    y = _homeY + _yOffset + math.sin(_t * 2.3 + _bobPhase) * 2;
    if (_vx.abs() > 4) _face = _vx.sign;
    angle = 0;
  }

  /// الأسماك النادرة قد تفرّ عند اقتراب الصنارة — هذا ما يجعل صيدها مهارة.
  void _maybeEvade() {
    if (species.evasion <= 0 || _evadeCooldown > 0) return;
    if (game.phase.value != CastPhase.ascending) return;
    final h = game.hook;
    final dx = x - h.x, dy = y - h.y;
    if (dx * dx + dy * dy > 95 * 95) return;
    if (_rng.nextDouble() < species.evasion) {
      _dir = dx >= 0 ? 1 : -1;
      _evadeBoost = 0.6;
      _yTarget += dy >= 0 ? 30 : -30;
      _evadeCooldown = 1.6;
      game.fx.bubbles(position, 4);
    } else {
      _evadeCooldown = 1.0;
    }
  }

  @override
  void render(Canvas canvas) {
    if (!game.isVisibleY(y, 120)) return;
    if (_face < 0) canvas.scale(-1, 1);
    final swim = switch (state) {
      FishState.swimming => (_vx.abs() / math.max(1, _speed)).clamp(0.2, 1.8),
      FishState.fighting => 1.2 + _thrash * 0.6,
      FishState.escaping => 2.0,
      _ => 1.6,
    };
    visual.render(canvas, _t, swim: swim);
  }
}
