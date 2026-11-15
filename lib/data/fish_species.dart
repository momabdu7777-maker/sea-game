import 'dart:convert';
import 'dart:ui';

import 'package:flutter/services.dart' show rootBundle;

import 'rarity.dart';

/// نمط حركة السمكة في الماء.
enum FishMovement {
  /// سرب: تسبح معاً بخط مستقيم مع تموج خفيف.
  school,

  /// تجوال هادئ مع توقفات واستدارات أحياناً.
  cruise,

  /// سريعة ومتقلبة الاتجاه (للأسماك النادرة).
  dart,

  /// اندفاعات متقطعة مثل الحبار.
  pulse,

  /// مشي بطيء جانبي مثل السرطان.
  crawl;

  static FishMovement parse(String v) => FishMovement.values.firstWhere((m) => m.name == v, orElse: () => FishMovement.cruise);
}

/// شكل الرسم المؤقت للسمكة (يُستبدل لاحقاً بصور نهائية).
enum FishShape {
  slim,
  round,
  long,
  flyer,
  grouper,
  squid,
  crab,

  /// جسم طوربيدي وذيل هلالي وزعانف صفراء صغيرة.
  tuna,

  /// زعنفة ظهرية مثلثة وذيل غير متماثل وفتحات خياشيم.
  shark,

  /// مثل القرش لكن برأس عريض وبقع بيضاء.
  whaleshark;

  static FishShape parse(String v) => FishShape.values.firstWhere((s) => s.name == v, orElse: () => FishShape.slim);
}

/// تعريف نوع سمكة كما في ملف assets/data/fish.json.
class FishSpecies {
  const FishSpecies({
    required this.id,
    required this.name,
    required this.description,
    required this.rarity,
    required this.regions,
    required this.minDepth,
    required this.maxDepth,
    required this.minWeight,
    required this.maxWeight,
    required this.basePrice,
    required this.times,
    required this.weather,
    required this.movement,
    required this.schoolMin,
    required this.schoolMax,
    required this.speed,
    required this.sizePx,
    required this.evasion,
    required this.shape,
    required this.bodyColor,
    required this.accentColor,
    required this.glow,
    required this.bigFight,
    required this.fightPower,
    required this.fightMinWeight,
  });

  final String id;
  final String name;
  final String description;
  final Rarity rarity;
  final List<String> regions;
  final double minDepth;
  final double maxDepth;
  final double minWeight;
  final double maxWeight;
  final double basePrice;
  final List<String> times;
  final List<String> weather;
  final FishMovement movement;
  final int schoolMin;
  final int schoolMax;
  final double speed;
  final double sizePx;
  final double evasion;
  final FishShape shape;
  final Color bodyColor;
  final Color accentColor;
  final bool glow;

  /// هل هذا النوع يُطلق "صراع السمكة الكبيرة"؟
  final bool bigFight;

  /// شراسة الصراع (0..1): تضيّق المنطقة الخضراء وتسرّع حركتها وتزيد الاندفاعات.
  final double fightPower;

  /// الصراع لا يبدأ إلا إذا كان الوزن ≥ هذا الحد (مثلاً: الهامور الضخم فقط).
  final double fightMinWeight;

  bool livesAt(double depth) => depth >= minDepth && depth <= maxDepth;

  /// هل سمكة بهذا الوزن تحتاج صراعاً لاصطيادها؟
  bool triggersFight(double weightKg) => bigFight && weightKg >= fightMinWeight;

  factory FishSpecies.fromJson(Map<String, dynamic> j) {
    double d(String k, [double def = 0]) => (j[k] as num?)?.toDouble() ?? def;
    List<String> l(String k) => (j[k] as List?)?.cast<String>() ?? const [];
    return FishSpecies(
      id: j['id'] as String,
      name: j['name'] as String,
      description: j['description'] as String? ?? '',
      rarity: Rarity.parse(j['rarity'] as String? ?? 'common'),
      regions: l('regions'),
      minDepth: d('minDepth'),
      maxDepth: d('maxDepth', 50),
      minWeight: d('minWeight', 0.1),
      maxWeight: d('maxWeight', 1),
      basePrice: d('basePrice', 1),
      times: l('times'),
      weather: l('weather'),
      movement: FishMovement.parse(j['movement'] as String? ?? 'cruise'),
      schoolMin: (j['schoolMin'] as num?)?.toInt() ?? 1,
      schoolMax: (j['schoolMax'] as num?)?.toInt() ?? 1,
      speed: d('speed', 40),
      sizePx: d('sizePx', 36),
      evasion: d('evasion'),
      shape: FishShape.parse(j['shape'] as String? ?? 'slim'),
      bodyColor: _hex(j['bodyColor'] as String? ?? '#90A4AE'),
      accentColor: _hex(j['accentColor'] as String? ?? '#455A64'),
      glow: j['glow'] as bool? ?? false,
      bigFight: j['bigFight'] as bool? ?? false,
      fightPower: d('fightPower', 0.4).clamp(0.0, 1.0),
      fightMinWeight: d('fightMinWeight'),
    );
  }

  static Color _hex(String s) => Color(int.parse('FF${s.replaceFirst('#', '')}', radix: 16));
}

/// كتالوج كل الأسماك المحمّلة من JSON.
class FishCatalog {
  FishCatalog(this.species) : _byId = {for (final s in species) s.id: s};

  final List<FishSpecies> species;
  final Map<String, FishSpecies> _byId;

  FishSpecies? byId(String id) => _byId[id];

  static const assetPath = 'assets/data/fish.json';

  static FishCatalog parse(String jsonText) {
    final root = jsonDecode(jsonText) as Map<String, dynamic>;
    final list = (root['species'] as List).cast<Map<String, dynamic>>();
    return FishCatalog(list.map(FishSpecies.fromJson).toList(growable: false));
  }

  static Future<FishCatalog> loadFromAssets() async => parse(await rootBundle.loadString(assetPath));
}
