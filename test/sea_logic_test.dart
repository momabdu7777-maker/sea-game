import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sea_hunter/config/game_config.dart';
import 'package:sea_hunter/data/cast_result.dart';
import 'package:sea_hunter/data/fish_species.dart';
import 'package:sea_hunter/data/rarity.dart';
import 'package:sea_hunter/game/systems/sea_spawner.dart';
import 'package:sea_hunter/state/player_state.dart';

void main() {
  final catalog = FishCatalog.parse(File('assets/data/fish.json').readAsStringSync());
  const config = GameConfig();

  test('ملف الأسماك صالح: 20 نوعاً بمعرفات فريدة وقيم منطقية', () {
    expect(catalog.species.length, 20);
    expect(catalog.species.map((s) => s.id).toSet().length, 20);
    for (final s in catalog.species) {
      expect(s.minDepth, lessThan(s.maxDepth), reason: s.id);
      expect(s.minWeight, lessThan(s.maxWeight), reason: s.id);
      expect(s.minDepth, lessThan(config.lineLengthForLevel(8)), reason: '${s.id} يجب أن يكون في متناول أطول خيط');
      expect(s.regions, isNotEmpty, reason: s.id);
    }
    // اللاعب الجديد (خيط 100 م) يجد في المكلا أنواعاً تكفي لهدف «اكتشف 6 أنواع»
    final starter = catalog.species.where((s) => s.regions.contains('mukalla') && s.minDepth < config.baseLineLength);
    expect(starter.length, greaterThanOrEqualTo(8));
    expect(catalog.byId('hamour')!.rarity, Rarity.epic);
    expect(catalog.byId('whaleshark')!.rarity, Rarity.legendary);
    for (final s in catalog.species.where((s) => s.bigFight)) {
      expect(s.schoolMax, 1, reason: '${s.id}: الأسماك الكبيرة تظهر منفردة');
      expect(s.fightPower, greaterThan(0), reason: s.id);
    }
  });

  test('نفس البذرة = نفس البحر (أساس تحدي صديق)', () {
    final sp = SeaSpawner(config, catalog);
    final a = sp.plan(seed: 42, maxDepth: 100, width: 400);
    final b = sp.plan(seed: 42, maxDepth: 100, width: 400);
    expect(a.fish.length, b.fish.length);
    for (var i = 0; i < a.fish.length; i++) {
      expect(a.fish[i].species.id, b.fish[i].species.id);
      expect(a.fish[i].x, b.fish[i].x);
      expect(a.fish[i].weightKg, b.fish[i].weightKg);
    }
    expect(a.obstacles.length, b.obstacles.length);
  });

  test('الأسماك في أعماقها، والعوائق لا تغلق الممر', () {
    final sp = SeaSpawner(config, catalog);
    for (var seed = 0; seed < 200; seed++) {
      final plan = sp.plan(seed: seed, maxDepth: 100, width: 400);
      expect(plan.fish, isNotEmpty);
      for (final f in plan.fish) {
        expect(f.depth, greaterThanOrEqualTo(f.species.minDepth - 0.01));
        expect(f.depth, lessThanOrEqualTo(f.species.maxDepth + 3));
        expect(f.weightKg, inInclusiveRange(f.species.minWeight, f.species.maxWeight));
      }
      for (final o in plan.obstacles) {
        expect(o.depth, greaterThanOrEqualTo(config.obstacleStartDepth));
        if (o.kind != ObstacleKind.jellyfish) expect(o.width, lessThan(400 * 0.6));
      }
    }
  });

  test('السعر يتصاعد مع الندرة والوزن', () {
    final sardine = catalog.byId('sardine')!;
    final hamour = catalog.byId('hamour')!;
    expect(SeaSpawner.priceOf(config, hamour, hamour.minWeight), greaterThan(SeaSpawner.priceOf(config, sardine, sardine.maxWeight)));
    expect(SeaSpawner.priceOf(config, hamour, hamour.maxWeight), greaterThan(SeaSpawner.priceOf(config, hamour, hamour.minWeight)));
    final rng = math.Random(1);
    final weights = List.generate(2000, (_) => SeaSpawner.rollWeight(rng, hamour));
    final mid = (hamour.minWeight + hamour.maxWeight) / 2;
    expect(weights.where((w) => w < mid).length, greaterThan(1200), reason: 'الأسماك الثقيلة يجب أن تكون أندر');
  });

  test('حفظ حالة اللاعب واسترجاعها', () {
    final s = PlayerState.initial().copyWith(coins: 120, catchCounts: {'sardine': 3}, heaviest: {'sardine': 0.15}, bestDepth: 64.5);
    final back = PlayerState.fromMap(s.copyWith(fightsWon: 4, fightsLost: 2, fightStreak: 3, lineStrengthLevel: 1).toMap());
    expect(back.fightsWon, 4);
    expect(back.fightsLost, 2);
    expect(back.fightStreak, 3);
    expect(back.lineStrengthLevel, 1);
    // حفظ قديم من المرحلة 1 (بدون حقول الصراع) يُقرأ بقيم صفرية
    final old = PlayerState.fromMap({'coins': 5});
    expect(old.fightsWon, 0);
    expect(old.totalFights, 0);
    expect(back.coins, 120);
    expect(back.catchCounts['sardine'], 3);
    expect(back.hasDiscovered('sardine'), isTrue);
    expect(back.bestDepth, 64.5);
  });

  test('مجموع قيمة الرمية', () {
    final s = catalog.byId('kanad')!;
    final r = CastResult(
      fish: [
        CaughtFish(species: s, weightKg: 3, value: 100),
        CaughtFish(species: s, weightKg: 2, value: 50),
      ],
      maxDepth: 40,
      end: DescentEnd.reachedDepth,
      seed: 1,
    );
    expect(r.totalValue, 150);
  });

  test('الأسماك الضائعة لا تُحسب في المجموع، وسجل الصراعات', () {
    final tuna = catalog.byId('tuna')!;
    final r = CastResult(
      fish: [CaughtFish(species: tuna, weightKg: 30, value: 500, fromFight: true)],
      lost: [CaughtFish(species: tuna, weightKg: 50, value: 700, fromFight: true)],
      fightLog: [false, true],
      maxDepth: 80,
      end: DescentEnd.reachedDepth,
      seed: 2,
    );
    expect(r.totalValue, 500);
    expect(r.lostValue, 700);
    expect(r.fightsWon, 1);
  });
}
