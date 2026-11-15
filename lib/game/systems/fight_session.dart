import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../config/game_config.dart';
import '../../data/fish_species.dart';

/// أرقام صراع سمكة واحدة — تُحسب من [GameConfig] + نوع السمكة ووزنها + ترقية "قوة الخيط".
class FightTuning {
  const FightTuning({
    required this.power,
    required this.zoneWidth,
    required this.reelAccel,
    required this.slackAccel,
    required this.maxVelocity,
    required this.bounce,
    required this.drag,
    required this.startProgress,
    required this.gainRate,
    required this.lossRate,
    required this.snapSeconds,
    required this.dangerRecover,
    required this.introSeconds,
    required this.zoneSpeed,
    required this.retargetSeconds,
    required this.runChancePerSecond,
    required this.runBoost,
    required this.runSeconds,
  });

  factory FightTuning.forFish(GameConfig c, FishSpecies s, double weightKg, {int lineStrengthLevel = 0}) {
    final range = s.maxWeight - s.minWeight;
    final norm = range <= 0 ? 0.5 : ((weightKg - s.minWeight) / range).clamp(0.0, 1.0);
    final power = (s.fightPower + norm * c.fightWeightPowerBonus).clamp(0.0, 1.0);
    final lvl = math.max(0, lineStrengthLevel);
    return FightTuning(
      power: power,
      zoneWidth: (c.fightZoneBase - power * c.fightZoneShrinkPerPower + lvl * c.fightZonePerStrengthLevel).clamp(
        c.fightZoneMin,
        c.fightZoneMax,
      ),
      reelAccel: c.fightReelAccel,
      slackAccel: c.fightSlackAccel,
      maxVelocity: c.fightMaxVelocity,
      bounce: c.fightBounce,
      drag: c.fightDrag,
      startProgress: c.fightStartProgress,
      gainRate: c.fightGainRate * (1 - power * c.fightGainPowerPenalty),
      lossRate: c.fightLossRate,
      snapSeconds: c.fightSnapSeconds + lvl * c.fightSnapPerStrengthLevel,
      dangerRecover: c.fightDangerRecover,
      introSeconds: c.fightIntroSeconds,
      zoneSpeed: c.fightZoneSpeedBase + power * c.fightZoneSpeedPerPower,
      retargetSeconds: c.fightRetargetSlow + (c.fightRetargetFast - c.fightRetargetSlow) * power,
      runChancePerSecond: power * c.fightRunChancePerSecond,
      runBoost: c.fightRunBoost,
      runSeconds: c.fightRunSeconds,
    );
  }

  /// شراسة السمكة النهائية (0..1).
  final double power;
  final double zoneWidth;
  final double reelAccel;
  final double slackAccel;
  final double maxVelocity;
  final double bounce;
  final double drag;
  final double startProgress;
  final double gainRate;
  final double lossRate;
  final double snapSeconds;
  final double dangerRecover;
  final double introSeconds;
  final double zoneSpeed;
  final double retargetSeconds;
  final double runChancePerSecond;
  final double runBoost;
  final double runSeconds;
}

enum FightStatus {
  /// مهلة البداية: المؤشر يتحرك لكن لا تقدم ولا خطر.
  intro,
  active,
  won,

  /// انقطع الخيط.
  snapped,
}

/// أحداث تهم اللعبة (صوت، اهتزاز، مؤثرات).
enum FightEvent { none, started, run, won, snapped }

/// منطق صراع السمكة الكبيرة — بدون أي رسم، ليسهل اختباره وضبطه.
///
/// - شريط أفقي من 0 (إرخاء) إلى 1 (شد). الضغط يدفع المؤشر نحو الشد، والإفلات يرخيه.
/// - منطقة خضراء تتحرك حسب شراسة السمكة، مع "اندفاعات" مفاجئة.
/// - داخل الأخضر: شريط التقدم يمتلئ والخيط يتعافى.
/// - خارج الأخضر: التقدم ينقص، والبقاء خارجه [FightTuning.snapSeconds] ثانية يقطع الخيط.
///
/// نفس البذرة = نفس حركة السمكة (مهم لـ "تحدي صديق").
class FightSession extends ChangeNotifier {
  FightSession(this.tuning, {required int seed})
    : _rng = math.Random(seed),
      progress = tuning.startProgress,
      _retarget = tuning.introSeconds + 0.4;

  final FightTuning tuning;
  final math.Random _rng;

  FightStatus status = FightStatus.intro;
  double time = 0;

