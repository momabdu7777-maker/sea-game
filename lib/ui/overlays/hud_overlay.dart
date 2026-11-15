import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../game/sea_hunter_game.dart';
import '../../state/providers.dart';
import '../theme.dart';

/// الواجهة فوق اللعب: الريالات، العمق، عدد الأسماك، الرسائل والتلميحات.
class HudOverlay extends StatelessWidget {
  const HudOverlay({super.key, required this.game});

  final SeaHunterGame game;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          const PositionedDirectional(top: 10, start: 12, child: _CoinPill()),
          PositionedDirectional(
            top: 10,
            end: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CatchCounter(game: game),
                const SizedBox(width: 8),
                const _SoundButton(),
              ],
            ),
          ),
          Positioned(
            top: 62,
            left: 0,
            right: 0,
            child: Center(child: _DepthReadout(game: game)),
          ),
          Positioned(
            top: 130,
            left: 16,
            right: 16,
            child: Center(child: _BannerView(game: game)),
          ),
          Positioned(
            bottom: 26,
            left: 16,
            right: 16,
            child: Center(child: _Hints(game: game)),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.child, this.color = const Color(0x8C062B4F)});

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Colors.white24, width: 1.5),
    ),
    child: DefaultTextStyle.merge(
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
      child: child,
    ),
  );
}

class _CoinPill extends ConsumerWidget {
  const _CoinPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coins = ref.watch(playerProvider.select((p) => p.coins));
    return _Pill(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _CoinIcon(),
          const SizedBox(width: 6),
          // العدّاد يعدّ تصاعدياً عند زيادة الرصيد
          TweenAnimationBuilder<double>(
            tween: Tween(end: coins.toDouble()),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => Text('${v.round()}'),
          ),
        ],
      ),
    );
  }
}

class _CoinIcon extends StatelessWidget {
  const _CoinIcon();

  @override
  Widget build(BuildContext context) => Container(
    width: 20,
    height: 20,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.gold,
      border: Border.all(color: const Color(0xFFB8860B), width: 2),
    ),
  );
}

class _SoundButton extends ConsumerWidget {
  const _SoundButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(playerProvider.select((p) => p.soundOn));
    return Material(
      color: const Color(0x8C062B4F),
      shape: const CircleBorder(side: BorderSide(color: Colors.white24, width: 1.5)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => ref.read(playerProvider.notifier).toggleSound(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(on ? Icons.volume_up_rounded : Icons.volume_off_rounded, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _CatchCounter extends StatelessWidget {
  const _CatchCounter({required this.game});

  final SeaHunterGame game;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([game.caughtCount, game.capacity, game.phase]),
      builder: (context, _) {
        final n = game.caughtCount.value, cap = game.capacity.value;
        final full = n >= cap && cap > 0;
        return _Pill(
          color: full ? const Color(0xCC2E7D32) : const Color(0x8C062B4F),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🐟', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 4),
              Text('$n/$cap'),
            ],
          ),
        );
      },
    );
  }
}

class _DepthReadout extends StatelessWidget {
  const _DepthReadout({required this.game});

  final SeaHunterGame game;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([game.phase, game.depthMeters]),
      builder: (context, _) {
        final visible = game.phase.value.isUnderwater;
        return AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 250),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${game.depthMeters.value}',
                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900),
                ),
                const TextSpan(
                  text: ' م',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            style: const TextStyle(
              color: Colors.white,
              height: 1,
              shadows: [Shadow(color: Color(0xAA000000), blurRadius: 8, offset: Offset(0, 2))],
            ),
          ),
        );
      },
    );
  }
}

class _BannerView extends StatelessWidget {
  const _BannerView({required this.game});

  final SeaHunterGame game;

  static Color _color(BannerTone t) => switch (t) {
    BannerTone.info => const Color(0xE6164A7A),
    BannerTone.good => const Color(0xE62E9D57),
    BannerTone.bad => const Color(0xE6D84343),
    BannerTone.epic => const Color(0xE68E44AD),
  };

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GameBanner?>(
      valueListenable: game.banner,
      builder: (context, b, _) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, a) => ScaleTransition(
          scale: CurvedAnimation(parent: a, curve: Curves.elasticOut, reverseCurve: Curves.easeIn),
          child: FadeTransition(opacity: a, child: child),
        ),
        child: b == null
            ? const SizedBox.shrink()
            : Container(
                key: ValueKey(b.id),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                decoration: BoxDecoration(
                  color: _color(b.tone),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 12, offset: Offset(0, 4))],
                ),
                child: Text(
                  b.text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                ),
              ),
      ),
    );
  }
}

class _Hints extends ConsumerWidget {
  const _Hints({required this.game});

  final SeaHunterGame game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final casts = ref.watch(playerProvider.select((p) => p.totalCasts));
    return ListenableBuilder(
      listenable: Listenable.merge([game.phase, game.dragging]),
      builder: (context, _) {
        String? text;
        var pulse = false;
        switch (game.phase.value) {
          case CastPhase.aiming:
            if (!game.dragging.value) {
              text = 'اسحب إصبعك للأسفل ثم أفلت للرمي 🎣';
              pulse = true;
            }
          case CastPhase.descending:
            if (casts < 3) text = 'حرّك إصبعك يميناً ويساراً لتفادي العوائق';
          case CastPhase.ascending:
            if (casts < 3) text = 'التقط الأسماك وأنت صاعد!';
          case CastPhase.surfacing:
            text = 'المس للتخطي';
          default:
            break;
        }
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: text == null ? const SizedBox.shrink() : _HintBubble(key: ValueKey(text), text: text, pulse: pulse),
        );
      },
    );
  }
}

class _HintBubble extends StatefulWidget {
  const _HintBubble({super.key, required this.text, required this.pulse});

  final String text;
  final bool pulse;

  @override
  State<_HintBubble> createState() => _HintBubbleState();
}

class _HintBubbleState extends State<_HintBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() {
    super.initState();
    if (widget.pulse) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(color: const Color(0x99062B4F), borderRadius: BorderRadius.circular(24)),
      child: Text(
        widget.text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
      ),
    );
    if (!widget.pulse) return bubble;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Transform.translate(offset: Offset(0, _c.value * 8), child: child),
      child: bubble,
    );
  }
}
