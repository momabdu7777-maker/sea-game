import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../sea_hunter_game.dart';

/// القارب الخشبي والصياد الحضرمي والصنارة (رسم مؤقت).
///
/// يُرسم بإحداثيات العالم مباشرة حتى يبقى طرف الصنارة [rodTip] دقيقاً.
class Boat extends Component with HasGameReference<SeaHunterGame> {
  Boat() : super(priority: 5);

  /// انحناء الصنارة للخلف أثناء السحب (0..1).
  double bend = 0;
  double _shownBend = 0;
  double _t = 0;

  final Vector2 _tip = Vector2.zero();
  final Path _hull = Path();
  final Path _rod = Path();

  static final _wood = Paint()..color = const Color(0xFF9C5B2E);
  static final _woodDark = Paint()..color = const Color(0xFF7A4321);
  static final _stripe = Paint()
    ..color = const Color(0xFFF2C14E)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5;
  static final _outline = Paint()
    ..color = const Color(0xFF4E2A12)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.2
    ..strokeJoin = StrokeJoin.round;
  static final _skin = Paint()..color = const Color(0xFFC98B5B);
  static final _shirt = Paint()..color = const Color(0xFFF5F1E6);
  static final _futa = Paint()..color = const Color(0xFF2E7D6B);
  static final _futaLine = Paint()
    ..color = const Color(0xFF1B4D42)
    ..strokeWidth = 1.6;
  static final _mustache = Paint()
    ..color = const Color(0xFF2B1B10)
    ..strokeWidth = 1.8
    ..strokeCap = StrokeCap.round;
  static final _turban = Paint()..color = const Color(0xFFEDE4CF);
  static final _turbanStripe = Paint()
    ..color = const Color(0xFFC0392B)
    ..strokeWidth = 2.4;
  static final _dark = Paint()..color = const Color(0xFF2B1B10);
  static final _arm = Paint()
    ..color = const Color(0xFFC98B5B)
    ..strokeWidth = 4.5
    ..strokeCap = StrokeCap.round;
  static final _rodPaint = Paint()
    ..color = const Color(0xFF5D3A1A)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round;
  static final _reel = Paint()..color = const Color(0xFF37474F);

  double get _bx => game.size.x * 0.72;
  double get _bob => math.sin(_t * 1.6) * 3;
  double get _tilt => math.sin(_t * 1.1) * 0.035;

  Offset get _hand => Offset(_bx - 24, -44 + _bob);

  /// طرف الصنارة بإحداثيات العالم — منه يخرج الخيط.
  Vector2 get rodTip {
    final hand = _hand;
    final restX = game.size.x * 0.47 - hand.dx;
    const restY = -150.0;
    final dy = restY - hand.dy;
    final len = math.sqrt(restX * restX + dy * dy);
    final a = math.atan2(dy, restX) + _shownBend * 1.15;
    _tip.setValues(hand.dx + math.cos(a) * len, hand.dy + math.sin(a) * len);
    return _tip;
  }

  @override
  void update(double dt) {
    _t += dt;
    // الصنارة ترجع بسرعة عند الإفلات (إحساس النابض)
    final k = bend > _shownBend ? 20.0 : 26.0;
    _shownBend += (bend - _shownBend) * (1 - math.exp(-k * dt));
  }

  @override
  void render(Canvas canvas) {
    if (!game.isVisibleY(0, 260)) return;
    final bx = _bx, by = _bob;

    // ---- الصياد ----
    final fx = bx - 10;
    canvas.drawRRect(RRect.fromLTRBR(fx - 11, by - 36, fx + 9, by - 12, const Radius.circular(3)), _futa);
    for (var i = 0; i < 3; i++) {
      canvas.drawLine(Offset(fx - 11, by - 30 + i * 7), Offset(fx + 9, by - 30 + i * 7), _futaLine);
    }
    canvas.drawRRect(RRect.fromLTRBR(fx - 12, by - 58, fx + 10, by - 34, const Radius.circular(7)), _shirt);
    canvas.drawCircle(Offset(fx - 1, by - 68), 10, _skin);
    // العمامة الحضرمية
    canvas.drawOval(Rect.fromCenter(center: Offset(fx - 1, by - 76), width: 24, height: 11), _turban);
    canvas.drawLine(Offset(fx - 12, by - 75), Offset(fx + 10, by - 77), _turbanStripe);
    // وجه بسيط: عين وشارب
    canvas.drawCircle(Offset(fx - 6, by - 69), 1.4, _dark);
    canvas.drawLine(Offset(fx - 9, by - 63), Offset(fx - 3, by - 63), _mustache);

    // ---- الصنارة ----
    final hand = _hand;
    final tip = rodTip;
    final dx = tip.x - hand.dx, dy = tip.y - hand.dy;
    final butt = Offset(hand.dx - dx * 0.12, hand.dy - dy * 0.12);
    // انحناء الصنارة: نقطة تحكم منحرفة عمودياً على اتجاهها
    final bendAmt = 10 + _shownBend * 34;
    final len = math.max(1.0, math.sqrt(dx * dx + dy * dy));
    final ctrl = Offset(hand.dx + dx * 0.55 - dy / len * bendAmt, hand.dy + dy * 0.55 + dx / len * bendAmt);
    _rod
      ..reset()
      ..moveTo(butt.dx, butt.dy)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, tip.x, tip.y);
    canvas.drawPath(_rod, _rodPaint);
    canvas.drawCircle(hand.translate(-dx * 0.03, -dy * 0.03 + 4), 4.5, _reel);
    canvas.drawLine(Offset(fx - 6, by - 50), hand, _arm);

    // ---- القارب (يتمايل) ----
    canvas.save();
    canvas.translate(bx, by);
    canvas.rotate(_tilt);
    _hull
      ..reset()
      ..moveTo(-66, -14)
      ..lineTo(70, -22)
      ..quadraticBezierTo(54, 16, 22, 18)
      ..lineTo(-46, 18)
      ..quadraticBezierTo(-62, 10, -66, -14)
      ..close();
    canvas.drawPath(_hull, _wood);
    canvas.drawRect(const Rect.fromLTRB(-50, 6, 40, 18), _woodDark);
    canvas.drawLine(const Offset(-63, -9), const Offset(64, -17), _stripe);
    canvas.drawPath(_hull, _outline);
    canvas.restore();
  }
}
