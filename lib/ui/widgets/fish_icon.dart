import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../art/fish_visual.dart';
import '../../data/fish_species.dart';

/// أيقونة سمكة متحركة لواجهات Flutter (النتيجة، الألبوم لاحقاً) —
/// تستخدم نفس رسم اللعبة عبر [createFishVisual].
class FishIcon extends StatefulWidget {
  const FishIcon({super.key, required this.species, this.width = 64, this.height = 44});

  final FishSpecies species;
  final double width;
  final double height;

  @override
  State<FishIcon> createState() => _FishIconState();
}

class _FishIconState extends State<FishIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  late final FishVisual _visual = createFishVisual(widget.species);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(size: Size(widget.width, widget.height), painter: _FishPainter(_visual, _c)),
  );
}

class _FishPainter extends CustomPainter {
  _FishPainter(this.visual, this.anim) : super(repaint: anim);

  final FishVisual visual;
  final Animation<double> anim;

  @override
  void paint(Canvas canvas, Size size) {
    final k = math.min(size.width * 0.8 / visual.length, size.height * 0.75 / visual.height);
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(k);
    visual.render(canvas, anim.value * 4, swim: 0.6);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FishPainter old) => old.visual != visual;
}
