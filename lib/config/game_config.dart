import 'dart:ui';

import '../data/rarity.dart';

/// كل أرقام اللعبة القابلة للضبط في مكان واحد.
///
/// القيم هنا افتراضية؛ في المرحلة 6 ستُستبدل جزئياً بقيم من Firebase Remote Config
/// عبر [GameConfig.copyWith] دون الحاجة لتحديث التطبيق.
class GameConfig {
  const GameConfig({
    this.pxPerMeter = 16,
    this.baseLineLength = 100,
    this.baseHookCapacity = 4,
    this.minCastDepth = 6,
    this.perfectCastThreshold = 0.97,
    this.minPowerToCast = 0.08,
    this.maxPullScreenFraction = 0.32,
    this.castFlightSeconds = 0.55,
    this.descendStartSpeed = 5,
    this.descendMaxSpeed = 13,
    this.descendAccel = 9,
    this.ascendSpeed = 8.5,
    this.ascendFullSpeed = 26,
    this.turnPauseSeconds = 0.32,
    this.steerSensitivity = 1.25,
    this.steerSharpness = 16,
    this.hookRadius = 11,
    this.catchForgiveness = 9,
    this.fishGroupsPerMeter = 0.12,
    this.obstacleStartDepth = 9,
    this.obstacleSpacingShallow = 15,
    this.obstacleSpacingDeep = 7,
    this.obstacleRampDepth = 100,
    this.catchSlowMoSeconds = 0.07,
    this.catchSlowMoScale = 0.3,
    this.rarityWeights = const {Rarity.common: 60, Rarity.uncommon: 25, Rarity.rare: 10, Rarity.epic: 4, Rarity.legendary: 1},
    this.rarityPriceMultipliers = const {Rarity.common: 1, Rarity.uncommon: 1.5, Rarity.rare: 2.5, Rarity.epic: 4, Rarity.legendary: 10},
    this.waterColorStops = const [
      // (العمق بالمتر، اللون) — من فيروزي فاتح إلى ظلام الأعماق
      (0, Color(0xFF3FD0D4)),
      (15, Color(0xFF1EA7C4)),
      (40, Color(0xFF127FB0)),
      (80, Color(0xFF0B4F86)),
      (130, Color(0xFF082D5A)),
      (200, Color(0xFF04142E)),
      (320, Color(0xFF01060F)),
    ],
    this.darknessStartDepth = 60,
    this.darknessFullDepth = 220,
    this.fightZoneBase = 0.36,
    this.fightZoneShrinkPerPower = 0.14,
    this.fightZoneMin = 0.16,
    this.fightZoneMax = 0.6,
    this.fightZonePerStrengthLevel = 0.025,
    this.fightReelAccel = 3.0,
    this.fightSlackAccel = 2.6,
    this.fightMaxVelocity = 1.2,
    this.fightBounce = 0.3,
    this.fightDrag = 4,
    this.fightStartProgress = 0.25,
    this.fightGainRate = 0.22,
    this.fightGainPowerPenalty = 0.35,
    this.fightLossRate = 0.07,
    this.fightSnapSeconds = 1.8,
    this.fightSnapPerStrengthLevel = 0.12,
    this.fightDangerRecover = 1.6,
    this.fightIntroSeconds = 1.0,
    this.fightZoneSpeedBase = 0.2,
    this.fightZoneSpeedPerPower = 0.32,
    this.fightRetargetSlow = 1.7,
    this.fightRetargetFast = 0.7,
    this.fightRunChancePerSecond = 0.28,
    this.fightRunBoost = 2.3,
    this.fightRunSeconds = 0.7,
    this.fightWeightPowerBonus = 0.12,
    this.fightReelMeters = 5,
    this.fightStartSlowMoSeconds = 0.35,
  });

  /// كم بكسل يساوي متر واحد في عالم اللعبة.
  final double pxPerMeter;

  /// طول الخيط الأساسي (أقصى عمق) بالمتر — ترقية "الخيط" ستزيده في المرحلة 3.
  final double baseLineLength;

  /// عدد الأسماك في الرمية الواحدة — ترقية "الصنارة" ستزيده.
  final int baseHookCapacity;

  /// أقل عمق للرمية حتى لو كان السحب ضعيفاً.
  final double minCastDepth;

  /// قوة السحب التي تُعتبر "رمية كاملة".
  final double perfectCastThreshold;

  /// أقل قوة سحب تُعتبر رمية (أقل من ذلك = إلغاء).
  final double minPowerToCast;

  /// مسافة السحب القصوى كنسبة من ارتفاع الشاشة.
  final double maxPullScreenFraction;

  /// مدة طيران الصنارة في الهواء قبل لمس الماء.
  final double castFlightSeconds;

  /// سرعات النزول والصعود (متر/ثانية).
  final double descendStartSpeed;
  final double descendMaxSpeed;
  final double descendAccel;
  final double ascendSpeed;

  /// سرعة الصعود بعد امتلاء الصنارة.
  final double ascendFullSpeed;

