import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../sea_hunter_game.dart';

enum _Kind { bubble, droplet, ring, spark, coin }

class _P {
  _Kind kind = _Kind.bubble;
  bool alive = false;
  double x = 0, y = 0, vx = 0, vy = 0, life = 0, maxLife = 1, size = 2;
  Color color = const Color(0xFFFFFFFF);
}

/// نظام جسيمات واحد خفيف لكل المؤثرات: فقاعات، رذاذ، حلقات، شرر، عملات.
/// يستخدم مجموعة ثابتة من الجسيمات (Pool) لتجنب إنشاء كائنات أثناء اللعب.
class FxLayer extends Component with HasGameReference<SeaHunterGame> {
  FxLayer() : super(priority: 7);

  final List<_P> _pool = List.generate(320, (_) => _P());
  int _cursor = 0;
  final _rng = math.Random();
  double _trailAcc = 0;

  final Paint _fill = Paint();
  final Paint _stroke = Paint()..style = PaintingStyle.stroke;
  static final _coinEdge = Paint()..color = const Color(0xFFB8860B);
  static final _coinFace = Paint()..color = const Color(0xFFFFD54F);
  static final _coinShine = Paint()..color = const Color(0xFFFFF8E1);

  _P _alloc() {
    for (var i = 0; i < _pool.length; i++) {
      _cursor = (_cursor + 1) % _pool.length;
      final p = _pool[_cursor];
      if (!p.alive) return p..alive = true;
    }
    // كلها مشغولة: أعد استخدام الأقدم
    return _pool[_cursor]..alive = true;
  }

  void _spawn(_Kind k, double x, double y, double vx, double vy, double life, double size, Color c) {
    final p = _alloc();
    p
      ..kind = k
      ..x = x
      ..y = y
      ..vx = vx
      ..vy = vy
      ..life = life
      ..maxLife = life
      ..size = size
      ..color = c;
  }

  double _r(double a, double b) => a + _rng.nextDouble() * (b - a);

  void bubbles(Vector2 at, int n) {
    for (var i = 0; i < n; i++) {
      _spawn(
        _Kind.bubble,
        at.x + _r(-8, 8),
        at.y + _r(-6, 6),
        _r(-15, 15),
        _r(-90, -40),
        _r(0.6, 1.2),
        _r(1.5, 4),
        const Color(0xCCFFFFFF),
      );
    }
  }

  /// فقاعات خلف الصنارة أثناء النزول.
  void trail(Vector2 at, double dt) {
    _trailAcc += dt;
    while (_trailAcc > 0.045) {
      _trailAcc -= 0.045;
      _spawn(_Kind.bubble, at.x + _r(-3, 3), at.y - 14, _r(-10, 10), _r(-50, -20), _r(0.4, 0.8), _r(1.2, 2.8), const Color(0xAAFFFFFF));
    }
  }

  /// رذاذ ماء عند السطح.
  void splash(Vector2 at, {int count = 16}) {
    for (var i = 0; i < count; i++) {
      final a = _r(-math.pi * 0.85, -math.pi * 0.15);
      final s = _r(140, 420);
      _spawn(
        _Kind.droplet,
        at.x + _r(-6, 6),
        at.y - 2,
        math.cos(a) * s,
        math.sin(a) * s,
        _r(0.5, 0.9),
        _r(2, 4.5),
        const Color(0xEEE0F7FA),
      );
    }
    _spawn(_Kind.ring, at.x, at.y, 0, 0, 0.5, 6, const Color(0xCCFFFFFF));
  }

  /// انفجار صغير عند التقاط سمكة.
  void catchBurst(Vector2 at, Color color) {
    _spawn(_Kind.ring, at.x, at.y, 0, 0, 0.35, 8, color);
    for (var i = 0; i < 8; i++) {
      final a = i / 8 * math.pi * 2;
      _spawn(_Kind.spark, at.x, at.y, math.cos(a) * 160, math.sin(a) * 160, 0.3, 3, const Color(0xFFFFFFFF));
    }
    bubbles(at, 6);
  }

