import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../sea_hunter_game.dart';

/// خيط الصيد من طرف الصنارة إلى الخطّاف، بانحناء حسب حركة الصنارة.
///
/// أثناء صراع السمكة الكبيرة: مشدود ويرتجف حسب الشد، ويحمرّ مع خطر الانقطاع.
/// بعد الانقطاع: يرتد ويتلوّى لحظة.
class FishingLine extends Component with HasGameReference<SeaHunterGame> {
  FishingLine() : super(priority: 3);

  final Path _path = Path();
  final Paint _paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  static const _white = Color(0xDDFFFFFF);
  static const _danger = Color(0xFFFF4D4D);

  @override
  void render(Canvas canvas) {
    final tip = game.boat.rodTip;
    final hook = game.hook;
    final hx = hook.x, hy = hook.y - 17;
    final phase = game.phase.value;
    final fight = game.fightSession.value;
    final t = game.time;

    var mx = (tip.x + hx) / 2 - hook.vx * 0.12;
    var my = (tip.y + hy) / 2;
    var color = _white;
    var width = 1.3;

    if (phase == CastPhase.flying) {
      // ارتخاء الخيط أثناء الطيران
      my += 40;
    } else if (fight != null && !fight.isOver) {
      // خيط مشدود: بلا ارتخاء، يرتجف أكثر كلما زاد الشد
      mx = (tip.x + hx) / 2;
      final tension = fight.indicator;
      mx += math.sin(t * 95) * (0.6 + tension * 3.5) + math.sin(t * 37) * fight.dangerFraction * 4;
      color = Color.lerp(_white, _danger, fight.dangerFraction)!;
      width = 1.3 + tension * 1.2;
    }

    final snap = game.lineSnapFx;
    if (snap > 0) {
      // الخيط المقطوع يرتد ويتموّج ثم يعود (القائد ينقطع، الصنارة الاحتياطية تبقى)
      my += 140 * snap;
      mx += math.sin(t * 28) * 60 * snap;
      color = Color.lerp(_white, _danger, snap)!;
      width = 1.3 + snap;
    }

    _paint
      ..color = color
      ..strokeWidth = width;
    _path
      ..reset()
      ..moveTo(tip.x, tip.y)
      ..quadraticBezierTo(mx, my, hx, hy);
    canvas.drawPath(_path, _paint);
  }
}
