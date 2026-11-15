import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/game_config.dart';
import '../data/cast_result.dart';
import '../data/fish_species.dart';
import '../data/save_repository.dart';
import 'player_state.dart';

/// الإعدادات — تُستبدل لاحقاً بنسخة من Remote Config.
final gameConfigProvider = Provider<GameConfig>((ref) => const GameConfig());

/// يُحقن في main() بعد فتح Hive.
final saveRepositoryProvider = Provider<SaveRepository>(
  (ref) => throw UnimplementedError('saveRepositoryProvider must be overridden in main()'),
);

/// يُحقن في main() بعد قراءة ملف JSON.
final fishCatalogProvider = Provider<FishCatalog>((ref) => throw UnimplementedError('fishCatalogProvider must be overridden in main()'));

final playerProvider = NotifierProvider<PlayerNotifier, PlayerState>(PlayerNotifier.new);

class PlayerNotifier extends Notifier<PlayerState> {
  @override
  PlayerState build() => ref.read(saveRepositoryProvider).loadPlayer();

  /// تسجيل نتيجة رمية: يحدد الأسماك الجديدة، يضيف الريالات (بيع تلقائي مؤقت
  /// حتى يأتي الحراج في المرحلة 3)، ويحفظ.
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
    );
    _persist();
    return result;
  }

  void toggleSound() {
    state = state.copyWith(soundOn: !state.soundOn);
    _persist();
  }

  void _persist() => ref.read(saveRepositoryProvider).savePlayer(state);
}
