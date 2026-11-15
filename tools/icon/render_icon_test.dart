// يرسم أيقونة اللعبة (1024×1024) برسم الأسماك نفسه المستخدم داخل اللعبة.
// التشغيل:  flutter test tools/icon/render_icon_test.dart
// ثم:       python3 tools/icon/make_icons.py   (يولّد كل المقاسات لأندرويد والويب)
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sea_hunter/art/fish_visual.dart';
import 'package:sea_hunter/data/fish_species.dart';

/// [b] = هامش إضافي حول المشهد (للأيقونات التكيّفية التي يقصّ النظام أطرافها).
void paintIcon(Canvas c, double s, FishSpecies tuna, {double b = 0}) {
  final horizon = s * 0.34;
  // السماء
  c.drawRect(
    Rect.fromLTRB(-b, -b, s + b, horizon + 4),
    Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, horizon), const [Color(0xFF5FBDEB), Color(0xFFD4F1FC)]),
  );
  // الشمس
  final sun = Offset(s * 0.24, s * 0.16);
  c.drawCircle(sun, s * 0.12, Paint()..color = const Color(0x55FFE9A0));
  c.drawCircle(sun, s * 0.075, Paint()..color = const Color(0xFFFFD54F));
  // البحر
  final water = Path()..moveTo(-b, horizon);
  for (var x = -b; x <= s + b; x += 4) {
    water.lineTo(x, horizon + math.sin(x / s * math.pi * 4) * s * 0.012);
  }
  water
    ..lineTo(s + b, s + b)
    ..lineTo(-b, s + b)
    ..close();
  c.drawPath(
    water,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, horizon),
        Offset(0, s + b),
        const [Color(0xFF2EC4D6), Color(0xFF1279B8), Color(0xFF0A3A6B)],
        const [0, 0.45, 1],
      ),
  );
  // رغوة السطح
  final foam = Path();
  for (var x = -b; x <= s + b; x += 4) {
    final y = horizon + math.sin(x / s * math.pi * 4) * s * 0.012;
    x == -b ? foam.moveTo(x, y) : foam.lineTo(x, y);
  }
  c.drawPath(
    foam,
    Paint()
      ..color = const Color(0xE6FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.014,
  );
  // أشعة الضوء تحت الماء
  final ray = Paint()..color = const Color(0x1AFFFFFF);
  for (var i = 0; i < 3; i++) {
    final x = s * (0.18 + i * 0.3);
    c.drawPath(
      Path()
        ..moveTo(x - s * 0.03, horizon)
        ..lineTo(x + s * 0.03, horizon)
        ..lineTo(x + s * 0.14 + b * 0.2, s + b)
        ..lineTo(x - s * 0.02 + b * 0.05, s + b)
        ..close(),
      ray,
    );
  }

  // السمكة
  final visual = createFishVisual(tuna);
  final scale = s * 0.6 / visual.length;
  final center = Offset(s * 0.47, s * 0.64);
  const angle = -0.42;
  final mouthLocal = Offset(visual.length * 0.5, visual.height * 0.04) * scale;
  final mouth =
      Offset(-s * 0.029, s * 0.04) + // تصحيح بصري ليقع الخطاف في الفم تماماً
      center +
      Offset(
        mouthLocal.dx * math.cos(angle) - mouthLocal.dy * math.sin(angle),
        mouthLocal.dx * math.sin(angle) + mouthLocal.dy * math.cos(angle),
      );

  // الخيط من الأعلى حتى فم السمكة
  c.drawLine(
    Offset(mouth.dx + s * 0.05 + b * 0.06, -b),
    mouth + Offset(s * 0.012, -s * 0.05),
    Paint()
      ..color = const Color(0xF2FFFFFF)
      ..strokeWidth = s * 0.008,
  );
  // الخطاف
  c.drawArc(
    Rect.fromCircle(center: mouth + Offset(s * 0.0, -s * 0.012), radius: s * 0.026),
    -0.3,
    math.pi * 1.25,
    false,
    Paint()
      ..color = const Color(0xFFE0E6EC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.013
      ..strokeCap = StrokeCap.round,
  );

  c.save();
  c.translate(center.dx, center.dy);
  c.rotate(angle);
  c.scale(scale);
  visual.render(c, 0.6, swim: 0.9);
  c.restore();

  // فقاعات
  final bubble = Paint()
    ..color = const Color(0xB3FFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = s * 0.006;
  for (final b in const [(0.1, 0.9, 0.022), (0.07, 0.79, 0.013), (0.86, 0.9, 0.018), (0.92, 0.8, 0.011)]) {
    c.drawCircle(Offset(s * b.$1, s * b.$2), s * b.$3, bubble);
  }
}

Future<void> _render(FishSpecies tuna, String path, {double bleed = 0}) async {
  const s = 1024.0;
  final b = s * bleed;
  final size = (s + 2 * b).round();
  final rec = ui.PictureRecorder();
  final c = Canvas(rec)..translate(b, b);
  paintIcon(c, s, tuna, b: b);
  final img = await rec.endRecording().toImage(size, size);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  test('render icon', () async {
    final catalog = FishCatalog.parse(File('assets/data/fish.json').readAsStringSync());
    final tuna = catalog.byId('tuna')!;
    await _render(tuna, 'tools/icon/icon-1024.png');
    // أندرويد التكيّفي: 108dp والجزء المرئي ~72dp ⇒ هامش 25% من كل جهة
    await _render(tuna, 'tools/icon/icon-bleed-1536.png', bleed: 0.25);
  });
}
