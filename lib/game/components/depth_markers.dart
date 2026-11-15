import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../sea_hunter_game.dart';

/// علامات العمق كل 10 أمتار على حافة الشاشة، وخط أحمر عند نهاية الخيط.
class DepthMarkers extends Component with HasGameReference<SeaHunterGame> {
  DepthMarkers() : super(priority: 0);

  final Map<int, TextPainter> _labels = {};
  static final _tick = Paint()
    ..color = const Color(0x66FFFFFF)
    ..strokeWidth = 2;
  static final _limit = Paint()
    ..color = const Color(0x99FF5252)
    ..strokeWidth = 2;

  TextPainter _label(int m) => _labels.putIfAbsent(
    m,
    () => TextPainter(
      text: TextSpan(
        text: '$m م',
        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.w700, color: Color(0x88FFFFFF)),
      ),
      textDirection: TextDirection.rtl,
    )..layout(),
  );

  @override
  void render(Canvas canvas) {
    final ppm = game.ppm;
    final w = game.size.x;
    final top = game.camTop, bottom = top + game.size.y;
    final first = ((top / ppm) / 10).ceil().clamp(1, 1 << 20);
    for (var m = first * 10; m * ppm < bottom; m += 10) {
      final y = m * ppm;
      canvas.drawLine(Offset(w - 16, y), Offset(w - 4, y), _tick);
      final tp = _label(m);
      tp.paint(canvas, Offset(w - 20 - tp.width, y - tp.height / 2));
    }
    // نهاية الخيط
    final limitY = game.lineLength.value * ppm;
    if (limitY > top && limitY < bottom) {
      for (var x = 0.0; x < w; x += 18) {
        canvas.drawLine(Offset(x, limitY), Offset(x + 9, limitY), _limit);
      }
    }
  }
}
