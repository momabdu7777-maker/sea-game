import 'dart:math' as math;

import '../../config/game_config.dart';
import '../../data/fish_species.dart';

/// أنواع العوائق.
enum ObstacleKind {
  jellyfish('قنديل البحر', 8, 5),
  rock('صخرة', 18, 3),
  net('شبكة قديمة', 35, 2);

  const ObstacleKind(this.arabicName, this.minDepth, this.weight);

  final String arabicName;
  final double minDepth;
  final double weight;
}

/// بيانات ظهور سمكة (قبل إنشاء المكوّن).
class FishSpawn {
  FishSpawn({required this.species, required this.x, required this.depth, required this.dir, required this.weightKg, required this.seed});

  final FishSpecies species;
  final double x;
  final double depth;
  final int dir;
  final double weightKg;
  final int seed;
}

/// بيانات ظهور عائق.
class ObstacleSpawn {
  ObstacleSpawn({
    required this.kind,
    required this.x,
    required this.depth,
    required this.width,
    required this.height,
    required this.fromLeft,
    required this.seed,
  });

  final ObstacleKind kind;
  final double x;
  final double depth;
  final double width;
  final double height;
  final bool fromLeft;
  final int seed;
}

class SpawnPlan {
  SpawnPlan(this.fish, this.obstacles);

  final List<FishSpawn> fish;
  final List<ObstacleSpawn> obstacles;
}

/// يولّد توزيع الأسماك والعوائق لرمية واحدة.
///
/// نفس [seed] + نفس العرض = نفس البحر تماماً، وهذا أساس "تحدي صديق" لاحقاً.
class SeaSpawner {
  SeaSpawner(this.config, this.catalog);

  final GameConfig config;
  final FishCatalog catalog;

  SpawnPlan plan({required int seed, required double maxDepth, required double width}) {
    final rng = math.Random(seed);
    return SpawnPlan(_fish(rng, maxDepth, width), _obstacles(rng, maxDepth, width));
  }

  /// وزن عشوائي يميل للأوزان الأخف (الكبيرة أندر).
  static double rollWeight(math.Random rng, FishSpecies s) {
    final t = math.pow(rng.nextDouble(), 1.7).toDouble();
    return s.minWeight + (s.maxWeight - s.minWeight) * t;
  }

  /// السعر = الأساسي × مضاعف الندرة × عامل الوزن (0.7..1.3).
  /// (مضاعف الطزاجة يُضاف مع الحراج في المرحلة 3)
  static int priceOf(GameConfig config, FishSpecies s, double weightKg) {
    final range = s.maxWeight - s.minWeight;
    final norm = range <= 0 ? 0.5 : ((weightKg - s.minWeight) / range).clamp(0.0, 1.0);
    final mult = config.rarityPriceMultipliers[s.rarity] ?? 1;
    return math.max(1, (s.basePrice * mult * (0.7 + 0.6 * norm)).round());
  }

  List<FishSpawn> _fish(math.Random rng, double maxDepth, double width) {
    final out = <FishSpawn>[];
    final avgGap = 1 / config.fishGroupsPerMeter;
    var d = 2.0;
    while (true) {
      d += avgGap * (0.45 + rng.nextDouble() * 1.1);
      if (d > maxDepth + 4) break;
      final candidates = catalog.species.where((s) => s.livesAt(d)).toList();
      if (candidates.isEmpty) continue;
      final s = _pickWeighted(rng, candidates);
      final count = s.schoolMin + rng.nextInt(math.max(1, s.schoolMax - s.schoolMin + 1));
      final dir = rng.nextBool() ? 1 : -1;
      final baseX = 30 + rng.nextDouble() * (width - 60);
      for (var i = 0; i < count; i++) {
        // أفراد السرب متقاربون خلف القائد
        final dx = s.movement == FishMovement.school ? -dir * i * s.sizePx * 0.9 : (rng.nextDouble() - 0.5) * width * 0.6;
        final dy = s.movement == FishMovement.school ? (rng.nextDouble() - 0.5) * 1.6 : (rng.nextDouble() - 0.5) * 3;
        out.add(
          FishSpawn(
            species: s,
            x: (baseX + dx).clamp(10, width - 10).toDouble(),
            depth: math.max(s.minDepth, d + dy),
            dir: dir,
            weightKg: rollWeight(rng, s),
            seed: rng.nextInt(1 << 30),
          ),
        );
      }
    }
    return out;
  }

  FishSpecies _pickWeighted(math.Random rng, List<FishSpecies> list) {
    double w(FishSpecies s) => config.rarityWeights[s.rarity] ?? 1;
    final total = list.fold<double>(0, (a, s) => a + w(s));
    var r = rng.nextDouble() * total;
    for (final s in list) {
      r -= w(s);
      if (r <= 0) return s;
    }
    return list.last;
  }

  List<ObstacleSpawn> _obstacles(math.Random rng, double maxDepth, double width) {
    final out = <ObstacleSpawn>[];
    var d = config.obstacleStartDepth;
    while (true) {
      final ramp = (d / config.obstacleRampDepth).clamp(0.0, 1.0);
      final spacing = config.obstacleSpacingShallow + (config.obstacleSpacingDeep - config.obstacleSpacingShallow) * ramp;
      d += spacing * (0.7 + rng.nextDouble() * 0.6);
      if (d > maxDepth) break;
      final kinds = ObstacleKind.values.where((k) => d >= k.minDepth).toList();
      final total = kinds.fold<double>(0, (a, k) => a + k.weight);
      var r = rng.nextDouble() * total;
      var kind = kinds.first;
      for (final k in kinds) {
        r -= k.weight;
        if (r <= 0) {
          kind = k;
          break;
        }
      }
      final fromLeft = rng.nextBool();
      switch (kind) {
        case ObstacleKind.jellyfish:
          out.add(
            ObstacleSpawn(
              kind: kind,
              x: 40 + rng.nextDouble() * (width - 80),
              depth: d,
              width: 40 + rng.nextDouble() * 14,
              height: 44,
              fromLeft: fromLeft,
              seed: rng.nextInt(1 << 30),
            ),
          );
        case ObstacleKind.rock:
          // الصخرة ملتصقة بأحد الجانبين ولا تغلق الممر أبداً
          final w = width * (0.26 + rng.nextDouble() * 0.2);
          out.add(
            ObstacleSpawn(
              kind: kind,
              x: fromLeft ? w / 2 - 8 : width - w / 2 + 8,
              depth: d,
              width: w,
              height: 46 + rng.nextDouble() * 36,
              fromLeft: fromLeft,
              seed: rng.nextInt(1 << 30),
            ),
          );
        case ObstacleKind.net:
          final w = width * (0.34 + rng.nextDouble() * 0.2);
          out.add(
            ObstacleSpawn(
              kind: kind,
              x: fromLeft ? w / 2 : width - w / 2,
              depth: d,
              width: w,
              height: 30,
              fromLeft: fromLeft,
              seed: rng.nextInt(1 << 30),
            ),
          );
      }
    }
    return out;
  }
}
