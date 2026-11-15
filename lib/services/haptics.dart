import 'package:flutter/services.dart';

/// اهتزازات اللمس. مجمّعة هنا ليسهل استبدالها لاحقاً بحزمة تتحكم بشدة الاهتزاز.
class Haptics {
  static bool enabled = true;

  static void tick() {
    if (enabled) HapticFeedback.selectionClick();
  }

  static void light() {
    if (enabled) HapticFeedback.lightImpact();
  }

  static void medium() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  static void heavy() {
    if (enabled) HapticFeedback.heavyImpact();
  }

  /// نبضة بشدة متدرجة (0..1) — للاهتزاز المتصاعد أثناء صراع السمكة الكبيرة.
  static void pulse(double intensity) {
    if (intensity < 0.4) {
      light();
    } else if (intensity < 0.72) {
      medium();
    } else {
      heavy();
    }
  }
}
