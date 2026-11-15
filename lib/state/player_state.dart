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

  /// مستويات الترقيات (المرحلة 3 ستضيف الباقي).
  final int lineLevel;
  final int hookLevel;

  /// ترقية "قوة الخيط": توسّع المنطقة الخضراء وتؤخر انقطاع الخيط (واجهتها في المرحلة 3).
  final int lineStrengthLevel;

  final bool soundOn;

  // ---------- إحصاءات صراع الأسماك الكبيرة ----------
  final int fightsWon;
  final int fightsLost;

  /// صراعات متتالية بدون انقطاع (لمهمة "اربح صراعين بدون انقطاع" في المرحلة 5).
  final int fightStreak;
  final int bestFightStreak;

  int get totalFights => fightsWon + fightsLost;

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
    );
  }
}
