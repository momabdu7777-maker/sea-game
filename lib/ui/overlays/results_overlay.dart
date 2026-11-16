import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/cast_result.dart';
import '../../data/upgrades.dart';
import '../../game/sea_hunter_game.dart';
import '../../state/providers.dart';
import '../theme.dart';
import '../widgets/fish_icon.dart';
import '../../utils/format.dart';

/// شاشة نتيجة الرمية مع زر "رمية جديدة" الكبير.
class ResultsOverlay extends ConsumerStatefulWidget {
  const ResultsOverlay({super.key, required this.game});

  final SeaHunterGame game;

  @override
  ConsumerState<ResultsOverlay> createState() => _ResultsOverlayState();
}

class _ResultsOverlayState extends ConsumerState<ResultsOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  bool _leaving = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _newCast() async {
    if (_leaving) return;
    _leaving = true;
    await _c.animateBack(0, duration: const Duration(milliseconds: 220), curve: Curves.easeIn);
    widget.game.newCast();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.game.lastResult!;
    final slide = CurvedAnimation(
      parent: _c,
      curve: const Interval(0, 0.55, curve: Curves.easeOutBack),
    );
    return Stack(
      children: [
        FadeTransition(
          opacity: CurvedAnimation(parent: _c, curve: const Interval(0, 0.3)),
          child: const ColoredBox(color: Color(0x88021428), child: SizedBox.expand()),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(slide),
            child: _panel(context, r),
          ),
        ),
      ],
    );
  }

  Widget _panel(BuildContext context, CastResult r) {
    final maxH = MediaQuery.sizeOf(context).height * 0.8;
    final title = r.fightsWon > 0
        ? 'صيد عظيم! 🏆'
        : r.fish.isEmpty
        ? (r.lost.isNotEmpty ? 'كانت بيدك! 💔' : 'رجعت الصنارة فاضية!')
        : (r.fish.length >= widget.game.capacity.value ? 'صنارة ملآنة! 🔥' : 'صيد موفّق!');
    // الأسماك المصطادة ثم التي ضاعت (بعنوان فاصل)
    final rows = <Widget>[
      for (final f in r.fish) _FishRow(fish: f),
      if (r.lost.isNotEmpty) const _LostHeader(),
      for (final f in r.lost) _FishRow(fish: f, lost: true),
    ];
    final subtitle = r.end == DescentEnd.hitObstacle
        ? 'اصطدمت بـ${r.obstacleName} على عمق ${r.maxDepth.round()} م'
        : 'نزلت إلى عمق ${r.maxDepth.round()} م';

    return Container(
      constraints: BoxConstraints(maxHeight: maxH, maxWidth: 520),
      decoration: const BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Color(0x66000000), blurRadius: 24)],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.seaDeep),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: Color(0xFF5C6B7A), fontWeight: FontWeight.w600),
              ),
              if (r.completedStage) ...[const SizedBox(height: 12), _staggered(0, _StageCompleteBanner(result: r))],
              if (!r.completedStage && r.newGoals.isNotEmpty) ...[const SizedBox(height: 10), _staggered(0, _GoalsBanner(result: r))],
              if (r.hasNewSpecies) ...[const SizedBox(height: 12), _staggered(0, const _NewAlbumBanner())],
              const SizedBox(height: 12),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    'لا بأس! حرّك الصنارة نحو الأسماك وأنت صاعد،\nوتفادَ القناديل في النزول لتصل أعمق.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, height: 1.5, color: AppColors.ink),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _staggered(i + 1, rows[i]),
                  ),
                ),
              const SizedBox(height: 14),
              _staggered(
                rows.length + 1,
                Row(
                  children: [
                    const Text('المجموع', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    // الرقم والعملة في عنصرين حتى لا ينقلب «+» في النص العربي
                    Text(
                      plus(r.totalValue),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFFC77700)),
                    ),
                    const Text(
                      ' ريال',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFFC77700)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _staggered(rows.length + 2, _MenuRow(game: widget.game)),
              const SizedBox(height: 10),
              _BigButton(label: 'رمية جديدة 🎣', onTap: _newCast),
            ],
          ),
        ),
      ),
    );
  }

  /// ظهور متتابع للعناصر.
  Widget _staggered(int index, Widget child) {
    final start = (0.3 + index * 0.08).clamp(0.0, 0.85);
    final a = CurvedAnimation(
      parent: _c,
      curve: Interval(start, (start + 0.3).clamp(0.0, 1.0), curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween(begin: const Offset(0.15, 0), end: Offset.zero).animate(a),
        child: child,
      ),
    );
  }
}

/// «أكملت المرحلة!» مع اسم المرحلة التي فُتحت.
class _StageCompleteBanner extends ConsumerWidget {
  const _StageCompleteBanner({required this.result});

