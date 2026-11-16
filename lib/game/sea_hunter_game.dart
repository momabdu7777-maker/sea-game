import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../config/game_config.dart';
import '../data/cast_result.dart';
import '../data/fish_species.dart';
import '../data/rarity.dart';
import '../data/stage.dart';
import '../services/game_audio.dart';
import '../services/haptics.dart';
import '../state/player_state.dart';
import '../utils/format.dart';
import 'components/aim_indicator.dart';
import 'components/boat.dart';
import 'components/depth_markers.dart';
import 'components/depth_vignette.dart';
import 'components/fish_component.dart';
import 'components/fishing_line.dart';
import 'components/floating_label.dart';
import 'components/fx_layer.dart';
import 'components/hook.dart';
import 'components/obstacle_component.dart';
import 'components/water_backdrop.dart';
import 'components/wave_surface.dart';
import 'systems/fight_session.dart';
import 'systems/sea_spawner.dart';

/// مراحل الرمية الواحدة.
enum CastPhase {
  /// على القارب، اللاعب يسحب للرمي.
  aiming,

  /// الصنارة تطير في الهواء.
  flying,

  /// النزول وتفادي العوائق.
  descending,

  /// توقف قصير عند القاع أو بعد الاصطدام.
  turning,

  /// الصعود والتقاط الأسماك.
  ascending,

  /// صراع سمكة كبيرة (اضغط وأفلت لإبقاء المؤشر في المنطقة الخضراء).
  fighting,

  /// الوصول للسطح وقذف الأسماك احتفالاً.
  surfacing,

  /// شاشة النتيجة.
  results;

  bool get isUnderwater => this == descending || this == turning || this == ascending || this == fighting;
}

enum BannerTone { info, good, bad, epic }

/// رسالة قصيرة تظهر وسط الشاشة.
class GameBanner {
  GameBanner(this.text, {this.tone = BannerTone.info}) : id = _next++;
  static int _next = 0;

  final String text;
  final BannerTone tone;
  final int id;
}

/// نهاية صراع: فوز أو انقطاع الخيط، مع السمكة (لعرضها في بطاقة "كانت بيدك!").
class FightOutcome {
  FightOutcome({required this.won, required this.fish});

  final bool won;
  final CaughtFish fish;
}

/// اللعبة نفسها (Flame). القوائم والواجهات في Flutter فوقها كـ overlays.
///
/// التواصل مع Flutter:
/// - قيم سريعة التغير (العمق، عدد الأسماك...) عبر [ValueNotifier] لتجنب إعادة
///   بناء الواجهة كلها 60 مرة في الثانية.
/// - الحالة الدائمة (الريالات، الألبوم) عبر Riverpod من خلال [readPlayer] و[onCastFinished].
class SeaHunterGame extends FlameGame {
  SeaHunterGame({
    required this.config,
    required this.catalog,
    required this.readPlayer,
    required this.onCastFinished,
    required this.audio,
    StageCatalog? stages,
  }) : stages = stages ?? StageCatalog.single,
       _spawner = SeaSpawner(config, catalog);

  final GameConfig config;
  final FishCatalog catalog;

  /// المراحل (المرحلة الحالية تُقرأ من حالة اللاعب عند تجهيز كل بحر).
  final StageCatalog stages;
  final PlayerState Function() readPlayer;
  final CastResult Function(CastResult) onCastFinished;
  final GameAudio audio;
  final SeaSpawner _spawner;

  // ---------- قيم للواجهة ----------
  final phase = ValueNotifier<CastPhase>(CastPhase.aiming);
  final depthMeters = ValueNotifier<int>(0);
  final caughtCount = ValueNotifier<int>(0);
  final capacity = ValueNotifier<int>(0);
  final lineLength = ValueNotifier<double>(0);

  /// أقصى عمق ممكن للرمية = الأقل بين طول الخيط وقاع المرحلة.
  final castLimit = ValueNotifier<double>(0);
  final banner = ValueNotifier<GameBanner?>(null);
  final dragging = ValueNotifier<bool>(false);

