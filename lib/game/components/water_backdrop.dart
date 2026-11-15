import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../sea_hunter_game.dart';

/// الخلفية بإحداثيات الشاشة: السماء وساحل المكلا، تدرج لون الماء حسب العمق،
/// أشعة الشمس قرب السطح، و"ثلج البحر" الذي يعطي إحساس السرعة.
class WaterBackdrop extends Component with HasGameReference<SeaHunterGame> {
  final Paint _sky = Paint();
  final Paint _water = Paint();
  final Paint _ray = Paint();
  final Paint _snow = Paint()..strokeCap = StrokeCap.round;
  static final _sun = Paint()..color = const Color(0xFFFFE08A);
  static final _sunGlow = Paint()
    ..color = const Color(0x66FFF3C4)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
  static final _hill = Paint()..color = const Color(0xFFCDA978);
  static final _hillFar = Paint()..color = const Color(0xFFDCC59C);
  static final _house = Paint()..color = const Color(0xFFFFFBF2);
  static final _window = Paint()..color = const Color(0xFF8D6E63);
  static final _cloud = Paint()..color = const Color(0xE6FFFFFF);

  final List<Offset> _snowPos = [];
  final List<double> _snowSize = [];
  final _rng = math.Random(3);
  double _t = 0;
  double _lastW = 0;
  final Path _hillPath = Path(), _farPath = Path(), _rayPath = Path();
  final List<Rect> _houses = [];

  void _buildCoast(double w) {
    _lastW = w;
    _farPath
      ..reset()
      ..moveTo(0, 0)
      ..lineTo(0, -38)
      ..quadraticBezierTo(w * 0.15, -70, w * 0.32, -44)
      ..quadraticBezierTo(w * 0.5, -78, w * 0.7, -40)
      ..lineTo(w * 0.7, 0)
      ..close();
    _hillPath
      ..reset()
      ..moveTo(0, 0)
      ..lineTo(0, -22)
      ..quadraticBezierTo(w * 0.12, -40, w * 0.25, -24)
      ..quadraticBezierTo(w * 0.38, -12, w * 0.5, -18)
      ..lineTo(w * 0.5, 0)
      ..close();
    // بيوت المكلا البيضاء على السفح
    _houses.clear();
    final r = math.Random(11);
    for (var i = 0; i < 9; i++) {
      final x = w * 0.03 + i * w * 0.045;
      final h = 9 + r.nextDouble() * 12;
      _houses.add(Rect.fromLTWH(x, -18 - h - r.nextDouble() * 10, w * 0.035, h));
    }
    _snowPos.clear();
    _snowSize.clear();
  }

  @override
  void update(double dt) {
    _t += dt;
    _lastDt = dt;
  }

  double _lastDt = 1 / 60;

  @override
  void render(Canvas canvas) {
    final w = game.size.x, h = game.size.y;
    if (w <= 0) return;
    if (w != _lastW) _buildCoast(w);
    final top = game.camTop;
    final ppm = game.ppm;
    final surface = -top; // موضع سطح الماء على الشاشة
    final cfg = game.config;

    // ---------- السماء ----------
    if (surface > 0) {
      final skyBottom = math.min(surface, h);
      _sky.shader = Gradient.linear(Offset(0, surface - h * 0.6), Offset(0, surface), const [Color(0xFF6EC6F0), Color(0xFFD4F1FC)]);
      canvas.drawRect(Rect.fromLTRB(0, 0, w, skyBottom + 2), _sky);
      final sun = Offset(w * 0.22, surface - h * 0.33);
      canvas.drawCircle(sun, 52, _sunGlow);
      canvas.drawCircle(sun, 30, _sun);
      for (var i = 0; i < 3; i++) {
        final cx = ((_t * (6 + i * 3) + i * w * 0.4) % (w + 160)) - 80;
        final cy = surface - h * (0.22 + i * 0.07);
        canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: 70, height: 20), _cloud);
        canvas.drawOval(Rect.fromCenter(center: Offset(cx + 18, cy - 8), width: 40, height: 20), _cloud);
      }
      canvas.save();
      canvas.translate(0, surface);
      canvas.drawPath(_farPath, _hillFar);
      canvas.drawPath(_hillPath, _hill);
      for (final r in _houses) {
        canvas.drawRect(r, _house);
        canvas.drawRect(Rect.fromLTWH(r.left + r.width * 0.3, r.top + 3, r.width * 0.35, 3), _window);
      }
      canvas.restore();
    }

    // ---------- الماء ----------
    final waterTop = math.max(0.0, surface);
    if (waterTop < h) {
      final d0 = math.max(0.0, top / ppm);
      final d1 = (top + h) / ppm;
      final colors = <Color>[];
      final stops = <double>[];
      for (var i = 0; i <= 4; i++) {
        final f = i / 4;
        colors.add(cfg.waterColorAt(d0 + (d1 - d0) * f));
        stops.add(f);
      }
      _water.shader = Gradient.linear(Offset(0, waterTop), Offset(0, h), colors, stops);
      canvas.drawRect(Rect.fromLTRB(0, waterTop, w, h), _water);

      // أشعة الشمس تحت السطح
      final rayAlpha = (1 - d0 / 30).clamp(0.0, 1.0) * 0.12;
      if (rayAlpha > 0.005 && surface > -420) {
        _ray.color = Color.fromRGBO(255, 255, 255, rayAlpha);
        for (var i = 0; i < 4; i++) {
          final x = w * (0.12 + i * 0.26) + math.sin(_t * 0.4 + i * 1.7) * 20;
          _rayPath
            ..reset()
            ..moveTo(x - 14, surface)
            ..lineTo(x + 14, surface)
            ..lineTo(x + 60, surface + 420)
            ..lineTo(x - 10, surface + 420)
            ..close();
          canvas.drawPath(_rayPath, _ray);
        }
      }

      // ثلج البحر: جسيمات بتأثير المنظور (Parallax) تتمطط مع السرعة
      if (_snowPos.isEmpty) {
        for (var i = 0; i < 46; i++) {
          _snowPos.add(Offset(_rng.nextDouble() * w, _rng.nextDouble() * h));
          _snowSize.add(0.8 + _rng.nextDouble() * 1.8);
        }
      }
      final v = game.camVelocity;
      final dy = v * _lastDt;
      final stretch = (v.abs() * 0.035).clamp(0.0, 26.0);
      final alpha = 0.18 + (d0 / 120).clamp(0.0, 0.25);
      for (var i = 0; i < _snowPos.length; i++) {
        final s = _snowSize[i];
        var p = _snowPos[i];
        var ny = p.dy - dy * (0.4 + s * 0.25);
        if (ny < 0) ny += h;
        if (ny > h) ny -= h;
        p = Offset(p.dx + math.sin(_t + i) * 0.1, ny);
        _snowPos[i] = p;
        if (p.dy < waterTop) continue;
        _snow
          ..color = Color.fromRGBO(220, 240, 255, alpha)
          ..strokeWidth = s * 1.4;
        if (stretch > 1.5) {
          canvas.drawLine(p, p.translate(0, v > 0 ? -stretch * s * 0.5 : stretch * s * 0.5), _snow);
        } else {
          canvas.drawCircle(p, s, _snow);
        }
      }
    }
  }
}
