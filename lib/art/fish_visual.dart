import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show HSLColor;

import '../data/fish_species.dart';

/// واجهة رسم السمكة. أي تمثيل بصري (مؤقت أو صور نهائية) يطبّقها.
///
/// الرسم يكون حول النقطة (0,0) والسمكة متجهة لليمين (+x).
abstract class FishVisual {
  double get length;
  double get height;

  /// [swim] شدة حركة الذيل (0..2) — أعلى عند السرعة.
  void render(Canvas canvas, double time, {double swim = 1});
}

/// نقطة الاستبدال الوحيدة: عند توفر الرسومات النهائية أرجع هنا
/// SpriteFishVisual مثلاً بدلاً من الرسم المؤقت.
FishVisual createFishVisual(FishSpecies species, {double scale = 1}) => PlaceholderFishVisual(species, species.sizePx * scale);

Color _shade(Color c, double lightnessDelta) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness + lightnessDelta).clamp(0.0, 1.0)).toColor();
}

/// رسم كرتوني مسطح مؤقت بأشكال بسيطة وعيون كبيرة مضحكة.
/// كل المسارات والألوان تُحسب مرة واحدة فقط (لأداء 60fps).
class PlaceholderFishVisual implements FishVisual {
  PlaceholderFishVisual(this.species, this.length) : height = length * _heightFactor(species.shape) {
    final s = species;
    _body = Paint()..color = s.bodyColor;
    _belly = Paint()..color = _shade(s.bodyColor, 0.18);
    _accent = Paint()..color = s.accentColor;
    // التونة حدودها زرقاء داكنة (لونها الثانوي أصفر)، وسُمك الحدود محدود للأسماك الضخمة
    _outline = Paint()
      ..color = s.shape == FishShape.tuna ? _shade(s.bodyColor, -0.25) : _shade(s.accentColor, -0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (length * 0.035).clamp(1.3, 3.2)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    _line = Paint()
      ..color = s.accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = (length * 0.045).clamp(1.4, 4.0)
      ..strokeCap = StrokeCap.round;
    _thin = Paint()
      ..color = _shade(s.accentColor, -0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (length * 0.012).clamp(1.0, 2.0)
      ..strokeCap = StrokeCap.round;
    if (s.glow) {
      _glow = Paint()
        ..color = _shade(s.bodyColor, 0.25).withValues(alpha: 0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, length * 0.35);
    }
    _build();
  }

  final FishSpecies species;
  @override
  final double length;
  @override
  final double height;

  late final Paint _body, _belly, _accent, _outline, _line, _thin;
  Paint? _glow;

  // المسارات المحسوبة مسبقاً
  late Path _bodyPath, _tailPath, _finPath, _bellyPath;
  Path? _extraPath; // خطوط/بقع/أجنحة حسب الشكل
  Path? _spotPath; // بقع بيضاء (قرش الحوت)
  late Offset _tailPivot, _eye;
  late double _eyeR;
  final Path _scratch = Path(); // يُعاد استخدامه للأطراف المتحركة

  static double _heightFactor(FishShape s) => switch (s) {
    FishShape.slim => 0.34,
    FishShape.round => 0.62,
    FishShape.long => 0.26,
    FishShape.flyer => 0.3,
    FishShape.grouper => 0.5,
    FishShape.squid => 0.34,
    FishShape.crab => 0.5,
    FishShape.tuna => 0.42,
    FishShape.shark => 0.3,
    FishShape.whaleshark => 0.32,
  };

  static final _white = Paint()..color = const Color(0xFFFFFFFF);
  static final _pupil = Paint()..color = const Color(0xFF1B1B1B);
  static final _toothPaint = Paint()
    ..color = const Color(0xFFFFFFFF)
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.round;
  static final _spot = Paint()..color = const Color(0xE6F5F9FC);

  void _build() {
    final L = length, H = height;
    switch (species.shape) {
      case FishShape.squid:
        // العباءة متجهة للأمام (يمين) والمجسات للخلف
        _bodyPath = Path()
          ..moveTo(L * 0.52, 0)
          ..quadraticBezierTo(L * 0.3, -H * 0.62, -L * 0.08, -H * 0.42)
          ..quadraticBezierTo(-L * 0.16, 0, -L * 0.08, H * 0.42)
          ..quadraticBezierTo(L * 0.3, H * 0.62, L * 0.52, 0)
          ..close();
        _finPath = Path()
          ..moveTo(L * 0.38, -H * 0.2)
          ..lineTo(L * 0.56, -H * 0.62)
          ..lineTo(L * 0.5, -H * 0.05)
          ..moveTo(L * 0.38, H * 0.2)
          ..lineTo(L * 0.56, H * 0.62)
          ..lineTo(L * 0.5, H * 0.05);
        _bellyPath = Path()..addOval(Rect.fromCenter(center: Offset(L * 0.2, H * 0.1), width: L * 0.4, height: H * 0.35));
        _extraPath = Path();
        for (var i = 0; i < 3; i++) {
          _extraPath!.addOval(
            Rect.fromCircle(center: Offset(L * (0.08 + i * 0.12), -H * 0.12 + (i.isEven ? 0 : H * 0.14)), radius: L * 0.025),
          );
        }
        _tailPath = Path();
        _tailPivot = Offset.zero;
        _eye = Offset(-L * 0.06, -H * 0.12);
        _eyeR = math.max(2.6, H * 0.24);
      case FishShape.crab:
        _bodyPath = Path()..addOval(Rect.fromCenter(center: Offset.zero, width: L * 0.72, height: H * 0.8));
        _bellyPath = Path()..addOval(Rect.fromCenter(center: Offset(0, H * 0.14), width: L * 0.5, height: H * 0.4));
        _finPath = Path();
        _tailPath = Path();
        _tailPivot = Offset.zero;
        _extraPath = Path()
          ..addOval(Rect.fromCircle(center: Offset(-L * 0.42, -H * 0.42), radius: L * 0.13))
          ..addOval(Rect.fromCircle(center: Offset(L * 0.42, -H * 0.42), radius: L * 0.13));
        _eye = Offset(L * 0.1, -H * 0.62);
        _eyeR = math.max(2.4, L * 0.075);
      case FishShape.shark:
      case FishShape.whaleshark:
        final whale = species.shape == FishShape.whaleshark;
        // جسم انسيابي بخطم مدبب (أو رأس عريض مسطح لقرش الحوت)
        final nose = whale ? L * 0.47 : L * 0.5;
        _bodyPath = Path()
          ..moveTo(nose, whale ? H * 0.02 : H * 0.08)
          ..cubicTo(L * (whale ? 0.44 : 0.36), -H * (whale ? 0.62 : 0.55), -L * 0.1, -H * 0.55, -L * 0.38, -H * 0.12)
          ..lineTo(-L * 0.38, H * 0.1)
          ..cubicTo(-L * 0.1, H * 0.55, L * (whale ? 0.42 : 0.3), H * 0.52, nose, whale ? H * 0.02 : H * 0.08)
          ..close();
        _bellyPath = Path()..addOval(Rect.fromCenter(center: Offset(L * 0.1, H * 0.26), width: L * 0.62, height: H * 0.36));
        _tailPivot = Offset(-L * 0.36, 0);
        // ذيل غير متماثل: الفص العلوي أطول
        _tailPath = Path()
          ..moveTo(0, -H * 0.1)
          ..lineTo(-L * 0.2, -H * 1.0)
          ..quadraticBezierTo(-L * 0.08, -H * 0.1, -L * 0.13, H * 0.6)
          ..lineTo(0, H * 0.1)
          ..close();
        // زعنفة ظهرية مثلثة + زعنفة صدرية
        _finPath = Path()
          ..moveTo(-L * 0.04, -H * 0.42)
          ..lineTo(L * 0.05, -H * 1.1)
          ..quadraticBezierTo(L * 0.09, -H * 0.62, L * 0.2, -H * 0.4)
          ..close()
          ..moveTo(L * 0.16, H * 0.25)
          ..lineTo(L * 0.02, H * 0.95)
          ..lineTo(L * 0.27, H * 0.3)
          ..close();
        _extraPath = Path();
        // فتحات الخياشيم
        for (var i = 0; i < (whale ? 4 : 3); i++) {
          final x = L * (0.26 - i * 0.035);
          _extraPath!
            ..moveTo(x, -H * 0.16)
            ..quadraticBezierTo(x - L * 0.015, 0, x - L * 0.005, H * 0.16);
        }
        if (whale) {
          // بقع بيضاء منتظمة تقريباً
          _spotPath = Path();
          final r = math.Random(7);
          for (var i = 0; i < 26; i++) {
            final x = -L * 0.32 + r.nextDouble() * L * 0.72;
            final top = -H * 0.42 * (1 - (x / L).abs() * 0.9);
            final y = top + r.nextDouble() * H * 0.45;
            _spotPath!.addOval(Rect.fromCircle(center: Offset(x, y), radius: H * (0.035 + r.nextDouble() * 0.03)));
          }
        }
        _eye = Offset(L * (whale ? 0.38 : 0.33), -H * (whale ? 0.02 : 0.1));
        _eyeR = math.max(2.4, H * (whale ? 0.12 : 0.15));
      default:
        final bodyW = L * (species.shape == FishShape.long ? 0.82 : 0.76);
        final cx = L * 0.08;
        _bodyPath = Path()
          ..moveTo(cx + bodyW / 2, H * 0.04)
          ..cubicTo(cx + bodyW * 0.42, -H * 0.62, cx - bodyW * 0.3, -H * 0.62, cx - bodyW / 2, 0)
          ..cubicTo(cx - bodyW * 0.3, H * 0.6, cx + bodyW * 0.42, H * 0.56, cx + bodyW / 2, H * 0.04)
          ..close();
        _bellyPath = Path()..addOval(Rect.fromCenter(center: Offset(cx + bodyW * 0.06, H * 0.2), width: bodyW * 0.62, height: H * 0.42));
        _tailPivot = Offset(cx - bodyW / 2 + L * 0.03, 0);
        final tl = L * 0.24, th = H * (species.shape == FishShape.round ? 0.42 : 0.55);
        final forked = species.shape == FishShape.long || species.shape == FishShape.flyer || species.shape == FishShape.tuna;
        _tailPath = Path()
          ..moveTo(0, 0)
          ..lineTo(-tl, -th)
          ..quadraticBezierTo(-tl * (forked ? 0.45 : 0.8), 0, -tl, th)
          ..close();
        final finX = cx - bodyW * 0.05;
        _finPath = Path()
          ..moveTo(finX - bodyW * 0.22, -H * 0.38)
          ..quadraticBezierTo(finX - bodyW * 0.05, -H * (species.shape == FishShape.grouper ? 0.75 : 0.85), finX + bodyW * 0.18, -H * 0.42)
          ..close();
        _eye = Offset(cx + bodyW * 0.3, -H * 0.1);
        _eyeR = math.max(2.4, H * (species.shape == FishShape.round ? 0.15 : 0.19));
        switch (species.shape) {
          case FishShape.long: // خطوط عمودية مثل الكنعد
            _extraPath = Path();
            for (var i = 0; i < 5; i++) {
              final x = cx - bodyW * 0.3 + i * bodyW * 0.12;
              _extraPath!
                ..moveTo(x, -H * 0.36)
                ..lineTo(x - L * 0.02, -H * 0.05);
            }
          case FishShape.grouper: // بقع
            _extraPath = Path();
            final r = math.Random(species.id.hashCode);
            for (var i = 0; i < 7; i++) {
              _extraPath!.addOval(
                Rect.fromCircle(
                  center: Offset(cx + (r.nextDouble() - 0.6) * bodyW * 0.7, (r.nextDouble() - 0.6) * H * 0.6),
                  radius: H * (0.05 + r.nextDouble() * 0.04),
                ),
              );
            }
          case FishShape.flyer: // جناح صدري كبير
            _extraPath = Path()
              ..moveTo(cx + bodyW * 0.1, 0)
              ..quadraticBezierTo(cx - bodyW * 0.25, -H * 1.5, cx - bodyW * 0.55, -H * 0.9)
              ..quadraticBezierTo(cx - bodyW * 0.2, -H * 0.3, cx + bodyW * 0.1, 0)
              ..close();
          case FishShape.tuna: // زعانف صغيرة صفراء قرب الذيل + زعنفة ظهرية طويلة
            _extraPath = Path();
            for (var i = 0; i < 4; i++) {
              final x = cx - bodyW * 0.2 - i * bodyW * 0.065;
              final yTop = -H * (0.36 - i * 0.06), yBot = H * (0.34 - i * 0.06);
              _extraPath!
                ..moveTo(x + L * 0.02, yTop + H * 0.06)
                ..lineTo(x - L * 0.005, yTop - H * 0.1)
                ..lineTo(x - L * 0.02, yTop + H * 0.06)
                ..close()
                ..moveTo(x + L * 0.02, yBot - H * 0.06)
                ..lineTo(x - L * 0.005, yBot + H * 0.1)
                ..lineTo(x - L * 0.02, yBot - H * 0.06)
                ..close();
            }
            _extraPath!
              ..moveTo(cx + bodyW * 0.05, H * 0.35)
              ..quadraticBezierTo(cx - bodyW * 0.05, H * 0.95, cx - bodyW * 0.12, H * 0.38)
              ..close();
          case FishShape.slim: // خط فضي على الظهر
            _extraPath = Path()
              ..moveTo(cx - bodyW * 0.35, -H * 0.05)
              ..quadraticBezierTo(cx, -H * 0.22, cx + bodyW * 0.32, -H * 0.12);
          default:
            _extraPath = null;
        }
    }
  }

  @override
  void render(Canvas canvas, double time, {double swim = 1}) {
    final L = length, H = height;
    if (_glow != null) canvas.drawCircle(Offset.zero, L * 0.5, _glow!);

    switch (species.shape) {
      case FishShape.squid:
        _renderSquid(canvas, time, swim);
        return;
      case FishShape.crab:
        _renderCrab(canvas, time, swim);
        return;
      default:
        break;
    }

    // الذيل يهتز حسب سرعة السباحة
    final wag = math.sin(time * (8 + 6 * swim)) * 0.32 * swim.clamp(0.3, 1.6);
    canvas.save();
    canvas.translate(_tailPivot.dx, _tailPivot.dy);
    canvas.rotate(wag);
    canvas.drawPath(_tailPath, _accent);
    canvas.drawPath(_tailPath, _outline);
    canvas.restore();

    canvas.drawPath(_finPath, _accent);
    canvas.drawPath(_finPath, _outline);
    if (species.shape == FishShape.flyer && _extraPath != null) {
      canvas.drawPath(_extraPath!, _accent);
      canvas.drawPath(_extraPath!, _outline);
    }
    canvas.drawPath(_bodyPath, _body);
    canvas.drawPath(_bellyPath, _belly);
    if (_extraPath != null) {
      switch (species.shape) {
        case FishShape.long:
        case FishShape.slim:
          canvas.drawPath(_extraPath!, _line);
        case FishShape.grouper:
          canvas.drawPath(_extraPath!, _accent);
        case FishShape.tuna:
          canvas.drawPath(_extraPath!, _accent); // زعانف صغيرة صفراء بلا حدود (أوضح)
        case FishShape.shark:
        case FishShape.whaleshark:
          canvas.drawPath(_extraPath!, _thin); // خياشيم رفيعة
        default:
          break;
      }
    }
    if (_spotPath != null) canvas.drawPath(_spotPath!, _spot);
    canvas.drawPath(_bodyPath, _outline);

    _renderEye(canvas, _eye, _eyeR, time);
    // فم صغير مبتسم/متفاجئ
    final mouth = Offset(_eye.dx + _eyeR * 1.5, H * 0.12);
    if (species.shape == FishShape.shark) {
      // ابتسامة واسعة بأسنان
      final m = Rect.fromCenter(center: Offset(L * 0.36, H * 0.16), width: L * 0.16, height: H * 0.26);
      canvas.drawArc(m, 0.25, 2.4, false, _outline);
      for (var i = 0; i < 4; i++) {
        final x = L * (0.31 + i * 0.022);
        canvas.drawLine(Offset(x, H * 0.27), Offset(x + L * 0.006, H * 0.21), _toothPaint);
      }
    } else if (species.shape == FishShape.whaleshark) {
      // فم عريض مسطح وابتسامة هادئة
      canvas.drawArc(Rect.fromCenter(center: Offset(L * 0.42, H * 0.12), width: L * 0.1, height: H * 0.18), 0.1, 1.6, false, _outline);
    } else if (species.shape == FishShape.grouper) {
      canvas.drawArc(
        Rect.fromCenter(center: mouth.translate(-_eyeR * 0.4, 0), width: _eyeR * 2.4, height: _eyeR * 1.6),
        0.3,
        2.2,
        false,
        _outline,
      );
    } else {
      canvas.drawCircle(mouth, math.max(1, _eyeR * 0.28), _outline);
    }
  }

  void _renderEye(Canvas canvas, Offset c, double r, double time) {
    // رمشة عين كل بضع ثوان تعطي حياة للسمكة
    final blink = (time + species.id.length * 0.7) % 3.7 < 0.1;
    if (blink) {
      canvas.drawLine(c.translate(-r, 0), c.translate(r, 0), _outline);
      return;
    }
    canvas.drawCircle(c, r, _white);
    canvas.drawCircle(c, r, _outline);
    canvas.drawCircle(c.translate(r * 0.3, r * 0.1), r * 0.52, _pupil);
    canvas.drawCircle(c.translate(r * 0.45, -r * 0.15), r * 0.18, _white);
  }

  void _renderSquid(Canvas canvas, double time, double swim) {
    final L = length, H = height;
    // مجسات متموجة
    for (var i = 0; i < 6; i++) {
      final y0 = (i - 2.5) * H * 0.12;
      final w = math.sin(time * 7 + i * 0.9) * H * 0.25;
      _scratch
        ..reset()
        ..moveTo(-L * 0.08, y0)
        ..quadraticBezierTo(-L * 0.3, y0 + w, -L * (0.42 + (i % 2) * 0.08), y0 * 1.4 - w * 0.5);
      canvas.drawPath(_scratch, _line);
    }
    canvas.drawPath(_finPath, _accent);
    canvas.drawPath(_bodyPath, _body);
    canvas.drawPath(_bellyPath, _belly);
    canvas.drawPath(_extraPath!, _accent);
    canvas.drawPath(_bodyPath, _outline);
    _renderEye(canvas, _eye, _eyeR, time);
  }

  void _renderCrab(Canvas canvas, double time, double swim) {
    final L = length, H = height;
    // أرجل تمشي
    for (var side = -1; side <= 1; side += 2) {
      for (var i = 0; i < 3; i++) {
        final phase = math.sin(time * 10 + i * 1.3 + (side > 0 ? math.pi : 0)) * H * 0.12;
        final bx = side * L * (0.18 + i * 0.07);
        canvas.drawLine(Offset(bx, H * 0.15), Offset(side * L * (0.38 + i * 0.06), H * 0.45 + phase), _line);
      }
    }
    // الكلّابات
    final snap = math.sin(time * 4) * 0.08;
    canvas.save();
    canvas.rotate(snap);
    canvas.drawPath(_extraPath!, _body);
    canvas.drawPath(_extraPath!, _outline);
    canvas.restore();
    canvas.drawPath(_bodyPath, _body);
    canvas.drawPath(_bellyPath, _belly);
    canvas.drawPath(_bodyPath, _outline);
    // عيون على سيقان
    for (final dx in [-L * 0.1, L * 0.1]) {
      final e = Offset(dx, _eye.dy);
      canvas.drawLine(Offset(dx, -H * 0.3), e, _outline);
      _renderEye(canvas, e, _eyeR, time);
    }
    canvas.drawArc(Rect.fromCenter(center: Offset(0, -H * 0.05), width: L * 0.16, height: H * 0.2), 0.3, 2.5, false, _outline);
  }
}
