import 'fish_species.dart';

/// سمكة تم اصطيادها في رمية.
class CaughtFish {
  CaughtFish({required this.species, required this.weightKg, required this.value, this.fromFight = false});

  final FishSpecies species;
  final double weightKg;
  final int value;

  /// اصطيدت بعد صراع (سمكة كبيرة).
  final bool fromFight;

  /// هل هي أول مرة يُصطاد فيها هذا النوع؟ (يحددها PlayerNotifier عند تسجيل النتيجة)
  bool isNew = false;
}

/// سبب انتهاء النزول.
enum DescentEnd {
  /// وصلت الصنارة لأقصى عمق الرمية.
  reachedDepth,

  /// اصطدمت بعائق.
  hitObstacle,
}

/// نتيجة رمية كاملة.
class CastResult {
  CastResult({
    required this.fish,
    required this.maxDepth,
    required this.end,
    required this.seed,
    this.obstacleName,
    this.lost = const [],
    this.fightLog = const [],
    this.stageId = '',
  });

  /// المرحلة التي تمت فيها الرمية.
  final String stageId;

  /// تحددها PlayerNotifier: هل اكتملت أهداف المرحلة بهذه الرمية؟
  bool completedStage = false;

  /// تحددها PlayerNotifier: الأهداف التي تحققت لأول مرة في هذه الرمية (أرقامها في قائمة أهداف المرحلة).
  List<int> newGoals = const [];

  final List<CaughtFish> fish;

  /// الأسماك الكبيرة التي انقطع خيطها (تُعرض في النتيجة لتحفيز المحاولة).
  final List<CaughtFish> lost;

  /// نتائج الصراعات بالترتيب (true = فوز) — لحساب "صراعات متتالية بدون انقطاع".
  final List<bool> fightLog;
  final double maxDepth;
  final DescentEnd end;
  final String? obstacleName;

  /// البذرة العشوائية للرمية (ستُستخدم في "تحدي صديق").
  final int seed;

  int get totalValue => fish.fold(0, (sum, f) => sum + f.value);

  int get fightsWon => fightLog.where((w) => w).length;

  int get lostValue => lost.fold(0, (sum, f) => sum + f.value);

  bool get hasNewSpecies => fish.any((f) => f.isNew);
}
