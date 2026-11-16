import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/rarity.dart';
import '../../game/sea_hunter_game.dart';
import '../../state/providers.dart';
import '../theme.dart';
import '../widgets/menu_sheet.dart';

/// شاشة «كيف تصطاد؟»: تظهر تلقائياً أول مرة، وتُفتح من زر ❓ في أي وقت.
class HelpOverlay extends ConsumerWidget {
  const HelpOverlay({super.key, required this.game});

  final SeaHunterGame game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void close() {
      ref.read(playerProvider.notifier).markHelpSeen();
      game.closeMenu('help');
    }

    return MenuSheet(
      title: 'كيف تصطاد؟ 🎣',
      onClose: close,
      footer: BigButton(label: 'فهمت، يلا نصطاد! 🎣', onTap: close, height: 58, fontSize: 22),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Step(
            n: 1,
            emoji: '🎯',
            title: 'ارمِ الصنارة',
            body:
                'المس الشاشة واسحب إصبعك للأسفل، ثم أفلت. كلما سحبت أكثر نزلت الصنارة أعمق، '
                'والسحب حتى آخره = «رمية كاملة 💪» إلى نهاية الخيط.\n'
                'اسحب يميناً أو يساراً لتختار مكان سقوط الصنارة: فوق الأسماك التي تريدها.',
          ),
          _Step(
            n: 2,
            emoji: '🪼',
            title: 'انزل وتفادَ العوائق',
            body:
                'الصنارة تنزل وحدها. حرّك إصبعك يميناً ويساراً لتتفادى قناديل البحر والصخور والشباك القديمة.\n'
                'لمس أي عائق يوقف النزول فوراً ويبدأ الصعود، فكلما تفاديت أكثر وصلت أعمق إلى الأسماك الأغلى.',
          ),
          _Step(
            n: 3,
            emoji: '🐟',
            title: 'اصطد وأنت صاعد',
            body:
                'بعد أقصى عمق تبدأ الصنارة بالصعود. مرّرها على الأسماك فتعلق بها، حتى تمتلئ '
                '(العدد أعلى الشاشة 🐟 مثل 2/4).\n'
                'الصنارة الممتلئة تصعد بسرعة، فلا تملأها بالسردين إذا كنت تطارد سمكة أثمن تحتها!',
          ),
          _Step(
            n: 4,
            emoji: '💪',
            title: 'صارع الأسماك الكبيرة',
            body:
                'الهامور الضخم والتونة والقرش وأبو سيف لا تُصطاد بلمسة؛ يبدأ معها صراع:\n'
                '• اضغط باستمرار = شد 🔥 (المؤشر الأبيض يتحرك نحو اليسار)\n'
                '• أفلت = إرخاء (المؤشر يرجع نحو اليمين)\n'
                'أبقِ المؤشر داخل المنطقة الخضراء حتى يمتلئ شريط التقدم. إذا بقي خارجها طويلاً ينقطع الخيط وتضيع السمكة 💔',
            extra: _FightBarDiagram(),
          ),
          _Step(
            n: 5,
            emoji: '🛠️',
            title: 'بِع وطوّر عدّتك',
            body:
                'كل سمكة تُباع تلقائياً بالريال حسب ندرتها ووزنها. اصرف الريالات من زر «تطوير»:\n'
                '🧵 خيط أطول للنزول أعمق • 🪝 صنارة أكبر لأسماك أكثر • 💪 خيط أقوى لصراع أسهل.',
          ),
          _Step(
            n: 6,
            emoji: '🗺️',
            title: 'افتح المراحل',
            body:
                'لكل مرحلة أهداف (عدد أسماك، أنواع، عمق، صراعات). أكملها كلها لتفتح المرحلة التالية:\n'
                'ساحل المكلا ← خليج عدن ← جزيرة سقطرى ← أعماق المحيط الهندي.\n'
                'كل مرحلة أعمق وأسماكها أندر وأسعارها أعلى، لكنها تحتاج خيطاً أطول.',
          ),
          SizedBox(height: 6),
          _RarityLegend(),
          SizedBox(height: 12),
          _Tips(),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.emoji, required this.title, required this.body, this.extra});

  final int n;
  final String emoji;
  final String title;
  final String body;
  final Widget? extra;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0x1F062B4F), width: 1.5),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: const Color(0xFFE3F4FA), borderRadius: BorderRadius.circular(14)),
          child: Text(emoji, style: const TextStyle(fontSize: 26)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الخطوة $n',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.coralDark),
              ),
              Text(
                title,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppColors.seaDeep, height: 1.25),
              ),
              const SizedBox(height: 3),
              Text(body, style: const TextStyle(fontSize: 15.5, height: 1.55, color: AppColors.ink)),
              if (extra != null) ...[const SizedBox(height: 10), extra!],
            ],
          ),
        ),
      ],
    ),
  );
}