  final CastResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(stageCatalogProvider);
    final stage = catalog.byId(result.stageId);
    final next = catalog.next(stage);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF43C46B), Color(0xFF2E9D57)]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            '🎉 أكملت «${stage.name}»!',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Colors.white),
          ),
          const SizedBox(height: 2),
          Text(
            next == null ? '🏆 أنت سيد البحر العربي!' : 'فُتحت مرحلة جديدة: ${next.emoji} ${next.name}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// الأهداف التي تحققت لأول مرة في هذه الرمية.
class _GoalsBanner extends ConsumerWidget {
  const _GoalsBanner({required this.result});

  final CastResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stage = ref.watch(stageCatalogProvider).byId(result.stageId);
    final fish = ref.read(fishCatalogProvider);
    final done = ref.watch(playerProvider.select((p) => stage.goalsDone(p.progressIn(stage.id))));
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final i in result.newGoals)
            Text(
              '✓ ${stage.goals[i].label(fish)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF2E7D32)),
            ),
          Text(
            'أهداف ${stage.name}: $done من ${stage.goals.length}',
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF5C6B7A)),
          ),
        ],
      ),
    );
  }
}

/// زرّا «المراحل» و«تطوير» تحت النتيجة.
class _MenuRow extends ConsumerWidget {
  const _MenuRow({required this.game});

  final SeaHunterGame game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(playerProvider);
    final canUpgrade = Upgrade.values.any((u) => u.canAfford(p));
    Widget button(String label, VoidCallback onTap, {bool highlight = false}) => Expanded(
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          backgroundColor: highlight ? const Color(0xFFFFF1CC) : Colors.white,
          side: BorderSide(color: highlight ? const Color(0xFFFFB300) : const Color(0x33062B4F), width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.seaDeep),
        ),
      ),
    );
    return Row(
      children: [
        button('🗺️ المراحل', () => game.openMenu('stages')),
        const SizedBox(width: 10),
        button(canUpgrade ? '🛠️ تطوير متاح!' : '🛠️ تطوير', () => game.openMenu('shop'), highlight: canUpgrade),
      ],
    );
  }
}

class _NewAlbumBanner extends StatelessWidget {
  const _NewAlbumBanner();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFFFFD54F), Color(0xFFFFB300)]),
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Text(
      '📖 سمكة جديدة في الألبوم!',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Color(0xFF5D3B00)),
    ),
  );
}

class _LostHeader extends StatelessWidget {
  const _LostHeader();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: 4),
    child: Text(
      'ضاعت منك 💔 (انقطع الخيط)',
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFFB23B3B)),
    ),
  );
}

class _FishRow extends StatelessWidget {
  const _FishRow({required this.fish, this.lost = false});

  final CaughtFish fish;

  /// سمكة انقطع خيطها: تُعرض باهتة وقيمتها مشطوبة.
  final bool lost;

  @override
  Widget build(BuildContext context) {
    final s = fish.species;
    final w = fish.weightKg;
    final row = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: lost ? const Color(0xFFE57373) : s.rarity.color.withValues(alpha: 0.7), width: 2),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(color: const Color(0xFFE3F4FA), borderRadius: BorderRadius.circular(12)),
            child: FishIcon(species: s),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        s.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _Chip(text: s.rarity.arabicName, color: s.rarity.color),
                    if (fish.fromFight && !lost) ...[const SizedBox(width: 4), const _Chip(text: 'صراع 💪', color: Color(0xFF2E9D57))],
                    if (fish.isNew) ...[const SizedBox(width: 4), const _Chip(text: 'جديد!', color: AppColors.coral)],
                  ],
                ),
                Text(
                  '${formatKg(w)} كغ',
                  style: const TextStyle(fontSize: 14, color: Color(0xFF5C6B7A), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Text(
            plus(fish.value),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: lost ? const Color(0xFF9E9E9E) : const Color(0xFFC77700),
              decoration: lost ? TextDecoration.lineThrough : null,
              decorationThickness: 2.5,
            ),
          ),
        ],
      ),
    );
    return lost ? Opacity(opacity: 0.75, child: row) : row;
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w800),
    ),
  );
}

class _BigButton extends StatefulWidget {
  const _BigButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_BigButton> createState() => _BigButtonState();
}

class _BigButtonState extends State<_BigButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _down ? 0.95 : 1,
        duration: const Duration(milliseconds: 90),
        child: Container(
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.coral, AppColors.coralDark],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(color: AppColors.coralDark.withValues(alpha: 0.5), offset: Offset(0, _down ? 2 : 6), blurRadius: 0)],
          ),
          child: Text(
            widget.label,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
