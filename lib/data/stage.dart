import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'fish_species.dart';

/// نوع هدف المرحلة.
enum GoalType {
  /// اصطد عدداً من الأسماك في هذه المرحلة.
  catchCount,

  /// اكتشف (اصطد) عدداً من الأنواع المختلفة في هذه المرحلة.
  species,

  /// انزل إلى عمق معيّن في هذه المرحلة.
  depth,

  /// اربح عدداً من صراعات الأسماك الكبيرة في هذه المرحلة.
  fights,

  /// اجمع عدداً من الريالات في هذه المرحلة.
  coins,

  /// اصطد نوعاً معيّناً (حقل species في JSON).
  catchSpecies;

  static GoalType parse(String v) => switch (v) {
    'catch' => GoalType.catchCount,
    'species' => GoalType.species,
    'depth' => GoalType.depth,
    'fights' => GoalType.fights,
    'coins' => GoalType.coins,
    'catchSpecies' => GoalType.catchSpecies,
    _ => throw FormatException('نوع هدف غير معروف: $v'),
  };
}

/// هدف واحد من أهداف المرحلة.
class StageGoal {
  const StageGoal({required this.type, required this.target, this.speciesId});

  final GoalType type;
  final int target;

  /// لهدف [GoalType.catchSpecies] فقط.
  final String? speciesId;

  factory StageGoal.fromJson(Map<String, dynamic> j) => StageGoal(
    type: GoalType.parse(j['type'] as String),
    target: (j['target'] as num?)?.toInt() ?? 1,
    speciesId: j['species'] as String?,
  );

  /// التقدم الحالي (قبل القص على [target]).
  int progressIn(StageProgress p) => switch (type) {
    GoalType.catchCount => p.catches,
    GoalType.species => p.species.length,
    GoalType.depth => p.bestDepth.floor(),
    GoalType.fights => p.fightsWon,
    GoalType.coins => p.coins,
    GoalType.catchSpecies => p.species.contains(speciesId) ? 1 : 0,
  };

  bool isDone(StageProgress p) => progressIn(p) >= target;

  /// نص الهدف بالعربية.
  String label(FishCatalog catalog) => switch (type) {
    GoalType.catchCount => 'اصطد ${countAr(target, 'سمكة', 'سمكتين', 'أسماك', 'سمكة')}',
    GoalType.species => 'اكتشف ${countAr(target, 'نوعاً', 'نوعين', 'أنواع', 'نوعاً')} مختلفة',
    GoalType.depth => 'انزل إلى عمق $target م',
    GoalType.fights => 'اربح ${countAr(target, 'صراعاً', 'صراعين', 'صراعات', 'صراعاً')} مع سمكة كبيرة',
    GoalType.coins => 'اجمع $target ريال',
    GoalType.catchSpecies => 'اصطد ${catalog.byId(speciesId ?? '')?.name ?? speciesId}',
  };
}

/// العدد مع المعدود بالعربية: 1 → «سمكة واحدة»، 2 → «سمكتين»، 3-10 → «5 أسماك»، 11+ → «15 سمكة».
String countAr(int n, String one, String two, String few, String many) {
  if (n == 1) return one == 'سمكة' ? 'سمكة واحدة' : '$one واحداً';
  if (n == 2) return two;
  if (n >= 3 && n <= 10) return '$n $few';
  return '$n $many';
}

/// مرحلة (منطقة صيد): لها أسماكها وعمق قاعها وأسعارها وأهدافها.
class Stage {
  const Stage({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.emoji,
    required this.region,
    required this.seabed,
    required this.priceMultiplier,
    required this.obstacleDensity,
    required this.goals,
  });

  final String id;
  final String name;
  final String subtitle;
  final String emoji;

  /// المنطقة في fish.json (حقل regions). null = كل الأسماك (للاختبارات).
  final String? region;

  /// عمق القاع بالمتر: لا تنزل الصنارة أعمق منه مهما طال الخيط.
  final double seabed;

  /// مضاعف أسعار الأسماك في هذه المرحلة.
  final double priceMultiplier;

  /// كثافة العوائق (1 = عادية، أكبر = أكثر).
  final double obstacleDensity;