  /// الصراع الحالي (null خارج الصراع) ونتيجته عند انتهائه.
  final fightSession = ValueNotifier<FightSession?>(null);
  final fightOutcome = ValueNotifier<FightOutcome?>(null);

  /// إظهار شرح التحكم في أول الصراعات.
  bool fightShowHelp = false;
  CastResult? lastResult;

  // ---------- المكونات ----------
  late final Boat boat;
  late final HookComponent hook;
  late final FxLayer fx;
  final List<FishComponent> fishes = [];
  final List<ObstacleComponent> obstacles = [];
  final List<FishComponent> hooked = [];
  final List<CaughtFish> _catches = [];
  final List<CaughtFish> _lost = [];
  final List<bool> _fightLog = [];

  // ---------- الكاميرا ----------
  /// أعلى نقطة مرئية في العالم (y). سطح الماء عند y = 0 والعمق موجب للأسفل.
  double camTop = 0;
  double camVelocity = 0;
  double _shake = 0;
  final _rng = math.Random();

  // ---------- حالة الرمية ----------
  double _phaseTime = 0;
  double _slowMo = 0;
  double _descendSpeed = 0;
  double _targetDepth = 0;
  double _maxDepth = 0;
  DescentEnd _end = DescentEnd.reachedDepth;
  String? _obstacleName;
  int _seed = 0;
  int _lastDepthTick = 0;
  double _bannerTimer = 0;
  int _pendingPops = 0;
  double _finishTimer = -1;
  final Vector2 _flyFrom = Vector2.zero();
  final Vector2 _flyTo = Vector2.zero();

  // ---------- حالة الصراع ----------
  FishComponent? _fightFish;
  CaughtFish? _fightCatch;
  bool _pointerIsDown = false;
  double _fightAnchorY = 0;
  double _outcomeTimer = 0;
  double _hapticTimer = 0;
  double _pendingHaptic = -1;
  double _reelTimer = 0;
  double _strainCooldown = 0;
  double _time = 0;

  /// السمكة الجاري صراعها (لعرض اسمها ووزنها وقيمتها).
  CaughtFish? get fightCatchPreview => _fightCatch;

  /// لاختبارات الواجهة فقط.
  @visibleForTesting
  set debugFightCatch(CaughtFish? c) => _fightCatch = c;

  /// مؤثر ارتداد الخيط بعد انقطاعه (1 → 0).
  double lineSnapFx = 0;

  /// وقت اللعب الكلي (للمؤثرات المتذبذبة مثل ارتجاف الخيط).
  double get time => _time;

  // ---------- السحب للرمي ----------
  Vector2? _aimStart;
  double aimPower = 0;
  double aimPullX = 0;
  int _lastPowerStep = 0;

  bool get isAimDragging => _aimStart != null && phase.value == CastPhase.aiming;
  double get ppm => config.pxPerMeter;
  double get hookDepth => math.max(0, hook.y / ppm);
  double get viewWidth => size.x;
  double get viewHeight => size.y;
  bool get isFull => hooked.length >= capacity.value;

  /// المرحلة التي جُهّز لها البحر الحالي.
  Stage get stage => _stage;
  Stage _stage = Stage.open;

  // ---------- القوائم (الشرح، التطوير، المراحل) ----------
  static const menuOverlays = ['help', 'shop', 'stages'];

  /// أثناء فتح قائمة لا يصل اللمس للعبة (حتى لا يتحول تمرير القائمة إلى رمية).
  bool get menuOpen => menuOverlays.any(overlays.isActive);

  void openMenu(String name) {
    _aimStart = null;
    dragging.value = false;
    boat.bend = 0;
    for (final m in menuOverlays) {
      if (m != name && overlays.isActive(m)) overlays.remove(m);
    }
    overlays.add(name);
  }

  void closeMenu(String name) => overlays.remove(name);

  /// أزرار الواجهة تعلّم اللمسة حتى لا تبدأ رمية تحتها (انظر UiTouch).
  bool _uiTouch = false;
  void markUiTouch() => _uiTouch = true;
  bool consumeUiTouch() {
    final v = _uiTouch;
    _uiTouch = false;
    return v;
  }