  /// شرر عند الاصطدام بعائق.
  void sparks(Vector2 at) {
    for (var i = 0; i < 12; i++) {
      final a = _r(0, math.pi * 2);
      final s = _r(80, 260);
      _spawn(_Kind.spark, at.x, at.y, math.cos(a) * s, math.sin(a) * s, _r(0.25, 0.45), _r(2, 4), const Color(0xFFFFEB3B));
    }
    _spawn(_Kind.ring, at.x, at.y, 0, 0, 0.4, 10, const Color(0xFFFF5252));
  }

  /// عملات تتطاير ثم تطير إلى عداد الريالات.
  void coins(Vector2 at, int n) {
    for (var i = 0; i < n; i++) {
      final a = _r(0, math.pi * 2);
      final s = _r(120, 280);
      _spawn(_Kind.coin, at.x, at.y, math.cos(a) * s, math.sin(a) * s - 80, _r(1.1, 1.5), _r(5, 7), const Color(0xFFFFD54F));
    }
  }

  @override
  void update(double dt) {
    final tx = game.coinTargetX, ty = game.coinTargetY;
    for (final p in _pool) {
      if (!p.alive) continue;
      p.life -= dt;
      if (p.life <= 0) {
        p.alive = false;
        continue;
      }
      switch (p.kind) {
        case _Kind.bubble:
          p.vx += math.sin(p.life * 12) * 40 * dt;
          if (p.y < 0) p.life = 0; // الفقاعة تنفجر عند السطح
        case _Kind.droplet:
          p.vy += 900 * dt;
          if (p.y > 4 && p.vy > 0) p.life = 0;
        case _Kind.ring:
          p.size += 120 * dt;
        case _Kind.spark:
          p.vx *= math.exp(-6 * dt);
          p.vy *= math.exp(-6 * dt);
        case _Kind.coin:
          final age = p.maxLife - p.life;
          if (age < 0.28) {
            p.vx *= math.exp(-4 * dt);
            p.vy = p.vy * math.exp(-4 * dt) + 300 * dt;
          } else {
            // انجذاب نحو العداد بسرعة متزايدة
            final dx = tx - p.x, dy = ty - p.y;
            final d = math.sqrt(dx * dx + dy * dy);
            if (d < 16) {
              p.life = 0;
              continue;
            }
            final speed = 500 + age * 900;
            p.vx += (dx / d * speed - p.vx) * (1 - math.exp(-10 * dt));
            p.vy += (dy / d * speed - p.vy) * (1 - math.exp(-10 * dt));
          }
      }
      p.x += p.vx * dt;
      p.y += p.vy * dt;
    }
  }

  @override
  void render(Canvas canvas) {
    final top = game.camTop - 40, bottom = game.camTop + game.size.y + 40;
    for (final p in _pool) {
      if (!p.alive || p.y < top || p.y > bottom) continue;
      final t = (p.life / p.maxLife).clamp(0.0, 1.0);
      switch (p.kind) {
        case _Kind.bubble:
          _stroke
            ..color = p.color.withValues(alpha: p.color.a * t)
            ..strokeWidth = 1.2;
          canvas.drawCircle(Offset(p.x, p.y), p.size, _stroke);
        case _Kind.droplet:
        case _Kind.spark:
          _fill.color = p.color.withValues(alpha: p.color.a * math.min(1, t * 2));
          canvas.drawCircle(Offset(p.x, p.y), p.size * (0.5 + t * 0.5), _fill);
        case _Kind.ring:
          _stroke
            ..color = p.color.withValues(alpha: p.color.a * t)
            ..strokeWidth = 3 * t + 0.5;
          canvas.drawCircle(Offset(p.x, p.y), p.size, _stroke);
        case _Kind.coin:
          // عملة تدور (عرض متغير)
          final w = p.size * (0.35 + 0.65 * math.sin(p.life * 14).abs());
          final r = Rect.fromCenter(center: Offset(p.x, p.y), width: w * 2, height: p.size * 2);
          canvas.drawOval(r, _coinEdge);
          canvas.drawOval(r.deflate(1.4), _coinFace);
          canvas.drawCircle(Offset(p.x - w * 0.3, p.y - p.size * 0.35), p.size * 0.22, _coinShine);
      }
    }
  }
}