  final List<StageGoal> goals;

  bool hasFish(FishSpecies s) => region == null || s.regions.contains(region);

  /// أعمق هدف عمق في المرحلة (لتنبيه اللاعب أنه يحتاج خيطاً أطول).
  int get depthGoal => goals.where((g) => g.type == GoalType.depth).fold(0, (a, g) => g.target > a ? g.target : a);

  bool isComplete(StageProgress p) => goals.every((g) => g.isDone(p));

  int goalsDone(StageProgress p) => goals.where((g) => g.isDone(p)).length;

  factory Stage.fromJson(Map<String, dynamic> j) => Stage(
    id: j['id'] as String,
    name: j['name'] as String,
    subtitle: j['subtitle'] as String? ?? '',
    emoji: j['emoji'] as String? ?? '🌊',
    region: j['region'] as String?,
    seabed: (j['seabed'] as num).toDouble(),
    priceMultiplier: (j['priceMultiplier'] as num?)?.toDouble() ?? 1,
    obstacleDensity: (j['obstacleDensity'] as num?)?.toDouble() ?? 1,
    goals: [for (final g in (j['goals'] as List? ?? const [])) StageGoal.fromJson(g as Map<String, dynamic>)],
  );

  /// مرحلة مفتوحة بكل الأسماك وبدون قاع — للاختبارات وللحالات الاحتياطية.
  static const open = Stage(
    id: 'open',
    name: 'البحر',
    subtitle: '',
    emoji: '🌊',
    region: null,
    seabed: 1000,
    priceMultiplier: 1,
    obstacleDensity: 1,
    goals: [],
  );
}

/// تقدّم اللاعب داخل مرحلة واحدة (يُحفظ).
class StageProgress {
  const StageProgress({this.catches = 0, this.coins = 0, this.bestDepth = 0, this.fightsWon = 0, this.species = const {}});

  final int catches;
  final int coins;
  final double bestDepth;
  final int fightsWon;

  /// الأنواع التي اصطيدت في هذه المرحلة.
  final Set<String> species;

  static const empty = StageProgress();

  Map<String, dynamic> toMap() => {
    'catches': catches,
    'coins': coins,
    'bestDepth': bestDepth,
    'fightsWon': fightsWon,
    'species': species.toList(),
  };

  factory StageProgress.fromMap(Map<dynamic, dynamic> m) => StageProgress(
    catches: (m['catches'] as num?)?.toInt() ?? 0,
    coins: (m['coins'] as num?)?.toInt() ?? 0,
    bestDepth: (m['bestDepth'] as num?)?.toDouble() ?? 0,
    fightsWon: (m['fightsWon'] as num?)?.toInt() ?? 0,
    species: {for (final s in (m['species'] as List? ?? const [])) s.toString()},
  );
}

/// كل المراحل بالترتيب (من assets/data/stages.json).
class StageCatalog {
  StageCatalog(this.stages) : assert(stages.isNotEmpty);

  final List<Stage> stages;

  Stage get first => stages.first;

  Stage byId(String? id) => stages.firstWhere((s) => s.id == id, orElse: () => stages.first);

  int indexOf(Stage s) => stages.indexOf(s);

  Stage? next(Stage s) {
    final i = stages.indexOf(s);
    return i >= 0 && i + 1 < stages.length ? stages[i + 1] : null;
  }

  /// المرحلة مفتوحة إذا كانت الأولى أو اكتملت المرحلة التي قبلها.
  bool isUnlocked(Stage s, Set<String> completed) {
    final i = stages.indexOf(s);
    return i <= 0 || completed.contains(stages[i - 1].id);
  }

  static const assetPath = 'assets/data/stages.json';

  static StageCatalog parse(String jsonText) {
    final root = jsonDecode(jsonText) as Map<String, dynamic>;
    return StageCatalog([for (final s in root['stages'] as List) Stage.fromJson(s as Map<String, dynamic>)]);
  }

  static Future<StageCatalog> loadFromAssets() async => parse(await rootBundle.loadString(assetPath));

  /// كتالوج بمرحلة مفتوحة واحدة (للاختبارات).
  static final single = StageCatalog(const [Stage.open]);
}