  /// يعيد تجهيز البحر بعد شراء ترقية أو تغيير المرحلة (فقط قبل الرمية).
  void reloadSea() {
    if (phase.value == CastPhase.aiming && isLoaded) _prepareSea();
  }
  /// العمق المتوقع للقوة الحالية أثناء السحب.
  double depthForPower(double p) =>
      p >= config.perfectCastThreshold ? castLimit.value : math.max(config.minCastDepth, p * castLimit.value);

  /// نقطة دخول الصنارة للماء — السحب يساراً يرمي يميناً (مثل المقلاع).
  double entryXForPull(double pullX) => (size.x * 0.5 - pullX * 0.9).clamp(36.0, size.x - 36.0);

  bool isVisibleY(double y, double margin) => y > camTop - margin && y < camTop + size.y + margin;

  double get _aimCamTop => -size.y * 0.42;

  @override
  Color backgroundColor() => const Color(0xFF0B4F86);

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
    camTop = _aimCamTop;
    camera.backdrop.add(WaterBackdrop());
    world.addAll([DepthMarkers(), boat = Boat(), FishingLine(), hook = HookComponent(), WaveSurface(), fx = FxLayer(), AimIndicator()]);
    camera.viewport.addAll([DepthVignette(), PowerGauge()]);
    _prepareSea();
    _applyCamera();
  }

  // =====================================================================
  //                              الإدخال
  // =====================================================================

  void pointerDown(Vector2 p) {
    if (menuOpen) return;
    _pointerIsDown = true;
    switch (phase.value) {
      case CastPhase.aiming:
        _aimStart = p.clone();
        dragging.value = true;
        aimPower = 0;
        aimPullX = 0;
        _lastPowerStep = 0;
      case CastPhase.surfacing:
        if (_phaseTime > 0.35) _skipCelebration();
      default:
        break;
    }
  }

  void pointerMove(Vector2 p, Vector2 delta) {
    if (menuOpen) return;
    switch (phase.value) {
      case CastPhase.aiming:
        final start = _aimStart;
        if (start == null) return;
        final pullX = p.x - start.x;
        final pullY = p.y - start.y;
        // السحب للأسفل (للخلف) هو الأساس، والسحب الجانبي يساهم قليلاً
        final dist = math.sqrt(math.max(0, pullY) * math.max(0, pullY) + pullX * pullX * 0.35);
        aimPower = (dist / (size.y * config.maxPullScreenFraction)).clamp(0.0, 1.0);
        aimPullX = pullX;
        boat.bend = aimPower;
        // "تكة" لمسية وصوتية كل 10% — تعطي إحساس بكرة الصنارة
        final step = (aimPower * 10).floor();
        if (step != _lastPowerStep) {
          _lastPowerStep = step;
          Haptics.tick();
          audio.play(Sfx.tick, volume: 0.25 + aimPower * 0.4);
        }
      case CastPhase.descending:
      case CastPhase.turning:
      case CastPhase.ascending:
        hook.targetX += delta.x * config.steerSensitivity;
      default:
        break;
    }
  }

  void pointerUp() {
    _pointerIsDown = false;
    if (phase.value == CastPhase.aiming && _aimStart != null && !menuOpen) {
      if (aimPower >= config.minPowerToCast) {
        _startCast();
      } else {
        boat.bend = 0;
      }
    }
    _aimStart = null;
    dragging.value = false;
  }

  // =====================================================================
  //                           دورة الرمية
  // =====================================================================

  void _setPhase(CastPhase p) {
    phase.value = p;
    _phaseTime = 0;
  }

  void showBanner(String text, {BannerTone tone = BannerTone.info, double seconds = 1.5}) {
    banner.value = GameBanner(text, tone: tone);
    _bannerTimer = seconds;
  }

  /// يجهّز بحراً جديداً (أسماك + عوائق) ببذرة جديدة قبل الرمية،
  /// فيرى اللاعب الأسماك تسبح ويختار أين يرمي.
  void _prepareSea() {
    for (final f in fishes) {
      f.removeFromParent();
    }
    for (final o in obstacles) {
      o.removeFromParent();
    }
    fishes.clear();
    obstacles.clear();
    hooked.clear();
    _catches.clear();
    _lost.clear();
    _fightLog.clear();
    _clearFight();

    final player = readPlayer();
    _stage = stages.byId(player.currentStage);
    lineLength.value = config.lineLengthForLevel(player.lineLevel);
    castLimit.value = math.min(lineLength.value, _stage.seabed);
    capacity.value = config.hookCapacityForLevel(player.hookLevel);
    caughtCount.value = 0;
    depthMeters.value = 0;

    _seed = DateTime.now().microsecondsSinceEpoch & 0x3fffffff;
    final plan = _spawner.plan(seed: _seed, maxDepth: castLimit.value, width: size.x, stage: _stage);
    for (final s in plan.obstacles) {
      obstacles.add(ObstacleComponent(s, ppm));
    }
    for (final s in plan.fish) {
      fishes.add(FishComponent(s, ppm));
    }
    world.addAll(obstacles);
    world.addAll(fishes);
  }

  void _startCast() {
    final power = aimPower;
    _targetDepth = depthForPower(power);
    _maxDepth = 0;
    _end = DescentEnd.reachedDepth;
    _obstacleName = null;
    _lastDepthTick = 0;
    boat.bend = 0;
    _flyFrom.setFrom(boat.rodTip);
    _flyTo.setValues(entryXForPull(aimPullX), 0);
    hook.position.setFrom(_flyFrom);
    _setPhase(CastPhase.flying);
    audio.play(Sfx.whoosh, volume: 0.5 + power * 0.5);
    Haptics.medium();
    if (power >= config.perfectCastThreshold) {
      showBanner('رمية كاملة! 💪', tone: BannerTone.good);
    }
  }

  void _enterWater() {
    hook.position.setFrom(_flyTo);
    hook.targetX = hook.x;
    _descendSpeed = config.descendStartSpeed;
    fx.splash(hook.position, count: 16);
    audio.play(Sfx.splash, volume: 0.8);
    Haptics.light();
    _setPhase(CastPhase.descending);
  }

  void _hitObstacle(ObstacleComponent o) {
    _end = DescentEnd.hitObstacle;
    _obstacleName = o.kind.arabicName;
    o.onHit();
    hook.flash();
    _shake = 14;
    fx.sparks(hook.position);
    audio.play(Sfx.thunk);
    Haptics.heavy();
    showBanner('آخ! ${o.kind.arabicName}', tone: BannerTone.bad);
    _setPhase(CastPhase.turning);
  }

  void _reachBottom() {
    _end = DescentEnd.reachedDepth;
    _shake = 4;
    fx.bubbles(hook.position, 8);
    Haptics.medium();
    final atSeabed = castLimit.value < lineLength.value && _targetDepth >= castLimit.value;
    showBanner(atSeabed ? 'وصلت إلى القاع! اصطد الآن ⬆' : 'اصطد الآن! ⬆', tone: BannerTone.good, seconds: 1.1);
    _setPhase(CastPhase.turning);
  }

  CaughtFish _caughtFrom(FishComponent f, {bool fromFight = false}) => CaughtFish(
    species: f.species,
    weightKg: f.weightKg,
    value: (SeaSpawner.priceOf(config, f.species, f.weightKg) * _stage.priceMultiplier).round(),
    fromFight: fromFight,
  );

  void _catch(FishComponent f) {
    final s = f.species;
    final c = _caughtFrom(f);
    f.hookOn(hooked.length, c);
    hooked.add(f);
    _catches.add(c);
    caughtCount.value = hooked.length;
    fx.catchBurst(f.position, s.bodyColor);
    _slowMo = config.catchSlowMoSeconds;
    audio.play(Sfx.pop, volume: 0.9);
    if (s.rarity.index >= Rarity.rare.index) {
      Haptics.medium();
      showBanner('${s.name}! ✨ ${s.rarity.arabicName}', tone: BannerTone.epic);
    } else {
      Haptics.light();
    }
    if (isFull) {
      Haptics.medium();
      showBanner('الصنارة ممتلئة! 🎣', tone: BannerTone.good);
    }
  }

  void _surface() {
    hook.y = 0;
    _setPhase(CastPhase.surfacing);
    fx.splash(hook.position, count: 22 + hooked.length * 6);
    audio.play(Sfx.splash);
    Haptics.medium();
    _pendingPops = hooked.length;
    _finishTimer = hooked.isEmpty ? 0.8 : -1;
    // الأسماك تُقذف للأعلى واحدة تلو الأخرى وتتوزع في السماء
    final n = hooked.length;
    for (var i = 0; i < n; i++) {
      final spread = n == 1 ? 0.0 : (i / (n - 1) - 0.5);
      hooked[i].toss(delay: 0.12 + i * 0.16, targetX: size.x * (0.5 + spread * 0.62));
    }
  }

  /// تستدعيها السمكة عند وصولها لقمة القذفة.
  void onFishPopped(FishComponent f) {
    final c = f.caught!;
    fx.coins(f.position, (c.value / 6).clamp(3, 14).round());
    fx.catchBurst(f.position, c.species.rarity.color);
    world.add(
      FloatingLabel(
        position: f.position.clone(),
        title: c.species.name,
        subtitle: '${formatKg(c.weightKg)} كغ  •  +${c.value} ريال',
        color: c.species.rarity.color,
      ),
    );
    audio.play(Sfx.coin, volume: 0.8);
    Haptics.light();
    _pendingPops--;
    if (_pendingPops <= 0) _finishTimer = 1.1;
  }

  void _skipCelebration() {
    for (final f in List.of(hooked)) {
      f.popNow();
    }
    _finishTimer = math.min(_finishTimer < 0 ? 0.35 : _finishTimer, 0.35);
  }

  void _finishCast() {
    _finishTimer = -1;
    final result = CastResult(
      fish: List.of(_catches),
      maxDepth: _maxDepth,
      end: _end,
      obstacleName: _obstacleName,
      seed: _seed,
      lost: List.of(_lost),
      fightLog: List.of(_fightLog),
      stageId: _stage.id,
    );
    lastResult = onCastFinished(result);
    if (result.completedStage || result.hasNewSpecies || result.fish.any((f) => f.species.rarity.index >= Rarity.epic.index)) {
      audio.play(Sfx.fanfare, volume: 0.7);
      Haptics.medium();
    }
    _setPhase(CastPhase.results);
    overlays.add('results');
  }

  /// زر "رمية جديدة".
  void newCast() {
    overlays.remove('results');
    banner.value = null;
    _prepareSea();
    _setPhase(CastPhase.aiming);
  }

  // =====================================================================
  //                       صراع السمكة الكبيرة
  // =====================================================================

  void _startFight(FishComponent f) {
    final s = f.species;
    final player = readPlayer();
    _fightFish = f..startFight();
    _fightCatch = _caughtFrom(f, fromFight: true);
    fightShowHelp = player.totalFights < 3;
    fightOutcome.value = null;
    fightSession.value = FightSession(
      FightTuning.forFish(config, s, f.weightKg, lineStrengthLevel: player.lineStrengthLevel),
      seed: f.seed ^ _seed,
    );
    _fightAnchorY = hook.y;
    hook.targetX = hook.x;
    _hapticTimer = 0.3;
    _reelTimer = 0;
    _strainCooldown = 0;
    _slowMo = config.fightStartSlowMoSeconds;
    _shake = 12;
    fx.catchBurst(hook.position, s.rarity.color);
    fx.bubbles(hook.position, 16);
    audio.play(Sfx.thunk, volume: 0.9);
    audio.play(Sfx.strain, volume: 0.6);
    Haptics.heavy();
    showBanner('سمكة كبيرة! 💪 ${s.name}', tone: BannerTone.epic, seconds: 1.6);
    overlays.add('fight');
    _setPhase(CastPhase.fighting);
  }

  void _updateFight(double dt) {
    final fs = fightSession.value;
    final f = _fightFish;
    if (fs == null || f == null) {
      _setPhase(CastPhase.ascending);
      return;
    }

    if (_pendingHaptic > 0) {
      _pendingHaptic -= dt;
      if (_pendingHaptic <= 0) Haptics.heavy();
    }

    // بعد النهاية: لحظة قصيرة لعرض النتيجة ثم نكمل الصعود
    if (fs.isOver) {
      _outcomeTimer -= dt;
      if (fs.status == FightStatus.won) hook.y -= ppm * 2 * dt;
      _trackDepth();
      if (_outcomeTimer <= 0) _endFight();
      return;
    }

    final event = fs.update(dt, holding: _pointerIsDown);

    // السمكة تسحب الصنارة نحو جهتها، والتقدم يرفع الصنارة قليلاً (لفّ البكرة)
    final prevX = hook.x;
    final targetX = (size.x * 0.5 + fs.pull * size.x * 0.26).clamp(30.0, size.x - 30.0);
    hook.x += (targetX - hook.x) * (1 - math.exp(-2.5 * dt));
    hook.targetX = hook.x;
    hook.vx = dt > 0 ? (hook.x - prevX) / dt : 0;
    final reeled = (fs.progress - fs.tuning.startProgress) * config.fightReelMeters * ppm;
    final targetY = math.max(ppm * 3, _fightAnchorY - reeled + (fs.isRunning ? ppm * 1.5 : 0));
    hook.y += (targetY - hook.y) * (1 - math.exp(-4 * dt));
    final thrash = (0.35 + fs.zoneVelocity.abs() * 1.4 + (fs.isRunning ? 0.5 : 0)).clamp(0.0, 1.5);
    f.fightPose(hook.position, fs.pull, thrash);
    _trackDepth();
    if (_rng.nextDouble() < dt * (4 + thrash * 6)) fx.bubbles(f.position, 2);

    _fightFeedback(fs, dt);

    switch (event) {
      case FightEvent.started:
        Haptics.medium();
      case FightEvent.run:
        _shake = 9;
        Haptics.heavy();
        fx.bubbles(f.position, 12);
        audio.play(Sfx.strain, volume: 0.7);
        showBanner('تسحب بقوة! ⚡', tone: BannerTone.info, seconds: 0.9);
      case FightEvent.won:
        _winFight(fs, f);
      case FightEvent.snapped:
        _loseFight(fs, f);
      case FightEvent.none:
        break;
    }
  }

  /// اهتزاز متصاعد مع اقتراب السمكة ومع خطر الانقطاع، وطقطقة البكرة أثناء الشد.
  void _fightFeedback(FightSession fs, double dt) {
    final intensity = (0.15 + 0.4 * fs.progress + 0.5 * fs.dangerFraction + (fs.isRunning ? 0.35 : 0)).clamp(0.0, 1.0);
    _hapticTimer -= dt;
    if (_hapticTimer <= 0) {
      _hapticTimer = 0.42 - 0.3 * intensity;
      Haptics.pulse(intensity);
    }
    if (fs.holding && fs.velocity > 0.05) {
      _reelTimer -= dt;
      if (_reelTimer <= 0) {
        _reelTimer = 0.11 - 0.05 * fs.indicator;
        audio.play(Sfx.reel, volume: 0.25 + 0.35 * fs.indicator);
      }
    }
    _strainCooldown -= dt;
    if (fs.dangerFraction > 0.55 && _strainCooldown <= 0) {
      _strainCooldown = 0.7;
      audio.play(Sfx.strain, volume: 0.4 + 0.5 * fs.dangerFraction);
    }
  }

  void _winFight(FightSession fs, FishComponent f) {
    final c = _fightCatch!;
    f.hookOn(hooked.length, c);
    hooked.add(f);
    _catches.add(c);
    _fightLog.add(true);
    caughtCount.value = hooked.length;
    fightOutcome.value = FightOutcome(won: true, fish: c);
    _outcomeTimer = 1.1;
    _slowMo = 0.25;
    _shake = 10;
    fx.catchBurst(hook.position, c.species.rarity.color);
    fx.catchBurst(hook.position, const Color(0xFFFFFFFF));
    fx.bubbles(hook.position, 18);
    audio.play(Sfx.pop);
    audio.play(Sfx.fanfare, volume: 0.6);
    Haptics.heavy();
    banner.value = null;
  }

  void _loseFight(FightSession fs, FishComponent f) {
    final c = _fightCatch!;
    // TODO(المرحلة 7): زر "أنقذ السمكة" بإعلان اختياري يعيد الصراع من 60%.
    _lost.add(c);
    _fightLog.add(false);
    f.escape(fs.pull);
    fightOutcome.value = FightOutcome(won: false, fish: c);
    _outcomeTimer = 2.0;
    lineSnapFx = 1;
    _shake = 18;
    hook.flash();
    fx.sparks(hook.position);
    fx.bubbles(hook.position, 14);
    audio.play(Sfx.snap);
    Haptics.heavy();
    _pendingHaptic = 0.14; // "طق-طق" مزدوجة
    banner.value = null;
  }

  void _endFight() {
    _clearFight();
    // متابعة الصعود والتقاط الأسماك كالمعتاد
    _setPhase(CastPhase.ascending);
  }

  void _clearFight() {
    if (overlays.isActive('fight')) overlays.remove('fight');
    fightSession.value = null;
    fightOutcome.value = null;
    _fightFish = null;
    _fightCatch = null;
    _pendingHaptic = -1;
  }

  // =====================================================================
  //                              التحديث
  // =====================================================================

  @override
  void update(double dt) {
    // حماية من القفزات عند تأخر إطار (جوالات ضعيفة)
    dt = math.min(dt, 1 / 30);
    // أول إطار: المكونات لم تُركّب بعد
    if (!hook.isMounted || !boat.isMounted) {
      super.update(dt);
      return;
    }
    if (_slowMo > 0) {
      _slowMo -= dt;
      dt *= config.catchSlowMoScale;
    }
    _phaseTime += dt;
    _time += dt;
    if (lineSnapFx > 0) lineSnapFx = math.max(0, lineSnapFx - dt * 1.6);

    if (_bannerTimer > 0) {
      _bannerTimer -= dt;
      if (_bannerTimer <= 0) banner.value = null;
    }

    switch (phase.value) {
      case CastPhase.aiming:
      case CastPhase.results:
        hook.dangleFrom(boat.rodTip, _phaseTime);
      case CastPhase.flying:
        _updateFlying();
      case CastPhase.descending:
        _updateDescent(dt);
      case CastPhase.turning:
        hook.steer(dt, size.x, config.steerSharpness);
        if (_phaseTime >= config.turnPauseSeconds) _setPhase(CastPhase.ascending);
      case CastPhase.ascending:
        _updateAscent(dt);
      case CastPhase.fighting:
        _updateFight(dt);
      case CastPhase.surfacing:
        hook.reelTowards(boat.rodTip, dt);
        if (_finishTimer > 0) {
          _finishTimer -= dt;
          if (_finishTimer <= 0) _finishCast();
        }
    }

    _updateCamera(dt);
    super.update(dt);
  }

  void _updateFlying() {
    final t = (_phaseTime / config.castFlightSeconds).clamp(0.0, 1.0);
    final arc = 70 + (_flyFrom.x - _flyTo.x).abs() * 0.25;
    hook.x = _flyFrom.x + (_flyTo.x - _flyFrom.x) * t;
    hook.y = _flyFrom.y + (_flyTo.y - _flyFrom.y) * (t * t) - arc * 4 * t * (1 - t);
    if (t >= 1) _enterWater();
  }

  void _updateDescent(double dt) {
    _descendSpeed = math.min(config.descendMaxSpeed, _descendSpeed + config.descendAccel * dt);
    final targetY = _targetDepth * ppm;
    hook.y = math.min(targetY, hook.y + _descendSpeed * ppm * dt);
    hook.steer(dt, size.x, config.steerSharpness);
    fx.trail(hook.position, dt);
    _trackDepth();

    final r = config.hookRadius * 0.8;
    for (final o in obstacles) {
      if (o.hits(hook.position, r)) {
        _hitObstacle(o);
        return;
      }
    }
    if (hook.y >= targetY) _reachBottom();
  }

  void _updateAscent(double dt) {
    final ramp = math.min(1.0, 0.35 + _phaseTime * 1.5);
    final speed = (isFull ? config.ascendFullSpeed : config.ascendSpeed) * ramp;
    hook.y -= speed * ppm * dt;
    hook.steer(dt, size.x, config.steerSharpness);
    _trackDepth();

    if (!isFull) {
      final reach = config.hookRadius + config.catchForgiveness;
      for (final f in fishes) {
        if (!f.isSwimming) continue;
        final rr = reach + f.radius;
        if (f.position.distanceToSquared(hook.position) < rr * rr) {
          if (f.needsFight) {
            _startFight(f);
            return;
          }
          _catch(f);
          if (isFull) break;
        }
      }
    }
    if (hook.y <= 0) _surface();
  }

  void _trackDepth() {
    final d = hookDepth;
    _maxDepth = math.max(_maxDepth, d);
    final m = d.floor();
    if (m != depthMeters.value) depthMeters.value = m;
    // تكة خفيفة كل 10 أمتار أثناء النزول
    final tick = m ~/ 10;
    if (phase.value == CastPhase.descending && tick > _lastDepthTick) {
      _lastDepthTick = tick;
      Haptics.tick();
    }
  }

  void _updateCamera(double dt) {
    final h = size.y;
    double target;
    double k;
    switch (phase.value) {
      case CastPhase.aiming:
      case CastPhase.results:
      case CastPhase.flying:
        target = _aimCamTop;
        k = 5;
      case CastPhase.descending:
        // الصنارة في الثلث العلوي لرؤية العوائق القادمة من الأسفل
        target = hook.y - h * 0.33;
        k = 11;
      case CastPhase.turning:
        target = hook.y - h * 0.5;
        k = 5;
      case CastPhase.ascending:
        // الصنارة في الأسفل لرؤية الأسماك القادمة من الأعلى
        target = hook.y - h * 0.64;
        k = 6;
      case CastPhase.fighting:
        // السمكة في منتصف الشاشة تقريباً، فوق لوحة الصراع
        target = hook.y - h * 0.36;
        k = 4;
      case CastPhase.surfacing:
        target = -h * 0.62;
        k = 4;
    }
    final prev = camTop;
    camTop += (target - camTop) * (1 - math.exp(-k * dt));
    camVelocity = dt > 0 ? (camTop - prev) / dt : 0;
    _shake *= math.exp(-9 * dt);
    if (_shake < 0.3) _shake = 0;
    _applyCamera();
  }

  final Vector2 _camPos = Vector2.zero();

  void _applyCamera() {
    final sx = _shake == 0 ? 0.0 : (_rng.nextDouble() - 0.5) * _shake;
    final sy = _shake == 0 ? 0.0 : (_rng.nextDouble() - 0.5) * _shake;
    // ملاحظة: في Flame الـ getter يُرجع نسخة جديدة (-transform.offset)، فتعديلها بـ setValues لا يحرّك الكاميرا.
    // يجب استخدام الـ setter حتى تتحرك الكاميرا فعلاً.
    _camPos.setValues(sx, camTop + sy);
    camera.viewfinder.position = _camPos;
  }

  /// موضع عداد الريالات في الشاشة (أعلى اليمين) محوّلاً لإحداثيات العالم.
  double get coinTargetX => size.x - 56;
  double get coinTargetY => camTop + 44;

  @override
  void onRemove() {
    audio.dispose();
    super.onRemove();
  }
}
