import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../sea_hunter_game.dart';

/// أثناء السحب: مسار الرمية المتوقع + خط متقطع يُظهر العمق الذي ستصله الصنارة.
class AimIndicator extends Component with HasGameReference<SeaHunterGame> {
  AimIndicator() : super(priority: 9);

  final Paint _dot = Paint();
  final Paint _dash = Paint()..strokeWidth = 2.5;
  final Paint _ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;
  double _t = 0;

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    if (!game.isAimDragging) return;
    final p = game.aimPower;
    if (p < 0.02) return;
    final color = PowerGauge.colorFor(p, game.config.perfectCastThreshold);
    final tip = game.boat.rodTip;
    final ex = game.entryXForPull(game.aimPullX);
    final arc = 70 + (tip.x - ex).abs() * 0.25;

    // نقاط المسار
    _dot.color = const Color(0xE6FFFFFF);
    for (var i = 1; i <= 12; i++) {
      final t = i / 12;
      final x = tip.x + (ex - tip.x) * t;
      final y = tip.y + (0 - tip.y) * t * t - arc * 4 * t * (1 - t);
      canvas.drawCircle(Offset(x, y), 2.6 - t, _dot);
    }

    // خط العمق المتقطع وحلقة الهدف
    final depthY = game.depthForPower(p) * game.ppm;
    final march = (_t * 40) % 20;
    _dash.color = color.withValues(alpha: 0.8);
    for (var y = march; y < depthY; y += 20) {
      canvas.drawLine(Offset(ex, y), Offset(ex, math.min(depthY, y + 10)), _dash);
    }
    _ring.color = color;
    canvas.drawCircle(Offset(ex, depthY), 12 + math.sin(_t * 8) * 2, _ring);
  }
}

/// مؤشر قوة الرمية (بإحداثيات الشاشة) على جانب الشاشة.
class PowerGauge extends Component with HasGameReference<SeaHunterGame> {
  PowerGauge() : super(priority: 1);

  final Paint _bg = Paint()..color = const Color(0x66000000);
  final Paint _border = Paint()
    ..color = const Color(0xAAFFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  final Paint _fill = Paint();
  final Paint _glow = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
  final Paint _tickPaint = Paint()
    ..color = const Color(0x66FFFFFF)
    ..strokeWidth = 1.5;
  TextPainter? _label;
  int _labelValue = -1;
  bool _labelPerfect = false;
  double _t = 0;

  static Color colorFor(double p, double perfect) {
    if (p >= perfect) return const Color(0xFFFFD700);
    if (p < 0.5) return Color.lerp(const Color(0xFF5BE37D), const Color(0xFFFFE066), p / 0.5)!;
    return Color.lerp(const Color(0xFFFFE066), const Color(0xFFFF7A3D), (p - 0.5) / 0.5)!;
  }

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    if (!game.isAimDragging) return;
    final p = game.aimPower;
    final h = game.size.y;
    final perfect = p >= game.config.perfectCastThreshold;
    const left = 16.0, width = 26.0;
    final top = h * 0.3, bottom = h * 0.7;
    final rect = RRect.fromLTRBR(left, top, left + width, bottom, const Radius.circular(13));
    canvas.drawRRect(rect, _bg);
    final fillTop = bottom - (bottom - top) * p;
    final color = colorFor(p, game.config.perfectCastThreshold);
    if (perfect) {
      _glow.color = color.withValues(alpha: 0.5 + 0.3 * math.sin(_t * 14));
      canvas.drawRRect(rect.inflate(4), _glow);
    }
    _fill.color = color;
    canvas.save();
    canvas.clipRRect(rect);
    canvas.drawRect(Rect.fromLTRB(left, fillTop, left + width, bottom), _fill);
    canvas.restore();
    for (var i = 1; i < 10; i++) {
      final y = bottom - (bottom - top) * i / 10;
      canvas.drawLine(Offset(left + 4, y), Offset(left + (i == 5 ? width - 4 : 11), y), _tickPaint);
    }
    canvas.drawRRect(rect, _border);

    final depth = game.depthForPower(p).round();
    if (depth != _labelValue || perfect != _labelPerfect) {
      _labelValue = depth;
      _labelPerfect = perfect;
      _label = TextPainter(
        text: TextSpan(
          text: perfect ? '$depth م\nكاملة!' : '$depth م',
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: perfect ? const Color(0xFFFFD700) : const Color(0xFFFFFFFF),
            shadows: const [Shadow(color: Color(0xAA000000), blurRadius: 4)],
            height: 1.1,
          ),
        ),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
      )..layout();
    }
    final tp = _label!;
    tp.paint(canvas, Offset(left + width / 2 - tp.width / 2, top - tp.height - 8));
  }
}
