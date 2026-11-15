import 'dart:ui';

import 'package:flame/components.dart';

import '../sea_hunter_game.dart';

/// ظلام الأعماق: إضاءة دائرية حول الصنارة تضيق كلما نزلنا.
/// (في المناطق العميقة لاحقاً تظهر الأسماك المضيئة فوق هذا الظلام)
class DepthVignette extends Component with HasGameReference<SeaHunterGame> {
  DepthVignette() : super(priority: 0);

  final Paint _paint = Paint();

  @override
  void render(Canvas canvas) {
    final w = game.size.x, h = game.size.y;
    final centerDepth = (game.camTop + h / 2) / game.ppm;
    final dark = game.config.darknessAt(centerDepth);
    if (dark < 0.02) return;
    final hook = game.hook;
    final c = Offset(hook.x, hook.y - game.camTop);
    final radius = w * (1.1 - dark * 0.45);
    _paint.shader = Gradient.radial(
      c,
      radius,
      [const Color(0x00000000), Color.fromRGBO(0, 4, 12, 0.35 * dark), Color.fromRGBO(0, 2, 8, 0.92 * dark)],
      const [0.2, 0.55, 1],
    );
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), _paint);
  }
}
