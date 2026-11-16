import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sea_hunter/config/game_config.dart';
import 'package:sea_hunter/data/cast_result.dart';
import 'package:sea_hunter/data/fish_species.dart';
import 'package:sea_hunter/data/save_repository.dart';
import 'package:sea_hunter/data/stage.dart';
import 'package:sea_hunter/data/upgrades.dart';
import 'package:sea_hunter/game/systems/sea_spawner.dart';
import 'package:sea_hunter/state/player_state.dart';
import 'package:sea_hunter/state/providers.dart';

/// اختبارات المراحل والتطوير: صحة البيانات، شراء الترقيات، تقدم الأهداف وفتح المراحل، والحفظ.
void main() {
  final fish = FishCatalog.parse(File('assets/data/fish.json').readAsStringSync());
  final stages = StageCatalog.parse(File('assets/data/stages.json').readAsStringSync());
  const config = GameConfig();
  final maxLine = config.lineLengthForLevel(Upgrade.line.maxLevel);

  ProviderContainer container({PlayerState? start}) {
    final save = SaveRepository.inMemory();
    if (start != null) save.savePlayer(start);
    final c = ProviderContainer(
      overrides: [
        saveRepositoryProvider.overrideWithValue(save),
        fishCatalogProvider.overrideWithValue(fish),
        stageCatalogProvider.overrideWithValue(stages),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  CastResult cast(String stageId, List<String> ids, {double depth = 30, List<bool> fights = const []}) => CastResult(
    fish: [for (final id in ids) CaughtFish(species: fish.byId(id)!, weightKg: 1, value: 10)],
    maxDepth: depth,
    end: DescentEnd.reachedDepth,
    seed: 1,
    fightLog: fights,
    stageId: stageId,
  );

  group('بيانات المراحل', () {
    test('4 مراحل بالترتيب، كل واحدة أعمق وأغلى من التي قبلها', () {
      expect(stages.stages.map((s) => s.id), ['mukalla', 'aden', 'socotra', 'indian']);
      for (var i = 1; i < stages.stages.length; i++) {
        expect(stages.stages[i].seabed, greaterThan(stages.stages[i - 1].seabed));
        expect(stages.stages[i].priceMultiplier, greaterThan(stages.stages[i - 1].priceMultiplier));
      }
    });

    test('في كل مرحلة أسماك على كل عمق من السطح حتى القاع', () {
      for (final st in stages.stages) {
        final pool = fish.species.where(st.hasFish).toList();
        for (var d = 2.0; d <= st.seabed; d += 5) {
          expect(pool.any((s) => s.livesAt(d)), isTrue, reason: '${st.name}: لا أسماك على عمق $d م');
        }
      }
    });

    test('كل الأهداف ممكنة: العمق أقل من القاع وأطول خيط، والأنواع المطلوبة موجودة في المرحلة', () {
      for (final st in stages.stages) {
        expect(st.goals, isNotEmpty);
        final pool = fish.species.where(st.hasFish).toList();
        for (final g in st.goals) {
          switch (g.type) {
            case GoalType.depth:
              expect(g.target, lessThanOrEqualTo(st.seabed), reason: st.name);
              expect(g.target, lessThanOrEqualTo(maxLine), reason: st.name);
            case GoalType.species:
              expect(g.target, lessThanOrEqualTo(pool.length), reason: st.name);
            case GoalType.catchSpecies:
              final s = fish.byId(g.speciesId!);
              expect(s, isNotNull, reason: g.speciesId);
              expect(st.hasFish(s!), isTrue, reason: '${s.name} ليست في ${st.name}');
              expect(s.minDepth, lessThan(st.seabed));
            case GoalType.fights:
              expect(pool.any((s) => s.bigFight), isTrue, reason: '${st.name} بلا أسماك صراع');
            case GoalType.catchCount:
            case GoalType.coins:
              break;
          }
        }
      }
    });

    test('مولّد البحر يلتزم بأسماك المرحلة', () {
      final spawner = SeaSpawner(config, fish);
      final indian = stages.byId('indian');
      for (var seed = 0; seed < 20; seed++) {
        final plan = spawner.plan(seed: seed, maxDepth: 300, width: 390, stage: indian);
        expect(plan.fish, isNotEmpty);
        expect(plan.fish.every((f) => indian.hasFish(f.species)), isTrue);
        expect(plan.fish.any((f) => f.depth > 150), isTrue, reason: 'الأعماق يجب ألا تكون فارغة');
        // العوائق الكثيفة تبقي مسافة كافية للتفادي
        final depths = [for (final o in plan.obstacles) o.depth]..sort();
        for (var i = 1; i < depths.length; i++) {
          expect(depths[i] - depths[i - 1], greaterThanOrEqualTo(5.5 * 0.7 - 1e-9));
        }
      }
    });

    test('صياغة العدد بالعربية', () {
      String fishCount(int n) => countAr(n, 'سمكة', 'سمكتين', 'أسماك', 'سمكة');
      expect(fishCount(1), 'سمكة واحدة');
      expect(fishCount(2), 'سمكتين');
      expect(fishCount(5), '5 أسماك');
      expect(fishCount(12), '12 سمكة');
      expect(stages.first.goals.first.label(fish), 'اصطد 12 سمكة');
      expect(stages.byId('indian').goals.last.label(fish), 'اصطد الحبار العملاق');
    });
  });

  group('التطوير', () {
    test('لا شراء بدون رصيد كافٍ، والشراء يخصم السعر ويرفع المستوى', () {
      final c = container();
      final n = c.read(playerProvider.notifier);
      expect(n.buyUpgrade(Upgrade.line), isFalse);
      n.applyCastResult(cast('mukalla', List.filled(10, 'sheri')));
      expect(c.read(playerProvider).coins, 100);
      expect(n.buyUpgrade(Upgrade.line), isTrue);
      expect(c.read(playerProvider).lineLevel, 1);
      expect(c.read(playerProvider).coins, 100 - Upgrade.line.costs[0]);
      expect(n.buyUpgrade(Upgrade.line), isFalse, reason: 'الرصيد لا يكفي للمستوى الثاني');
    });

    test('لا شراء بعد أقصى مستوى، والأسعار تتصاعد', () {
      final c = container(start: PlayerState.initial().copyWith(coins: 1000000));
      final n = c.read(playerProvider.notifier);
      for (final u in Upgrade.values) {
        for (var i = 1; i < u.costs.length; i++) {
          expect(u.costs[i], greaterThan(u.costs[i - 1]));
        }
        while (n.buyUpgrade(u)) {}
        expect(u.levelOf(c.read(playerProvider)), u.maxLevel);
        expect(u.isMaxed(c.read(playerProvider)), isTrue);
      }
      expect(config.lineLengthForLevel(c.read(playerProvider).lineLevel), 300);
    });
  });

  group('المراحل', () {
    test('المرحلة الثانية مقفلة حتى تكتمل أهداف الأولى، ثم تُفتح', () {
      final c = container();
      final n = c.read(playerProvider.notifier);
      expect(c.read(currentStageProvider).id, 'mukalla');
      expect(n.selectStage('aden'), isFalse);

      // 6 أنواع مختلفة + 12 سمكة + عمق 70 م
      final r1 = n.applyCastResult(cast('mukalla', ['sardine', 'anchovy', 'thamad', 'crab', 'squid', 'sheri'], depth: 50));
      expect(r1.newGoals, [1], reason: 'تحقق هدف الأنواع فقط');
      expect(r1.completedStage, isFalse);
      final r2 = n.applyCastResult(cast('mukalla', List.filled(6, 'sardine'), depth: 72));
      expect(r2.newGoals, containsAll([0, 2]));
      expect(r2.completedStage, isTrue);
      expect(c.read(playerProvider).completedStages, contains('mukalla'));

      // إكمالها مرة أخرى لا يحتفل من جديد
      expect(n.applyCastResult(cast('mukalla', ['sardine'])).completedStage, isFalse);

      expect(n.selectStage('aden'), isTrue);
      expect(c.read(currentStageProvider).id, 'aden');
      expect(n.selectStage('socotra'), isFalse);
      // الرجوع لمرحلة سابقة مسموح
      expect(n.selectStage('mukalla'), isTrue);
    });

    test('التقدم يُحسب لكل مرحلة على حدة', () {
      final c = container(start: PlayerState.initial().copyWith(completedStages: {'mukalla'}, currentStage: 'aden'));
      final n = c.read(playerProvider.notifier);
      n.applyCastResult(cast('aden', ['trevally', 'barracuda'], depth: 150, fights: [true, false, true]));
      final p = c.read(playerProvider);
      expect(p.progressIn('aden').catches, 2);
      expect(p.progressIn('aden').fightsWon, 2);
      expect(p.progressIn('aden').bestDepth, 150);
      expect(p.progressIn('mukalla').catches, 0);
    });
  });

  test('حفظ المراحل والشرح واسترجاعها، والحفظ القديم يبقى صالحاً', () {
    final s = PlayerState.initial().copyWith(
      currentStage: 'aden',
      completedStages: {'mukalla'},
      seenHelp: true,
      stageProgress: {'mukalla': const StageProgress(catches: 12, coins: 300, bestDepth: 71.5, fightsWon: 1, species: {'sardine', 'crab'})},
    );
    final back = PlayerState.fromMap(s.toMap());
    expect(back.currentStage, 'aden');
    expect(back.completedStages, {'mukalla'});
    expect(back.seenHelp, isTrue);
    expect(back.progressIn('mukalla').catches, 12);
    expect(back.progressIn('mukalla').species, {'sardine', 'crab'});
    expect(back.progressIn('mukalla').bestDepth, 71.5);

    // حفظ من الإصدار 1.1: لاعب جديد يرى الشرح، ولاعب قديم لا يُزعج به
    expect(PlayerState.fromMap({'coins': 0}).seenHelp, isFalse);
    expect(PlayerState.fromMap({'coins': 40, 'totalCasts': 7}).seenHelp, isTrue);
    expect(PlayerState.fromMap({'coins': 40}).currentStage, '');
    expect(stages.byId(PlayerState.fromMap({'coins': 40}).currentStage).id, 'mukalla');
  });
}