  /// موضع المؤشر (0..1) وسرعته.
  double indicator = 0.5;
  double velocity = 0;

  /// مركز المنطقة الخضراء وسرعتها.
  double zoneCenter = 0.5;
  double zoneVelocity = 0;

  /// شريط التقدم (1 = اصطيدت).
  double progress;

  /// ثوانٍ متراكمة خارج الأخضر (يقطع الخيط عند [FightTuning.snapSeconds]).
  double danger = 0;

  bool holding = false;

  double _target = 0.5;
  double _retarget;
  double _runLeft = 0;
  double _runCooldown = 1.5;

  double get zoneStart => zoneCenter - tuning.zoneWidth / 2;
  double get zoneEnd => zoneCenter + tuning.zoneWidth / 2;
  bool get inZone => (indicator - zoneCenter).abs() <= tuning.zoneWidth / 2;
  double get dangerFraction => (danger / tuning.snapSeconds).clamp(0.0, 1.0);
  bool get isRunning => _runLeft > 0;
  bool get isIntro => status == FightStatus.intro;
  bool get isOver => status == FightStatus.won || status == FightStatus.snapped;

  /// اتجاه سحب السمكة (-1..1) — يُستخدم لتحريك السمكة والصنارة على الشاشة.
  double get pull => ((zoneCenter - 0.5) * 2).clamp(-1.0, 1.0);

  /// خطوة واحدة. [holding] = هل إصبع اللاعب على الشاشة.
  FightEvent update(double dt, {required bool holding}) {
    if (isOver || dt <= 0) return FightEvent.none;
    this.holding = holding;
    time += dt;
    _moveIndicator(dt);

    if (status == FightStatus.intro) {
      if (time >= tuning.introSeconds) {
        status = FightStatus.active;
        notifyListeners();
        return FightEvent.started;
      }
      notifyListeners();
      return FightEvent.none;
    }

    var event = _moveZone(dt);
    if (inZone) {
      progress += tuning.gainRate * dt;
      danger = math.max(0, danger - tuning.dangerRecover * dt);
    } else {
      progress -= tuning.lossRate * dt;
      danger += dt;
    }
    progress = progress.clamp(0.0, 1.0);

    if (progress >= 1) {
      status = FightStatus.won;
      event = FightEvent.won;
    } else if (danger >= tuning.snapSeconds) {
      danger = tuning.snapSeconds;
      status = FightStatus.snapped;
      event = FightEvent.snapped;
    }
    notifyListeners();
    return event;
  }

  void _moveIndicator(double dt) {
    velocity += ((holding ? tuning.reelAccel : -tuning.slackAccel) - tuning.drag * velocity) * dt;
    velocity = velocity.clamp(-tuning.maxVelocity, tuning.maxVelocity);
    indicator += velocity * dt;
    if (indicator < 0) {
      indicator = 0;
      velocity = -velocity * tuning.bounce;
    } else if (indicator > 1) {
      indicator = 1;
      velocity = -velocity * tuning.bounce;
    }
  }

  FightEvent _moveZone(double dt) {
    var event = FightEvent.none;
    final half = tuning.zoneWidth / 2;
    _retarget -= dt;
    _runCooldown -= dt;
    if (_runLeft > 0) _runLeft -= dt;

    if (_runLeft <= 0 && _runCooldown <= 0 && _rng.nextDouble() < tuning.runChancePerSecond * dt) {
      // اندفاعة: السمكة تسحب بقوة نحو الطرف البعيد
      _runLeft = tuning.runSeconds;
      _runCooldown = 2.2;
      _target = zoneCenter < 0.5 ? 1 - half : half;
      event = FightEvent.run;
    } else if (_retarget <= 0 && _runLeft <= 0) {
      _retarget = tuning.retargetSeconds * (0.6 + _rng.nextDouble() * 0.8);
      _target = half + _rng.nextDouble() * (1 - 2 * half);
    }

    final speed = tuning.zoneSpeed * (_runLeft > 0 ? tuning.runBoost : 1);
    final desired = ((_target - zoneCenter) * 5).clamp(-speed, speed);
    zoneVelocity += (desired - zoneVelocity) * (1 - math.exp(-8 * dt));
    zoneCenter += zoneVelocity * dt;
    if (zoneCenter < half) {
      zoneCenter = half;
      zoneVelocity = 0;
    } else if (zoneCenter > 1 - half) {
      zoneCenter = 1 - half;
      zoneVelocity = 0;
    }
    return event;
  }
}
