import 'dart:ui';

/// درجات ندرة الأسماك.
enum Rarity {
  common('عادي', Color(0xFFB0BEC5)),
  uncommon('غير شائع', Color(0xFF66BB6A)),
  rare('نادر', Color(0xFF42A5F5)),
  epic('ملحمي', Color(0xFFAB47BC)),
  legendary('أسطوري', Color(0xFFFFB300));

  const Rarity(this.arabicName, this.color);

  final String arabicName;
  final Color color;

  static Rarity parse(String value) => Rarity.values.firstWhere((r) => r.name == value, orElse: () => Rarity.common);
}
