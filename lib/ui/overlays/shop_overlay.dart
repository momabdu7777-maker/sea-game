import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/upgrades.dart';
import '../../game/sea_hunter_game.dart';
import '../../services/game_audio.dart';
import '../../services/haptics.dart';
import '../../state/providers.dart';
import '../theme.dart';
import '../widgets/menu_sheet.dart';

/// شاشة «تطوير العدة»: شراء الترقيات بالريالات.
class ShopOverlay extends ConsumerWidget {
  const ShopOverlay({super.key, required this.game});

  final SeaHunterGame game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coins = ref.watch(playerProvider.select((p) => p.coins));
    final stage = ref.watch(currentStageProvider);
    final lineLen = game.config.lineLengthForLevel(ref.watch(playerProvider.select((p) => p.lineLevel)));
    final needLine = stage.depthGoal > 0 && lineLen < stage.depthGoal;

    void close() {
      game.closeMenu('shop');
      game.reloadSea();
    }

    return MenuSheet(
      title: 'تطوير العدة 🛠️',
      onClose: close,
      header: Row(
        children: [
          const Text(
            'رصيدك:',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF5C6B7A)),
          ),
          const SizedBox(width: 6),
          TweenAnimationBuilder<double>(
            tween: Tween(end: coins.toDouble()),
            duration: const Duration(milliseconds: 500),
            builder: (_, v, _) => Text(
              '${v.round()} ريال',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFFC77700)),
            ),
          ),
        ],
      ),
      footer: BigButton(label: 'رجوع للصيد 🎣', onTap: close, height: 54, fontSize: 21),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (needLine)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFFE3F4FA), borderRadius: BorderRadius.circular(14)),
              child: Text(
                '💡 هدف «${stage.name}»: الوصول إلى عمق ${stage.depthGoal} م، وخيطك الآن ${lineLen.round()} م فقط.',
                style: const TextStyle(fontSize: 15, height: 1.45, fontWeight: FontWeight.w700, color: AppColors.seaDeep),
              ),
            ),
          for (final u in Upgrade.values) _UpgradeCard(game: game, upgrade: u),
        ],
      ),
    );
  }
}

class _UpgradeCard extends ConsumerWidget {
  const _UpgradeCard({required this.game, required this.upgrade});

  final SeaHunterGame game;
  final Upgrade upgrade;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(playerProvider);
    final u = upgrade;
    final level = u.levelOf(p);
    final cost = u.nextCost(p);
    final maxed = cost == null;
    final affordable = u.canAfford(p);
    final c = game.config;

    void buy() {
      if (ref.read(playerProvider.notifier).buyUpgrade(u)) {
        game.audio.play(Sfx.coin);
        game.audio.play(Sfx.fanfare, volume: 0.45);
        Haptics.medium();
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: affordable ? const Color(0xFF2E9D57) : const Color(0x1F062B4F), width: affordable ? 2.2 : 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: const Color(0xFFE3F4FA), borderRadius: BorderRadius.circular(14)),
                child: Text(u.emoji, style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      u.name,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.seaDeep),
                    ),
                    const SizedBox(height: 4),
                    _LevelDots(level: level, max: u.maxLevel),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // الأثر: الآن ← بعد التطوير
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(12)),
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'الآن: '),
                  TextSpan(
                    text: u.effectAt(c, level),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  if (!maxed) ...[
                    const TextSpan(text: '   بعد التطوير: '),
                    TextSpan(
                      text: u.effectAt(c, level + 1),
                      style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1B5E20)),
                    ),
                  ],
                ],
              ),
              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: Color(0xFF2E7D32)),
            ),
          ),
          const SizedBox(height: 6),
          Text(u.description, style: const TextStyle(fontSize: 14.5, height: 1.45, color: Color(0xFF5C6B7A))),
          const SizedBox(height: 10),
          if (maxed)
            Container(
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(14)),
              child: const Text(
                'أقصى مستوى ✓',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF2E7D32)),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: BigButton(label: 'طوّر  •  $cost ريال', onTap: affordable ? buy : null, height: 48, fontSize: 19),
                ),
                if (!affordable) ...[
                  const SizedBox(width: 10),
                  Text(
                    'ينقصك ${cost - p.coins}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFFB23B3B)),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _LevelDots extends StatelessWidget {
  const _LevelDots({required this.level, required this.max});

  final int level;
  final int max;

  @override
  Widget build(BuildContext context) => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    runSpacing: 2,
    children: [
      for (var i = 0; i < max; i++)
        Container(
          width: 12,
          height: 8,
          margin: const EdgeInsetsDirectional.only(end: 3),
          decoration: BoxDecoration(
            color: i < level ? AppColors.coral : const Color(0x22062B4F),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      const SizedBox(width: 4),
      Text(
        'المستوى $level/$max',
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF5C6B7A)),
      ),
    ],
  );
}