  /// توقف قصير عند أقصى عمق أو بعد الاصطدام قبل الصعود.
  final double turnPauseSeconds;

  /// حساسية تحريك الصنارة بالإصبع ونعومة متابعتها.
  final double steerSensitivity;
  final double steerSharpness;

  /// نصف قطر الصنارة وهامش التسامح عند الالتقاط (لإحساس أكثر متعة).
  final double hookRadius;
  final double catchForgiveness;

  /// كثافة مجموعات الأسماك لكل متر.
  final double fishGroupsPerMeter;

  /// العوائق: بداية ظهورها والمسافة بينها (تقل مع العمق).
  final double obstacleStartDepth;
  final double obstacleSpacingShallow;
  final double obstacleSpacingDeep;
  final double obstacleRampDepth;

  /// "توقف لحظي" عند التقاط سمكة لزيادة الإحساس بالضربة.
  final double catchSlowMoSeconds;
  final double catchSlowMoScale;

  /// أوزان ظهور كل ندرة، ومضاعف السعر لها.
  final Map<Rarity, double> rarityWeights;
  final Map<Rarity, double> rarityPriceMultipliers;

  /// تدرج لون الماء حسب العمق.
  final List<(double, Color)> waterColorStops;

  /// بداية ونهاية الظلام (تأثير الإضاءة حول الصنارة).
  final double darknessStartDepth;
  final double darknessFullDepth;

  // ---------- صراع السمكة الكبيرة (كل القيم على شريط طوله 1) ----------

  /// عرض المنطقة الخضراء: الأساس، وكم يضيق مع شراسة السمكة، وحدوده.
  final double fightZoneBase;
  final double fightZoneShrinkPerPower;
  final double fightZoneMin;
  final double fightZoneMax;

  /// كم تتسع المنطقة مع كل مستوى من ترقية "قوة الخيط".
  final double fightZonePerStrengthLevel;

  /// فيزياء المؤشر: تسارع الشد (ضغط) والإرخاء (إفلات)، أقصى سرعة، والارتداد عند الطرفين.
  final double fightReelAccel;
  final double fightSlackAccel;
  final double fightMaxVelocity;
  final double fightBounce;

  /// مقاومة الماء للمؤشر: تجعله يستقر بدل أن ينزلق بلا توقف (أسهل في التحكم).
  final double fightDrag;

  /// شريط التقدم: البداية، سرعة الامتلاء داخل الأخضر (تقل مع الشراسة)، والنقصان خارجه.
  final double fightStartProgress;
  final double fightGainRate;
  final double fightGainPowerPenalty;
  final double fightLossRate;

  /// ثوانٍ متواصلة خارج الأخضر قبل انقطاع الخيط، وكم تزيد مع "قوة الخيط".
  final double fightSnapSeconds;
  final double fightSnapPerStrengthLevel;

  /// سرعة تعافي الخيط عند العودة للأخضر.
  final double fightDangerRecover;

  /// مهلة بداية الصراع (لا خسارة فيها) ليفهم اللاعب ما يحدث.
  final double fightIntroSeconds;

  /// حركة المنطقة الخضراء: السرعة، وكل كم ثانية تغيّر هدفها.
  final double fightZoneSpeedBase;
  final double fightZoneSpeedPerPower;
  final double fightRetargetSlow;
  final double fightRetargetFast;

  /// "الاندفاعة": السمكة تسحب فجأة لطرف الشريط (احتمال/ثانية × الشراسة).
  final double fightRunChancePerSecond;
  final double fightRunBoost;
  final double fightRunSeconds;

  /// السمكة الأثقل ضمن نوعها أشرس قليلاً.
  final double fightWeightPowerBonus;

  /// كم متراً ترتفع الصنارة بصرياً من بداية الصراع حتى نهايته.
  final double fightReelMeters;

  /// لحظة إبطاء درامية عند علوق سمكة كبيرة.
  final double fightStartSlowMoSeconds;

  // ---------- دوال مساعدة للترقيات (المرحلة 3 ستضيف منحنيات التكلفة) ----------

  double lineLengthForLevel(int level) => baseLineLength + level * 25;

  int hookCapacityForLevel(int level) => baseHookCapacity + level;

  /// لون الماء عند عمق معين (استيفاء خطي بين النقاط).
  Color waterColorAt(double depth) {
    final stops = waterColorStops;
    if (depth <= stops.first.$1) return stops.first.$2;
    for (var i = 1; i < stops.length; i++) {
      final (d1, c1) = stops[i];
      if (depth <= d1) {
        final (d0, c0) = stops[i - 1];
        return Color.lerp(c0, c1, (depth - d0) / (d1 - d0))!;
      }
    }
    return stops.last.$2;
  }

  /// قوة الظلام عند عمق معين (0 = لا ظلام، 1 = ظلام تام).
  double darknessAt(double depth) => ((depth - darknessStartDepth) / (darknessFullDepth - darknessStartDepth)).clamp(0.0, 1.0);
}