/// رسم توضيحي لشريط الصراع (نفس اتجاه اللعبة: اليسار = شد).
class _FightBarDiagram extends StatelessWidget {
  const _FightBarDiagram();

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Column(
      children: [
        SizedBox(
          height: 26,
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              return Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFE57373), Color(0xFF546E7A), Color(0xFF455A64)]),
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  Positioned(
                    left: w * 0.36,
                    width: w * 0.3,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xCC43C46B),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                  Positioned(
                    left: w * 0.5 - 3,
                    width: 6,
                    top: -2,
                    bottom: -2,
                    child: Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        // نفس تسميات شريط الصراع في اللعبة: اليسار «شد 🔥» واليمين «إرخاء»
        const Row(
          children: [
            Expanded(
              child: Text(
                'شد 🔥',
                textAlign: TextAlign.left,
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Color(0xFFC0392B)),
              ),
            ),
            Text(
              'المنطقة الخضراء',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Color(0xFF2E9D57)),
            ),
            Expanded(
              child: Text(
                'إرخاء',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Color(0xFF455A64)),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _RarityLegend extends StatelessWidget {
  const _RarityLegend();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'ندرة الأسماك',
        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppColors.seaDeep),
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final r in Rarity.values)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: r.color, borderRadius: BorderRadius.circular(10)),
              child: Text(
                r.arabicName,
                style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
      const SizedBox(height: 6),
      const Text(
        'كلما ندرت السمكة وثقل وزنها زاد سعرها، والأسطورية أغلى بعشر مرات!',
        style: TextStyle(fontSize: 15, height: 1.5, color: AppColors.ink),
      ),
    ],
  );
}

class _Tips extends StatelessWidget {
  const _Tips();

  static const _tips = [
    'الأسماك الأغلى تعيش في الأعماق: الرمية الكاملة + تفادي العوائق = صيد أثمن.',
    'الأسماك النادرة السريعة قد تفرّ عند اقتراب الصنارة. إذا فرّت فلاحقها فوراً، فهي لا تستطيع الفرار مرة أخرى مباشرة.',
    'في الصراع: ضغطات قصيرة متتالية أسهل في التحكم من ضغطة طويلة واحدة.',
    'عندما تقول «تسحب بقوة! ⚡» تندفع السمكة فجأة؛ أرخِ قليلاً ثم عُد للشد.',
    'كلما نزلت أعمق أظلم البحر، فانتبه للعوائق التي تظهر فجأة من الظلام.',
  ];

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: const Color(0xFFFFF1CC), borderRadius: BorderRadius.circular(18)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '💡 نصائح الصياد',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Color(0xFF5D3B00)),
        ),
        const SizedBox(height: 6),
        for (final t in _tips)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  ', style: TextStyle(fontSize: 15.5, color: Color(0xFF5D3B00))),
                Expanded(
                  child: Text(t, style: const TextStyle(fontSize: 15.5, height: 1.5, color: Color(0xFF4A3200))),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
