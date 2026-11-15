import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../sea_hunter_game.dart';
import '../systems/sea_spawner.dart';

/// عائق أثناء النزول: قنديل بحر يتحرك، صخرة على الجانب، أو شبكة قديمة.
/// لمسه أثناء النزول يبدأ الصعود فوراً. أثناء الصعود لا يؤذي.
class ObstacleComponent extends PositionComponent with HasGameReference<SeaHunterGame> {
  ObstacleComponent(ObstacleSpawn s, double ppm)
    : kind = s.kind,
      _w = s.width,
      _h = s.height,
      _rng = math.Random(s.seed),
      super(position: Vector2(s.x, s.depth * ppm), priority: 1) {
    _t = _rng.nextDouble() * 10;
    _drift = (_rng.nextBool() ? 1 : -1) * (10 + _rng.nextDouble() * 18);
    if (kind == ObstacleKind.rock) _buildRock(s.fromLeft);
    if (kind == ObstacleKind.jellyfish) _buildJelly();
  }

  final ObstacleKind kind;
  final double _w, _h;
  final math.Random _rng;
  double _t = 0;
  double _drift = 0;
  double _hit = 0;

  final Path _shape = Path();
  final Path _detail = Path();
  final Path _scratch = Path();
  final List<Offset> _barnacles = [];

  static final _jellyBody = Paint()..color = const Color(0xD9F48FB1);
  static final _jellyInner = Paint()..color = const Color(0x99FFFFFF);
  static final _jellyLine = Paint()
    ..color = const Color(0xCCE57BA8)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.2
    ..strokeCap = StrokeCap.round;
  static final _jellyGlow = Paint()
    ..color = const Color(0x44FF80AB)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
  static final _face = Paint()..color = const Color(0xFF6A1B4D);
  static final _faceLine = Paint()
    ..color = const Color(0xFF6A1B4D)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6
    ..strokeCap = StrokeCap.round;
  static final _rock = Paint()..color = const Color(0xFF6D6A75);
  static final _rockLight = Paint()..color = const Color(0xFF8C8996);
  static final _rockEdge = Paint()
    ..color = const Color(0xFF3F3C47)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.2
    ..strokeJoin = StrokeJoin.round;
  static final _coral = Paint()..color = const Color(0xFFFF8A65);
  static final _coral2 = Paint()..color = const Color(0xFFFFD54F);
  static final _netLine = Paint()
    ..color = const Color(0xB3D7CCC8)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.3;
  static final _rope = Paint()
    ..color = const Color(0xFFA1887F)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;
  static final _float = Paint()..color = const Color(0xFFFF7043);
  static final _dimPaint = Paint()..color = const Color(0x73000000);
  static final _hitPaint = Paint()..color = const Color(0x66FFFFFF);

  void _buildJelly() {
    final r = _w / 2;
    _shape
      ..moveTo(-r, 0)
      ..arcToPoint(Offset(r, 0), radius: Radius.elliptical(r, r * 0.85), clockwise: true);
    // حافة متموجة أسفل الجرس
    const n = 5;
    for (var i = n; i >= 0; i--) {
      final x = -r + 2 * r * i / n;
      _shape.quadraticBezierTo(x + r / n, 7, x, 0);
    }
    _shape.close();
    _detail.addOval(Rect.fromCenter(center: Offset(-r * 0.35, -r * 0.45), width: r * 0.5, height: r * 0.3));
  }

  void _buildRock(bool fromLeft) {
    const n = 13;
    for (var i = 0; i < n; i++) {
      final a = i / n * math.pi * 2;
      final k = 0.8 + _rng.nextDouble() * 0.25;
      final p = Offset(math.cos(a) * _w / 2 * k, math.sin(a) * _h / 2 * k);
      i == 0 ? _shape.moveTo(p.dx, p.dy) : _shape.lineTo(p.dx, p.dy);
    }
    _shape.close();
    _detail.addOval(Rect.fromCenter(center: Offset(0, -_h * 0.18), width: _w * 0.55, height: _h * 0.28));
    for (var i = 0; i < 4; i++) {
      // مرجان صغير على الجهة المكشوفة من الصخرة
      final side = fromLeft ? 1 : -1;
      _barnacles.add(Offset(side * _w * (0.05 + _rng.nextDouble() * 0.32), -_h * (0.25 + _rng.nextDouble() * 0.15)));
    }
  }

