import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sea_hunter/config/game_config.dart';
import 'package:sea_hunter/data/fish_species.dart';
import 'package:sea_hunter/game/systems/fight_session.dart';

/// نتيجة محاكاة صراع واحد.
class _Sim {
  _Sim(this.won, this.seconds);
  final bool won;
  final double seconds;
}

/// "لاعب آلي" بزمن رد فعل بشري: يرى الحالة متأخرة [reaction] ثانية ويخطئ أحياناً.
/// [skill] = 0 لاعب مبتدئ جداً، 1 = لاعب ماهر.
_Sim _play(FightTuning t, int seed, {double skill = 0.7, double reaction = 0.16}) {
  final f = FightSession(t, seed: seed);
  final rng = math.Random(seed * 31 + 7);
  const dt = 1 / 60;
  final history = <(double, double, double)>[]; // (indicator, velocity, zoneCenter)
  final delay = (reaction / dt).round();
  var hold = false;
  var decisionTimer = 0.0;
  while (!f.isOver && f.time < 60) {
    history.add((f.indicator, f.velocity, f.zoneCenter));
    decisionTimer -= dt;
    if (decisionTimer <= 0) {
      // البشر يقررون كل ~50-90 ملّي ثانية وليس كل إطار
      decisionTimer = 0.05 + rng.nextDouble() * 0.04;
      final seen = history[math.max(0, history.length - 1 - delay)];
      final lookAhead = 0.1 + 0.25 * skill;
      final predicted = seen.$1 + seen.$2 * lookAhead;
      final aim = seen.$3 + (rng.nextDouble() - 0.5) * t.zoneWidth * (1.4 - skill);
      hold = predicted < aim;
      if (rng.nextDouble() < 0.06 * (1 - skill)) hold = !hold; // سهو
    }
    f.update(dt, holding: hold);
  }
  return _Sim(f.status == FightStatus.won, f.time);
}

void main() {
  final catalog = FishCatalog.parse(File('assets/data/fish.json').readAsStringSync());
  const config = GameConfig();
  final bigFish = catalog.species.where((s) => s.bigFight).toList();

  FightTuning tuningFor(FishSpecies s, {double weightT = 0.5, int level = 0}) =>
      FightTuning.forFish(config, s, s.minWeight + (s.maxWeight - s.minWeight) * weightT, lineStrengthLevel: level);

  ({double winRate, double avgSeconds}) stats(FightTuning t, {double skill = 0.7, int n = 400}) {
    var wins = 0;
    var secs = 0.0;
    for (var i = 0; i < n; i++) {
      final r = _play(t, i, skill: skill);
      if (r.won) {
        wins++;
        secs += r.seconds;
      }
    }
    return (winRate: wins / n, avgSeconds: wins == 0 ? 0 : secs / wins);
  }

  test('الأسماك الكبيرة معرّفة في JSON', () {
    expect(bigFish.map((s) => s.id), containsAll(['hamour', 'tuna', 'shark', 'whaleshark']));
    final hamour = catalog.byId('hamour')!;
    expect(hamour.triggersFight(5), isFalse, reason: 'الهامور الصغير يُصطاد عادياً');
    expect(hamour.triggersFight(12), isTrue, reason: 'الهامور الضخم يُطلق صراعاً');
    expect(catalog.byId('sardine')!.triggersFight(0.1), isFalse);
  });

  test('نفس البذرة = نفس الصراع', () {
    final t = tuningFor(catalog.byId('tuna')!);
    final a = FightSession(t, seed: 99), b = FightSession(t, seed: 99);
    for (var i = 0; i < 600; i++) {
      final hold = (i ~/ 20).isEven;
      a.update(1 / 60, holding: hold);
      b.update(1 / 60, holding: hold);
    }
    expect(a.zoneCenter, b.zoneCenter);
    expect(a.progress, b.progress);
    expect(a.status, b.status);
  });

  test('عدم اللمس أو الضغط المستمر = انقطاع الخيط دائماً', () {
    for (final s in bigFish) {
      final t = tuningFor(s);
      for (final hold in [false, true]) {
        final f = FightSession(t, seed: 3);
        while (!f.isOver && f.time < 30) {
          f.update(1 / 60, holding: hold);
        }
        expect(f.status, FightStatus.snapped, reason: '${s.id} hold=$hold');
        expect(f.time, lessThan(12), reason: 'الخسارة يجب ألا تطول');
      }
    }
  });

  test('مهلة البداية لا خسارة فيها', () {
    final f = FightSession(tuningFor(catalog.byId('whaleshark')!), seed: 1);
    while (f.time < config.fightIntroSeconds - 0.05) {
      f.update(1 / 60, holding: false);
    }
    expect(f.danger, 0);
    expect(f.progress, config.fightStartProgress);
    expect(f.isOver, isFalse);
  });

  test('التوازن: الأسهل يُكسب غالباً، الأسطوري تحدٍّ، والمدة معقولة', () {
    final results = <String, ({double winRate, double avgSeconds})>{};
    for (final s in bigFish) {
      final r = stats(tuningFor(s));
      results[s.id] = r;
      // ignore: avoid_print
      print(
        '${s.id.padRight(11)} power=${tuningFor(s).power.toStringAsFixed(2)} zone=${tuningFor(s).zoneWidth.toStringAsFixed(2)}  '
        'win=${(r.winRate * 100).toStringAsFixed(0)}%  avg=${r.avgSeconds.toStringAsFixed(1)}s  '
        'novice=${(stats(tuningFor(s), skill: 0.25, n: 200).winRate * 100).toStringAsFixed(0)}%',
      );
      expect(r.avgSeconds, inInclusiveRange(4, 16), reason: '${s.id}: الصراع يجب أن يكون قصيراً وممتعاً');
    }
    expect(results['hamour']!.winRate, greaterThan(0.9));
    expect(results['tuna']!.winRate, inInclusiveRange(0.7, 0.98));
    expect(results['shark']!.winRate, inInclusiveRange(0.5, 0.92));
    expect(results['whaleshark']!.winRate, inInclusiveRange(0.3, 0.75));
    expect(results['shark']!.winRate, greaterThan(results['whaleshark']!.winRate));
    expect(results['hamour']!.winRate, greaterThan(results['whaleshark']!.winRate));
  });

  test('ترقية قوة الخيط تسهّل الصراع فعلاً', () {
    final s = catalog.byId('shark')!;
    final base = stats(tuningFor(s), n: 300).winRate;
    final upgraded = stats(tuningFor(s, level: 5), n: 300).winRate;
    expect(tuningFor(s, level: 5).zoneWidth, greaterThan(tuningFor(s).zoneWidth));
    expect(upgraded, greaterThan(base + 0.08));
  });
}
