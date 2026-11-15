import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

/// نص يطفو للأعلى ويختفي (اسم السمكة ووزنها وقيمتها عند السطح).
class FloatingLabel extends PositionComponent {
  FloatingLabel({required Vector2 position, required String title, required String subtitle, required Color color, this.lifetime = 1.7})
    : super(position: position, priority: 8) {
    _title = _painter(title, 20, FontWeight.w900, color);
    _sub = _painter(subtitle, 15, FontWeight.w800, const Color(0xFFFFE082));
  }

  final double lifetime;
  double _age = 0;
  late final TextPainter _title, _sub;
  final Paint _layer = Paint();

  static const _shadow = [
    Shadow(color: Color(0xCC000000), blurRadius: 0, offset: Offset(0, 2)),
    Shadow(color: Color(0x99000000), blurRadius: 6),
  ];

  static TextPainter _painter(String text, double size, FontWeight weight, Color color) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontFamily: 'Tajawal', fontSize: size, fontWeight: weight, color: color, shadows: _shadow, height: 1.1),
    ),
    textDirection: TextDirection.rtl,
    textAlign: TextAlign.center,
  )..layout();

  @override
  void update(double dt) {
    _age += dt;
    y -= (60 * math.exp(-_age * 1.5)) * dt;
    if (_age >= lifetime) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = _age / lifetime;
    final alpha = t < 0.6 ? 1.0 : (1 - (t - 0.6) / 0.4).clamp(0.0, 1.0);
    // ظهور بقفزة صغيرة
    final pop = _age < 0.18 ? 0.6 + 0.55 * math.sin(_age / 0.18 * math.pi / 2) : 1.0 + 0.15 * math.exp(-(_age - 0.18) * 10);
    canvas.scale(pop);
    final needLayer = alpha < 0.99;
    if (needLayer) {
      _layer.color = Color.fromRGBO(0, 0, 0, alpha);
      canvas.saveLayer(Rect.fromCenter(center: Offset.zero, width: 320, height: 120), _layer);
    }
    _title.paint(canvas, Offset(-_title.width / 2, -_title.height - 2));
    _sub.paint(canvas, Offset(-_sub.width / 2, 2));
    if (needLayer) canvas.restore();
  }
}