  /// اختبار اصطدام دائرة الصنارة.
  bool hits(Vector2 p, double r) {
    final dx = p.x - x, dy = p.y - y;
    switch (kind) {
      case ObstacleKind.jellyfish:
        final rr = _w * 0.42 + r;
        return dx * dx + dy * dy < rr * rr;
      case ObstacleKind.rock:
        final ax = _w / 2 * 0.88 + r, ay = _h / 2 * 0.88 + r;
        return (dx * dx) / (ax * ax) + (dy * dy) / (ay * ay) < 1;
      case ObstacleKind.net:
        return dx.abs() < _w / 2 + r && dy.abs() < _h / 2 + r;
    }
  }

  void onHit() => _hit = 0.5;

  @override
  void update(double dt) {
    _t += dt;
    if (_hit > 0) _hit -= dt;
    if (kind == ObstacleKind.jellyfish) {
      x += _drift * dt;
      final w = game.size.x;
      if (x < 30 && _drift < 0 || x > w - 30 && _drift > 0) _drift = -_drift;
    }
  }

  @override
  void render(Canvas canvas) {
    if (!game.isVisibleY(y, 120)) return;
    // أثناء الصعود العوائق باهتة لأنها لا تؤذي
    final dim = game.phase.value == CastPhase.ascending || game.phase.value == CastPhase.surfacing;
    if (dim) canvas.saveLayer(Rect.fromLTRB(-_w / 2 - 24, -_h / 2 - 30, _w / 2 + 24, _h / 2 + 44), _dimPaint);
    switch (kind) {
      case ObstacleKind.jellyfish:
        _renderJelly(canvas);
      case ObstacleKind.rock:
        _renderRock(canvas);
      case ObstacleKind.net:
        _renderNet(canvas);
    }
    if (dim) canvas.restore();
  }

  void _renderJelly(Canvas canvas) {
    final r = _w / 2;
    final pulse = math.sin(_t * 3.2);
    final squash = _hit > 0 ? 1 + _hit * 0.6 : 1.0;
    canvas.save();
    canvas.scale((1 + pulse * 0.06) * squash, (1 - pulse * 0.08) / squash);
    canvas.drawCircle(Offset(0, -r * 0.2), r * 1.1, _jellyGlow);
    // مجسات
    for (var i = 0; i < 4; i++) {
      final x0 = -r * 0.6 + i * r * 0.4;
      final wv = math.sin(_t * 4 + i) * 6;
      _scratch
        ..reset()
        ..moveTo(x0, 3)
        ..quadraticBezierTo(x0 + wv, 16, x0 - wv * 0.5, 28 + (i % 2) * 6);
      canvas.drawPath(_scratch, _jellyLine);
    }
    canvas.drawPath(_shape, _jellyBody);
    canvas.drawPath(_detail, _jellyInner);
    // وجه غاضب صغير — تحذير للاعب
    canvas.drawCircle(Offset(-r * 0.28, -r * 0.3), 2.2, _face);
    canvas.drawCircle(Offset(r * 0.28, -r * 0.3), 2.2, _face);
    canvas.drawLine(Offset(-r * 0.45, -r * 0.55), Offset(-r * 0.15, -r * 0.45), _faceLine);
    canvas.drawLine(Offset(r * 0.45, -r * 0.55), Offset(r * 0.15, -r * 0.45), _faceLine);
    if (_hit > 0) canvas.drawPath(_shape, _hitPaint);
    canvas.restore();
  }

  void _renderRock(Canvas canvas) {
    canvas.drawPath(_shape, _rock);
    canvas.drawPath(_detail, _rockLight);
    canvas.drawPath(_shape, _rockEdge);
    for (var i = 0; i < _barnacles.length; i++) {
      canvas.drawCircle(_barnacles[i], 4 + (i % 2) * 2, i.isEven ? _coral : _coral2);
    }
    if (_hit > 0) canvas.drawPath(_shape, _hitPaint);
  }

  void _renderNet(Canvas canvas) {
    final sway = math.sin(_t * 1.4) * 4;
    final l = -_w / 2 + sway, r = _w / 2 + sway, t = -_h / 2, b = _h / 2;
    // خيوط الشبكة
    for (var x = l; x <= r; x += 11) {
      final s = math.sin(_t * 2 + x * 0.05) * 2;
      canvas.drawLine(Offset(x, t), Offset(x + s, b), _netLine);
    }
    for (var y = t; y <= b; y += 8) {
      canvas.drawLine(Offset(l, y), Offset(r, y + math.sin(_t * 1.8 + y) * 1.5), _netLine);
    }
    canvas.drawLine(Offset(l - 6, t), Offset(r + 6, t), _rope);
    for (var x = l + 8; x < r; x += 28) {
      canvas.drawCircle(Offset(x, t), 5, _float);
    }
    if (_hit > 0) canvas.drawRect(Rect.fromLTRB(l, t, r, b), _hitPaint);
  }
}
