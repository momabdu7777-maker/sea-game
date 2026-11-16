import '../data/stage.dart';

/// حالة اللاعب الدائمة (تُحفظ في Hive).
class PlayerState {
  const PlayerState({
    required this.coins,
    required this.catchCounts,
    required this.heaviest,
    required this.totalCasts,
    required this.bestDepth,
    required this.lineLevel,
    required this.hookLevel,
    required this.soundOn,
    this.lineStrengthLevel = 0,
    this.fightsWon = 0,
    this.fightsLost = 0,
    this.fightStreak = 0,
    this.bestFightStreak = 0,
    this.currentStage = '',
    this.stageProgress = const {},
    this.completedStages = const {},
    this.seenHelp = false,
  });

  factory PlayerState.initial() =>
      const PlayerState(coins: 0, catchCounts: {}, heaviest: {}, totalCasts: 0, bestDepth: 0, lineLevel: 0, hookLevel: 0, soundOn: true);

  /// الرصيد بالريال.
  final int coins;

  /// عدد مرات صيد كل نوع (المفتاح = id) — وجود المفتاح يعني أنه في الألبوم.
  final Map<String, int> catchCounts;

  /// أثقل وزن تم صيده لكل نوع.
  final Map<String, double> heaviest;

  final int totalCasts;
  final double bestDepth;

  /// مستويات الترقيات (تُشترى من شاشة «تطوير العدة»).
  final int lineLevel;
  final int hookLevel;

  /// ترقية "قوة الخيط": توسّع المنطقة الخضراء وتؤخر انقطاع الخيط.
  final int lineStrengthLevel;

  final bool soundOn;

  // ---------- إحصاءات صراع الأسماك الكبيرة ----------
  final int fightsWon;
  final int fightsLost;

  /// صراعات متتالية بدون انقطاع (لمهمة "اربح صراعين بدون انقطاع" في المرحلة 5).
  final int fightStreak;
  final int bestFightStreak;

  int get totalFights => fightsWon + fightsLost;

  // ---------- المراحل ----------

  /// معرّف المرحلة التي يصطاد فيها اللاعب الآن ('' = الأولى).
  final String currentStage;

  /// التقدم في كل مرحلة (المفتاح = معرّف المرحلة).
  final Map<String, StageProgress> stageProgress;

  /// المراحل التي اكتملت أهدافها (تفتح ما بعدها).
  final Set<String> completedStages;

  /// هل شاهد شاشة «كيف تصطاد؟» (تظهر تلقائياً أول مرة فقط).
  final bool seenHelp;

  StageProgress progressIn(String stageId) => stageProgress[stageId] ?? StageProgress.empty;

  bool hasDiscovered(String speciesId) => catchCounts.containsKey(speciesId);

  PlayerState copyWith({
    int? coins,
    Map<String, int>? catchCounts,
    Map<String, double>? heaviest,
    int? totalCasts,
    double? bestDepth,
    int? lineLevel,
    int? hookLevel,
    bool? soundOn,
    int? lineStrengthLevel,
    int? fightsWon,
    int? fightsLost,
    int? fightStreak,
    int? bestFightStreak,
    String? currentStage,
    Map<String, StageProgress>? stageProgress,
    Set<String>? completedStages,
    bool? seenHelp,
  }) => PlayerState(
    coins: coins ?? this.coins,
    catchCounts: catchCounts ?? this.catchCounts,
    heaviest: heaviest ?? this.heaviest,
    totalCasts: totalCasts ?? this.totalCasts,
    bestDepth: bestDepth ?? this.bestDepth,
    lineLevel: lineLevel ?? this.lineLevel,
    hookLevel: hookLevel ?? this.hookLevel,
    soundOn: soundOn ?? this.soundOn,
    lineStrengthLevel: lineStrengthLevel ?? this.lineStrengthLevel,
    fightsWon: fightsWon ?? this.fightsWon,
    fightsLost: fightsLost ?? this.fightsLost,
    fightStreak: fightStreak ?? this.fightStreak,
    bestFightStreak: bestFightStreak ?? this.bestFightStreak,
    currentStage: currentStage ?? this.currentStage,
    stageProgress: stageProgress ?? this.stageProgress,
    completedStages: completedStages ?? this.completedStages,
    seenHelp: seenHelp ?? this.seenHelp,
  );

  Map<String, dynamic> toMap() => {
    'coins': coins,
    'catchCounts': catchCounts,
    'heaviest': heaviest,
    'totalCasts': totalCasts,
    'bestDepth': bestDepth,
    'lineLevel': lineLevel,
    'hookLevel': hookLevel,
    'soundOn': soundOn,
    'lineStrengthLevel': lineStrengthLevel,
    'fightsWon': fightsWon,
    'fightsLost': fightsLost,
    'fightStreak': fightStreak,
    'bestFightStreak': bestFightStreak,
    'currentStage': currentStage,
    'stageProgress': {for (final e in stageProgress.entries) e.key: e.value.toMap()},
    'completedStages': completedStages.toList(),
    'seenHelp': seenHelp,
  };

  factory PlayerState.fromMap(Map<String, dynamic> m) {
    Map<String, T> mapOf<T>(Object? raw, T Function(num) conv) =>
        raw is Map ? {for (final e in raw.entries) e.key.toString(): conv(e.value as num)} : <String, T>{};
    return PlayerState(
      coins: (m['coins'] as num?)?.toInt() ?? 0,
      catchCounts: mapOf(m['catchCounts'], (n) => n.toInt()),
      heaviest: mapOf(m['heaviest'], (n) => n.toDouble()),
      totalCasts: (m['totalCasts'] as num?)?.toInt() ?? 0,
      bestDepth: (m['bestDepth'] as num?)?.toDouble() ?? 0,
      lineLevel: (m['lineLevel'] as num?)?.toInt() ?? 0,
      hookLevel: (m['hookLevel'] as num?)?.toInt() ?? 0,
      soundOn: m['soundOn'] as bool? ?? true,
      lineStrengthLevel: (m['lineStrengthLevel'] as num?)?.toInt() ?? 0,
      fightsWon: (m['fightsWon'] as num?)?.toInt() ?? 0,
      fightsLost: (m['fightsLost'] as num?)?.toInt() ?? 0,
      fightStreak: (m['fightStreak'] as num?)?.toInt() ?? 0,
      bestFightStreak: (m['bestFightStreak'] as num?)?.toInt() ?? 0,
      currentStage: m['currentStage'] as String? ?? '',
      stageProgress: switch (m['stageProgress']) {
        final Map raw => {for (final e in raw.entries) e.key.toString(): StageProgress.fromMap(e.value as Map)},
        _ => const {},
      },
      completedStages: {for (final s in (m['completedStages'] as List? ?? const [])) s.toString()},
      // اللاعب القديم (لعب قبل إضافة الشرح) لا نعرض له الشرح تلقائياً
      seenHelp: m['seenHelp'] as bool? ?? ((m['totalCasts'] as num?)?.toInt() ?? 0) > 0,
    );
  }
}
