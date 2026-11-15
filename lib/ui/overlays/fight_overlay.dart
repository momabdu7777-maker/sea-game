import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/cast_result.dart';
import '../../game/sea_hunter_game.dart';
import '../../game/systems/fight_session.dart';
import '../../utils/format.dart';
import '../widgets/fish_icon.dart';

/// واجهة صراع السمكة الكبيرة: شريط التوتر بالمنطقة الخضراء، شريط التقدم،
/// وبطاقة النتيجة ("صدتها!" أو "كانت بيدك!").
///
/// الأشرطة تمتلئ من اليمين لليسار (اتجاه القراءة العربية): الضغط يدفع المؤشر يساراً نحو "شد".
class FightOverlay extends StatelessWidget {
  const FightOverlay({super.key, required this.game});

  final SeaHunterGame game;

  @override
  Widget build(BuildContext context) {
    // اللمس يمر للعبة (الضغط في أي مكان = شد)
    return IgnorePointer(
      child: ValueListenableBuilder<FightSession?>(
        valueListenable: game.fightSession,
        builder: (context, fs, _) {
          if (fs == null) return const SizedBox.shrink();
          return ValueListenableBuilder<FightOutcome?>(
            valueListenable: game.fightOutcome,
            builder: (context, outcome, _) => Stack(
              children: [
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 18,
                  child: SafeArea(
                    top: false,
                    child: AnimatedOpacity(
                      opacity: outcome == null ? 1 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: _SlideIn(
                        child: _FightPanel(session: fs, fish: game.fightCatchPreview, showHelp: game.fightShowHelp),
                      ),
                    ),
                  ),
                ),
                if (outcome != null)
                  Align(
                    alignment: const Alignment(0, 0.15),
                    child: _OutcomeCard(key: ValueKey(outcome), outcome: outcome),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SlideIn extends StatelessWidget {
  const _SlideIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 380),
    curve: Curves.easeOutBack,
    builder: (_, v, c) => Transform.translate(offset: Offset(0, (1 - v) * 160), child: c),
    child: child,
  );
}

class _FightPanel extends StatelessWidget {
  const _FightPanel({required this.session, required this.fish, required this.showHelp});

  final FightSession session;
  final CaughtFish? fish;
  final bool showHelp;

  @override
  Widget build(BuildContext context) {
    final f = fish;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xD9051C33),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white24, width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 16)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (f != null) _FishHeader(fish: f),
          const SizedBox(height: 8),
          SizedBox(height: 46, child: CustomPaint(painter: _TensionPainter(session))),
          const SizedBox(height: 3),
          // التسميات بإحداثيات مطلقة لتطابق الرسم: اليسار = شد، اليمين = إرخاء
          SizedBox(
            height: 18,
            child: Stack(
              children: [
                const Align(alignment: Alignment.centerLeft, child: _Tiny('شد 🔥')),
                const Align(alignment: Alignment.centerRight, child: _Tiny('إرخاء')),
                Align(child: _DangerText(session: session)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(height: 22, child: CustomPaint(painter: _ProgressPainter(session))),
          if (showHelp) ...[
            const SizedBox(height: 8),
            const Text(
              'اضغط باستمرار = شد  •  أفلت = إرخاء\nأبقِ المؤشر الأبيض داخل المنطقة الخضراء!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700, height: 1.35),
            ),
          ],
        ],
      ),
    );
  }
}

class _FishHeader extends StatelessWidget {
  const _FishHeader({required this.fish});

  final CaughtFish fish;

  @override
  Widget build(BuildContext context) {
    final s = fish.species;
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(color: const Color(0x33FFFFFF), borderRadius: BorderRadius.circular(12)),
          child: FishIcon(species: s, width: 58, height: 38),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900, height: 1.1),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                    decoration: BoxDecoration(color: s.rarity.color, borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      s.rarity.arabicName,
                      style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '≈ ${formatKg(fish.weightKg)} كغ',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFFB3E5FC), fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Text(
          '+${fish.value}',
          style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 20, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _Tiny extends StatelessWidget {
  const _Tiny(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w800),
  );
}

class _DangerText extends StatelessWidget {
  const _DangerText({required this.session});

  final FightSession session;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: session,
    builder: (_, _) {
      final d = session.dangerFraction;
      if (session.isIntro) {
        return const Text(
          'استعد...',
          style: TextStyle(color: Color(0xFFFFE082), fontSize: 13, fontWeight: FontWeight.w900),
        );
      }
      if (d < 0.35) return const SizedBox.shrink();
      final blink = 0.55 + 0.45 * math.sin(session.time * 18).abs();
      return Opacity(
        opacity: blink,
        child: const Text(
          '⚠️ الخيط سينقطع!',
          style: TextStyle(color: Color(0xFFFF6B6B), fontSize: 13, fontWeight: FontWeight.w900),
        ),
      );
    },
  );
}

/// شريط التوتر: المسار، المنطقة الخضراء، والمؤشر.
class _TensionPainter extends CustomPainter {
  _TensionPainter(this.s) : super(repaint: s);

  final FightSession s;

  static final _track = Paint()..color = const Color(0xFF0B2A47);
  static final _tightHint = Paint()..color = const Color(0x33FF5252);
  static final _zone = Paint();
  static final _zoneEdge = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  static final _border = Paint()..style = PaintingStyle.stroke;
  static final _needle = Paint();
  static final _needleEdge = Paint()
    ..color = const Color(0xFF0B2A47)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  /// تحويل قيمة الشريط (0..1) لإحداثي x: من اليمين لليسار.
  double _x(double v, double w) => w * (1 - v);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    const pad = 4.0;
    final trackRect = Rect.fromLTWH(0, pad, w, h - pad * 2);
    final track = RRect.fromRectAndRadius(trackRect, const Radius.circular(14));
    canvas.drawRRect(track, _track);

    // تلميح خفيف: طرف "الشد" أحمر قليلاً
    canvas.save();
    canvas.clipRRect(track);
    canvas.drawRect(Rect.fromLTWH(0, pad, w * 0.12, h - pad * 2), _tightHint);

    // المنطقة الخضراء
    final inZone = s.inZone;
    final zl = _x(s.zoneEnd, w), zr = _x(s.zoneStart, w);
    final zoneRect = Rect.fromLTRB(zl, pad, zr, h - pad);
    final pulse = s.isIntro ? 0.5 + 0.5 * math.sin(s.time * 10) : 1.0;
    _zone.color = (inZone ? const Color(0xFF43E07F) : const Color(0xFF2FA862)).withValues(alpha: 0.65 + 0.3 * pulse);
    canvas.drawRRect(RRect.fromRectAndRadius(zoneRect, const Radius.circular(10)), _zone);
    _zoneEdge.color = inZone ? const Color(0xFFB9FFD3) : const Color(0x8843E07F);
    canvas.drawRRect(RRect.fromRectAndRadius(zoneRect.deflate(1), const Radius.circular(10)), _zoneEdge);
    canvas.restore();

    // إطار يومض بالأحمر مع اقتراب الانقطاع
    final d = s.dangerFraction;
    final flash = d <= 0 ? 0.0 : d * (0.55 + 0.45 * math.sin(s.time * 20).abs());
    _border
      ..color = Color.lerp(const Color(0x55FFFFFF), const Color(0xFFFF3D3D), flash)!
      ..strokeWidth = 2 + 2.5 * d;
    canvas.drawRRect(track, _border);

    // المؤشر
    final nx = _x(s.indicator, w).clamp(6.0, w - 6.0);
    final needle = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(nx, h / 2), width: 11, height: h), const Radius.circular(6));
    _needle.color = inZone ? Colors.white : Color.lerp(Colors.white, const Color(0xFFFF8A80), 0.4 + 0.6 * d)!;
    canvas.drawRRect(needle, _needle);
    canvas.drawRRect(needle, _needleEdge);
  }

  @override
  bool shouldRepaint(covariant _TensionPainter old) => old.s != s;
}

/// شريط التقدم: يمتلئ من اليمين، مع صنارة في رأس الامتلاء.
class _ProgressPainter extends CustomPainter {
  _ProgressPainter(this.s) : super(repaint: s);

  final FightSession s;

  static final _track = Paint()..color = const Color(0xFF0B2A47);
  static final _fill = Paint();
  static final _knob = Paint()..color = const Color(0xFFFFFFFF);
  static final _knobEdge = Paint()
    ..color = const Color(0xFFE0A800)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final r = RRect.fromRectAndRadius(Rect.fromLTWH(0, 3, w, h - 6), const Radius.circular(10));
    canvas.drawRRect(r, _track);
    final p = s.progress.clamp(0.0, 1.0);
    if (p > 0) {
      final left = w * (1 - p);
      final fillRect = Rect.fromLTRB(left, 3, w, h - 3);
      _fill.shader = const LinearGradient(colors: [Color(0xFF7CFC9A), Color(0xFFFFD54F)]).createShader(fillRect);
      canvas.save();
      canvas.clipRRect(r);
      canvas.drawRect(fillRect, _fill);
      canvas.restore();
      final kx = left.clamp(h / 2, w - h / 2);
      canvas.drawCircle(Offset(kx, h / 2), h / 2 - 1, _knob);
      canvas.drawCircle(Offset(kx, h / 2), h / 2 - 1, _knobEdge);
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressPainter old) => old.s != s;
}

/// بطاقة نهاية الصراع.
class _OutcomeCard extends StatelessWidget {
  const _OutcomeCard({super.key, required this.outcome});

  final FightOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final f = outcome.fish;
    final won = outcome.won;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.elasticOut,
      builder: (_, v, c) => Transform.scale(scale: 0.4 + 0.6 * v, child: c),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 28),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: won ? const [Color(0xFF2ECC71), Color(0xFF1E8E4E)] : const [Color(0xFFE85959), Color(0xFFA62B2B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white54, width: 2),
          boxShadow: const [BoxShadow(color: Color(0x88000000), blurRadius: 20, offset: Offset(0, 6))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              won ? 'صدتها! 🏆' : 'كانت بيدك! 💔',
              style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Opacity(
              opacity: won ? 1 : 0.85,
              child: FishIcon(species: f.species, width: 130, height: 70),
            ),
            Text(
              '${f.species.name}  •  ${formatKg(f.weightKg)} كغ',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              won ? '+${f.value} ريال' : 'ضاعت عليك ${f.value} ريال!',
              style: TextStyle(color: const Color(0xFFFFE082), fontSize: won ? 24 : 20, fontWeight: FontWeight.w900),
            ),
            if (!won) ...[
              const SizedBox(height: 6),
              const Text(
                'لا تبقَ خارج الأخضر طويلاً — المرة الجاية لك!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
