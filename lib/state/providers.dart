import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/game_config.dart';
import '../data/cast_result.dart';
import '../data/fish_species.dart';
import '../data/save_repository.dart';
import '../data/stage.dart';
import '../data/upgrades.dart';
import 'player_state.dart';

/// الإعدادات — تُستبدل لاحقاً بنسخة من Remote Config.
final gameConfigProvider = Provider<GameConfig>((ref) => const GameConfig());

/// يُحقن في main() بعد فتح Hive.
final saveRepositoryProvider = Provider<SaveRepository>(
  (ref) => throw UnimplementedError('saveRepositoryProvider must be overridden in main()'),
);

/// يُحقن في main() بعد قراءة ملف JSON.
final fishCatalogProvider = Provider<FishCatalog>((ref) => throw UnimplementedError('fishCatalogProvider must be overridden in main()'));

/// يُحقن في main() بعد قراءة stages.json (الافتراضي: مرحلة مفتوحة واحدة للاختبارات).
final stageCatalogProvider = Provider<StageCatalog>((ref) => StageCatalog.single);

final playerProvider = NotifierProvider<PlayerNotifier, PlayerState>(PlayerNotifier.new);

/// المرحلة الحالية للاعب.
final currentStageProvider = Provider<Stage>((ref) {
  final id = ref.watch(playerProvider.select((p) => p.currentStage));
  return ref.watch(stageCatalogProvider).byId(id);
});

class PlayerNotifier extends Notifier<PlayerState> {
  @override
  PlayerState build() => ref.read(saveRepositoryProvider).loadPlayer();

  StageCatalog get _stages => ref.read(stageCatalogProvider);

  /// تسجيل نتيجة رمية: يحدد الأسماك الجديدة، يضيف الريالات، يحدّث تقدم المرحلة، ويحفظ.
  CastResult applyCastResult(CastResult result) {
    final counts = Map<String, int>.from(state.catchCounts);
    final heaviest = Map<String, double>.from(state.heaviest);
    for (final f in result.fish) {
      final id = f.species.id;
      f.isNew = !counts.containsKey(id);
      counts[id] = (counts[id] ?? 0) + 1;
      heaviest[id] = math.max(heaviest[id] ?? 0, f.weightKg);
    }
    // سلسلة الصراعات: الفوز يزيدها والانقطاع يصفّرها
    var streak = state.fightStreak, best = state.bestFightStreak;
    for (final won in result.fightLog) {
      streak = won ? streak + 1 : 0;
      best = math.max(best, streak);
    }

    // تقدم المرحلة وأهدافها
    final stage = _stages.byId(result.stageId);
    final before = state.progressIn(stage.id);
    final after = StageProgress(
      catches: before.catches + result.fish.length,
      coins: before.coins + result.totalValue,
      bestDepth: math.max(before.bestDepth, result.maxDepth),
      fightsWon: before.fightsWon + result.fightsWon,
      species: {...before.species, for (final f in result.fish) f.species.id},
    );
    result.newGoals = [
      for (var i = 0; i < stage.goals.length; i++)
        if (!stage.goals[i].isDone(before) && stage.goals[i].isDone(after)) i,
    ];
    var completed = state.completedStages;
    if (stage.goals.isNotEmpty && !completed.contains(stage.id) && stage.isComplete(after)) {
      completed = {...completed, stage.id};
      result.completedStage = true;
    }

    state = state.copyWith(
      fightsWon: state.fightsWon + result.fightsWon,
      fightsLost: state.fightsLost + result.lost.length,
      fightStreak: streak,
      bestFightStreak: best,
      coins: state.coins + result.totalValue,
      catchCounts: counts,
      heaviest: heaviest,
      totalCasts: state.totalCasts + 1,
      bestDepth: math.max(state.bestDepth, result.maxDepth),
      stageProgress: {...state.stageProgress, stage.id: after},
      completedStages: completed,
    );
    _persist();
    return result;
  }

  /// شراء المستوى التالي من ترقية. يُرجع false إذا لم يكفِ الرصيد أو وصلت للحد الأقصى.
  bool buyUpgrade(Upgrade u) {
    final cost = u.nextCost(state);
    if (cost == null || state.coins < cost) return false;
    state = u.withLevel(state, u.levelOf(state) + 1).copyWith(coins: state.coins - cost);
    _persist();
    return true;
  }

  /// الانتقال إلى مرحلة مفتوحة. يُرجع false إذا كانت مقفلة.
  bool selectStage(String id) {
    final stage = _stages.byId(id);
    if (stage.id != id || !_stages.isUnlocked(stage, state.completedStages)) return false;
    state = state.copyWith(currentStage: id);
    _persist();
    return true;
  }

  void markHelpSeen() {
    if (state.seenHelp) return;
    state = state.copyWith(seenHelp: true);
    _persist();
  }

  void toggleSound() {
    state = state.copyWith(soundOn: !state.soundOn);
    _persist();
  }

  void _persist() => ref.read(saveRepositoryProvider).savePlayer(state);
}
