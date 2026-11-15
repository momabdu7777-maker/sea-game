import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../sea_hunter_game.dart';

/// سطح الماء المتموج أمام القارب (y = 0 في العالم).
class WaveSurface extends Component with HasGameReference<SeaHunterGame> {
  WaveSurface() : super(priority: 6);

  final Path _fill = Path();
  final Path _foam = Path();
  double _t = 0;
  final Paint _water = Paint();
  static final _foamPaint = Paint()
    ..color = const Color(0xD9FFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.4
    ..strokeCap = StrokeCap.round;

  double waveAt(double x) => math.sin(x * 0.03 + _t * 2) * 3 + math.sin(x * 0.071 - _t * 1.3) * 2;

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    if (!game.isVisibleY(0, 40)) return;
    final w = game.size.x;
    _water.color = game.config.waterColorAt(0).withValues(alpha: 0.92);
    _fill.reset();
    _foam.reset();
    _fill.moveTo(0, 24);
    for (var x = 0.0; x <= w + 12; x += 12) {
      final y = waveAt(x);
      _fill.lineTo(x, y);
      x == 0 ? _foam.moveTo(x, y) : _foam.lineTo(x, y);
    }
    _fill
      ..lineTo(w + 12, 24)
      ..close();
    canvas.drawPath(_fill, _water);
    canvas.drawPath(_foam, _foamPaint);
  }
}
