import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../sea_hunter_game.dart';

/// الصنارة (الخطّاف + الثقالة). اللعبة تحرك موقعها، وهذا المكوّن يرسمها
/// ويتولى نعومة التوجيه.
class HookComponent extends PositionComponent with HasGameReference<SeaHunterGame> {
  HookComponent() : super(priority: 4, anchor: Anchor.center);

  /// الموضع الأفقي الذي يريده إصبع اللاعب.
  double targetX = 0;

  /// السرعة الأفقية الحالية (لإمالة الصنارة وانحناء الخيط).
  double vx = 0;

  double _flash = 0;

  static final _sinker = Paint()..color = const Color(0xFF546E7A);
  static final _metal = Paint()
    ..color = const Color(0xFFE0E6EA)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.8
    ..strokeCap = StrokeCap.round;
  static final _metalShadow = Paint()
    ..color = const Color(0xFF455A64)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4.4
    ..strokeCap = StrokeCap.round;
  static final _bait = Paint()..color = const Color(0xFFFF8A65);
  static final _flashPaint = Paint()..color = const Color(0x88FF3D3D);
  static final _glint = Paint()..color = const Color(0xCCFFFFFF);

  void flash() => _flash = 0.45;

  /// توجيه ناعم نحو [targetX] ضمن حدود الشاشة.
  void steer(double dt, double width, double sharpness) {
    targetX = targetX.clamp(14.0, width - 14.0);
    final prev = x;
    x += (targetX - x) * (1 - math.exp(-sharpness * dt));
    if (dt > 0) vx = (x - prev) / dt;
  }

  /// معلّقة تحت طرف الصنارة على القارب وتتأرجح.
  void dangleFrom(Vector2 tip, double t) {
    position.setValues(tip.x + math.sin(t * 2.1) * 5, tip.y + 36);
    targetX = x;
    vx = 0;
  }

  /// لفّ البكرة: الصنارة ترجع للقارب.
  void reelTowards(Vector2 tip, double dt) {
    final k = 1 - math.exp(-6 * dt);
    x += (tip.x - x) * k;
    y += (tip.y + 36 - y) * k;
    vx = 0;
  }

  @override
  void update(double dt) {
    if (_flash > 0) _flash -= dt;
    angle = (vx * 0.0022).clamp(-0.45, 0.45);
  }

  @override
  void render(Canvas canvas) {
    if (_flash > 0) canvas.drawCircle(const Offset(0, 4), 18, _flashPaint);
    // الثقالة
    canvas.drawOval(Rect.fromCenter(center: const Offset(0, -12), width: 8, height: 11), _sinker);
    canvas.drawCircle(const Offset(-1.5, -14), 1.5, _glint);
    // الخطّاف J
    for (final p in [_metalShadow, _metal]) {
      canvas.drawLine(const Offset(0, -6), const Offset(0, 6), p);
      canvas.drawArc(Rect.fromCircle(center: const Offset(-5, 6), radius: 5), 0, math.pi, false, p);
      canvas.drawLine(const Offset(-10, 6), const Offset(-10, 1), p);
    }
    // الطُّعم
    canvas.drawOval(Rect.fromCenter(center: const Offset(-4, 10), width: 9, height: 6), _bait);
  }
}
