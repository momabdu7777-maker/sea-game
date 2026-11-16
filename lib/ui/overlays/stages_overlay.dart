import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/stage.dart';
import '../../game/sea_hunter_game.dart';
import '../../services/haptics.dart';
import '../../state/player_state.dart';
import '../../state/providers.dart';
import '../theme.dart';
import '../widgets/menu_sheet.dart';

/// شاشة «مراحل البحر العربي»: الأهداف والتقدم، والانتقال بين المراحل المفتوحة.
class StagesOverlay extends ConsumerWidget {
  const StagesOverlay({super.key, required this.game});

  final SeaHunterGame game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(stageCatalogProvider);
    final p = ref.watch(playerProvider);
    final current = ref.watch(currentStageProvider);
    final doneCount = catalog.stages.where((s) => p.completedStages.contains(s.id)).length;

    return MenuSheet(
      title: 'مراحل البحر العربي 🗺️',
      onClose: () => game.closeMenu('stages'),
      header: Row(
        children: [
          Text(
            'أكملت $doneCount من ${catalog.stages.length}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF5C6B7A)),
          ),
          const SizedBox(width: 10),
          Expanded(child: ProgressBar(value: doneCount / catalog.stages.length, color: AppColors.coral, height: 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < catalog.stages.length; i++)
            _StageCard(
              game: game,
              index: i,
              stage: catalog.stages[i],
              player: p,
              isCurrent: catalog.stages[i].id == current.id,
              unlocked: catalog.isUnlocked(catalog.stages[i], p.completedStages),
              previous: i > 0 ? catalog.stages[i - 1] : null,
            ),
          if (doneCount == catalog.stages.length)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFFD54F), Color(0xFFFFB300)]),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                '🏆 أنت سيد البحر العربي! أكملت كل المراحل.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Color(0xFF5D3B00)),
              ),
            ),
        ],
      ),
    );
  }
}

class _StageCard extends ConsumerWidget {
  const _StageCard({
    required this.game,
    required this.index,
    required this.stage,
    required this.player,
    required this.isCurrent,
    required this.unlocked,
    required this.previous,
  });

  final SeaHunterGame game;
  final int index;
  final Stage stage;
  final PlayerState player;
  final bool isCurrent;
  final bool unlocked;
  final Stage? previous;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = player.progressIn(stage.id);
    final completed = player.completedStages.contains(stage.id);
    final fish = ref.read(fishCatalogProvider);
    final lineLen = game.config.lineLengthForLevel(player.lineLevel);
    final needLine = unlocked && !completed && stage.depthGoal > lineLen;

    void go() {
      if (ref.read(playerProvider.notifier).selectStage(stage.id)) {
        Haptics.medium();
        game.closeMenu('stages');
        game.reloadSea();
        game.showBanner('${stage.emoji} ${stage.name}', tone: BannerTone.good, seconds: 1.8);
      }
    }

    final border = isCurrent
        ? AppColors.coral
        : completed
        ? const Color(0xFF2E9D57)
        : const Color(0x1F062B4F);

    final card = Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: unlocked ? Colors.white : const Color(0xFFF1EEE6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: isCurrent ? 2.6 : 1.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: unlocked ? const Color(0xFFE3F4FA) : const Color(0xFFE0DCD2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(unlocked ? stage.emoji : '🔒', style: const TextStyle(fontSize: 30)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'المرحلة ${index + 1}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF5C6B7A)),
                    ),
                    Text(
                      stage.name,
                      style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: AppColors.seaDeep, height: 1.2),
                    ),
                  ],
                ),
              ),
              if (isCurrent)
                const _Badge(text: 'أنت هنا 📍', color: AppColors.coral)
              else if (completed)
                const _Badge(text: 'مكتملة ✓', color: Color(0xFF2E9D57)),
            ],
          ),
          const SizedBox(height: 6),
          Text(stage.subtitle, style: const TextStyle(fontSize: 14.5, height: 1.45, color: Color(0xFF5C6B7A))),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Fact('🌊 القاع ${stage.seabed.round()} م'),
              _Fact(stage.priceMultiplier == 1 ? '🪙 أسعار عادية' : '🪙 الأسعار ×${_mult(stage.priceMultiplier)}'),
              if (stage.obstacleDensity > 1) _Fact('🪼 عوائق أكثر'),
            ],
          ),
          if (unlocked) ...[
            const SizedBox(height: 10),
            const Text(
              'الأهداف',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.seaDeep),
            ),
            for (final g in stage.goals) _GoalRow(goal: g, progress: progress, label: g.label(fish)),
            if (needLine)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '💡 تحتاج خيطاً بطول ${stage.depthGoal} م على الأقل (خيطك ${lineLen.round()} م): طوّره من «تطوير».',
                  style: const TextStyle(fontSize: 13.5, height: 1.4, fontWeight: FontWeight.w700, color: Color(0xFF1C6E9A)),
                ),
              ),
            if (!isCurrent) ...[
              const SizedBox(height: 10),
              BigButton(label: 'اصطد هنا ${stage.emoji}', onTap: go, height: 48, fontSize: 19),
            ],
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                '🔒 أكمل أهداف «${previous?.name}» لتفتح هذه المرحلة.',
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF8A7F6A)),
              ),
            ),
        ],
      ),
    );
    return unlocked ? card : Opacity(opacity: 0.85, child: card);
  }

  static String _mult(double m) => m == m.roundToDouble() ? m.round().toString() : m.toString();
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({required this.goal, required this.progress, required this.label});

  final StageGoal goal;
  final StageProgress progress;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cur = goal.progressIn(progress).clamp(0, goal.target);
    final done = cur >= goal.target;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 22,
            color: done ? const Color(0xFF2E9D57) : const Color(0xFF90A4AE),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: done ? const Color(0xFF2E7D32) : AppColors.ink,
                        ),
                      ),
                    ),
                    Text(
                      '$cur/${goal.target}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF5C6B7A)),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                ProgressBar(value: cur / goal.target, height: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w900),
    ),
  );
}

class _Fact extends StatelessWidget {
  const _Fact(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
    decoration: BoxDecoration(color: const Color(0xFFEFF6F9), borderRadius: BorderRadius.circular(10)),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.seaDeep),
    ),
  );
}
