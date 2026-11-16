import '../config/game_config.dart';
import '../state/player_state.dart';

/// ترقيات العدة التي تُشترى بالريالات.
enum Upgrade {
  /// طول الخيط: أقصى عمق للرمية.
  line(
    name: 'طول الخيط',
    emoji: '🧵',
    description: 'خيط أطول = تنزل أعمق، حيث الأسماك الأندر والأغلى.',
    costs: [80, 160, 300, 500, 800, 1200, 1800, 2600],
  ),

  /// سعة الصنارة: عدد الأسماك في الرمية الواحدة.
  hook(
    name: 'سعة الصنارة',
    emoji: '🪝',
    description: 'صنارة أكبر = أسماك أكثر في كل رمية قبل أن تمتلئ.',
    costs: [120, 260, 480, 800, 1250, 1900],
  ),

  /// قوة الخيط: صراع أسهل مع الأسماك الكبيرة.
  strength(
    name: 'قوة الخيط',
    emoji: '💪',
    description: 'منطقة خضراء أوسع في الصراع، ووقت أطول قبل أن ينقطع الخيط.',
    costs: [150, 350, 650, 1100, 1700],
  );

  const Upgrade({required this.name, required this.emoji, required this.description, required this.costs});

  final String name;
  final String emoji;
  final String description;

  /// سعر المستوى التالي: costs[المستوى الحالي].
  final List<int> costs;

  int get maxLevel => costs.length;

  int levelOf(PlayerState p) => switch (this) {
    Upgrade.line => p.lineLevel,
    Upgrade.hook => p.hookLevel,
    Upgrade.strength => p.lineStrengthLevel,
  };

  bool isMaxed(PlayerState p) => levelOf(p) >= maxLevel;

  /// سعر الترقية التالية (null إذا وصلت لأقصى مستوى).
  int? nextCost(PlayerState p) {
    final l = levelOf(p);
    return l < maxLevel ? costs[l] : null;
  }

  bool canAfford(PlayerState p) {
    final c = nextCost(p);
    return c != null && p.coins >= c;
  }

  PlayerState withLevel(PlayerState p, int level) => switch (this) {
    Upgrade.line => p.copyWith(lineLevel: level),
    Upgrade.hook => p.copyWith(hookLevel: level),
    Upgrade.strength => p.copyWith(lineStrengthLevel: level),
  };

  /// أثر المستوى كنص قصير: «125 م»، «5 أسماك»، «أوسع 7٪».
  String effectAt(GameConfig c, int level) => switch (this) {
    Upgrade.line => '${c.lineLengthForLevel(level).round()} م',
    Upgrade.hook => '${c.hookCapacityForLevel(level)} أسماك',
    Upgrade.strength => level == 0 ? 'عادي' : 'أوسع ${(level * c.fightZonePerStrengthLevel * 100 / c.fightZoneBase).round()}٪',
  };
}
