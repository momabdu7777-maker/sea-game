import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sea_hunter/config/game_config.dart';
import 'package:sea_hunter/data/cast_result.dart';
import 'package:sea_hunter/data/fish_species.dart';
import 'package:sea_hunter/data/save_repository.dart';
import 'package:sea_hunter/data/stage.dart';
import 'package:sea_hunter/game/sea_hunter_game.dart';
import 'package:sea_hunter/services/game_audio.dart';
import 'package:sea_hunter/state/player_state.dart';
import 'package:sea_hunter/state/providers.dart';
import 'package:sea_hunter/ui/overlays/help_overlay.dart';
import 'package:sea_hunter/ui/overlays/hud_overlay.dart';
import 'package:sea_hunter/ui/overlays/results_overlay.dart';
import 'package:sea_hunter/ui/overlays/shop_overlay.dart';
import 'package:sea_hunter/ui/overlays/stages_overlay.dart';
import 'package:sea_hunter/ui/theme.dart';

/// يفتح القوائم الجديدة (الشرح، التطوير، المراحل، النتيجة) ويتأكد أنها تُبنى بلا أخطاء.
/// لحفظ صور الشاشة بالخطوط الحقيقية:  SHOTS_DIR=/some/dir flutter test test/menus_shots_test.dart
void main() {
  final shotsDir = Platform.environment['SHOTS_DIR'];
  final boundary = GlobalKey();

  setUpAll(() async {
    if (shotsDir == null) return;
    Future<void> load(String family, List<String> files) async {
      final loader = FontLoader(family);
      for (final f in files) {
        if (File(f).existsSync()) loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
      }
      await loader.load();
    }

    await load('Tajawal', [for (final w in ['Regular', 'Bold', 'ExtraBold', 'Black']) 'assets/fonts/Tajawal-$w.ttf']);
    final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '${Platform.environment['HOME']}/development/flutter';
    await load('MaterialIcons', ['$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
    await load('Emoji', ['/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf']);
    await load('Symbols', ['/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf']);
  });

  Future<void> shot(WidgetTester tester, String name) async {
    if (shotsDir == null) return;
    await tester.runAsync(() async {
      final img = await (boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage();
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$shotsDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  Future<void> pumpFor(WidgetTester tester, double seconds) async {
    for (var i = 0; i < (seconds * 60).round(); i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  testWidgets('القوائم الجديدة تُبنى وتعمل', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fish = FishCatalog.parse(File('assets/data/fish.json').readAsStringSync());
    final stages = StageCatalog.parse(File('assets/data/stages.json').readAsStringSync());
    final save = SaveRepository.inMemory();
    await save.savePlayer(
      PlayerState.initial().copyWith(
        coins: 420,
        lineLevel: 1,
        totalCasts: 9,
        seenHelp: true,
        completedStages: {'mukalla'},
        currentStage: 'aden',
        stageProgress: {
          'mukalla': const StageProgress(catches: 14, bestDepth: 84, species: {'a', 'b', 'c', 'd', 'e', 'f'}),
          'aden': const StageProgress(catches: 9, fightsWon: 1, bestDepth: 118),
        },
      ),
    );
    final container = ProviderContainer(
      overrides: [
        saveRepositoryProvider.overrideWithValue(save),
        fishCatalogProvider.overrideWithValue(fish),
        stageCatalogProvider.overrideWithValue(stages),
      ],
    );
    addTearDown(container.dispose);

    final game = SeaHunterGame(
      config: const GameConfig(),
      catalog: fish,
      stages: stages,
      readPlayer: () => container.read(playerProvider),
      onCastFinished: (r) => container.read(playerProvider.notifier).applyCastResult(r),
      audio: GameAudio(),
    );
    final base = buildTheme();
    final theme = base.copyWith(textTheme: base.textTheme.apply(fontFamilyFallback: const ['Symbols', 'Emoji']));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: theme,
          // نفس إعدادات التطبيق (app.dart): العربية واتجاه من اليمين لليسار
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: RepaintBoundary(
              key: boundary,
              child: GameWidget<SeaHunterGame>(
                game: game,
                textDirection: TextDirection.rtl,
                overlayBuilderMap: {
                  'hud': (context, g) => HudOverlay(game: g),
                  'results': (context, g) => ResultsOverlay(game: g),
                  'help': (context, g) => HelpOverlay(game: g),
                  'shop': (context, g) => ShopOverlay(game: g),
                  'stages': (context, g) => StagesOverlay(game: g),
                },
                initialActiveOverlays: const ['hud'],
              ),
            ),
          ),
        ),
      ),
    );
    await pumpFor(tester, 1);
    expect(game.stage.id, 'aden');
    expect(game.castLimit.value, 125, reason: 'خيط المستوى 1 = 125 م، أقصر من قاع عدن 170 م');
    expect(find.text('تطوير'), findsOneWidget);
    await shot(tester, 'm1-aiming');

    // اللمس لا يصل للعبة أثناء فتح قائمة
    game.openMenu('help');
    await pumpFor(tester, 0.6);
    expect(game.menuOpen, isTrue);
    game.pointerDown(Vector2(195, 300));
    game.pointerMove(Vector2(195, 600), Vector2(0, 300));
    game.pointerUp();
    expect(game.phase.value, CastPhase.aiming);
    await shot(tester, 'm2-help');
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -700));
    await pumpFor(tester, 0.4);
    await shot(tester, 'm3-help-scrolled');
    await tester.tap(find.text('فهمت، يلا نصطاد! 🎣'));
    await pumpFor(tester, 0.5);
    expect(game.menuOpen, isFalse);

    // التطوير: شراء سعة الصنارة (120 ريال)
    game.openMenu('shop');
    await pumpFor(tester, 0.6);
    await shot(tester, 'm4-shop');
    await tester.ensureVisible(find.text('طوّر  •  120 ريال'));
    await pumpFor(tester, 0.3);
    await tester.tap(find.text('طوّر  •  120 ريال'));
    await pumpFor(tester, 0.6);
    expect(container.read(playerProvider).hookLevel, 1);
    expect(container.read(playerProvider).coins, 300);
    await shot(tester, 'm5-shop-bought');
    await tester.tap(find.text('رجوع للصيد 🎣'));
    await pumpFor(tester, 0.5);
    expect(game.capacity.value, 5, reason: 'البحر يُجهّز من جديد بالصنارة الأكبر');

    // المراحل: الرجوع للمكلا
    game.openMenu('stages');
    await pumpFor(tester, 0.6);
    await shot(tester, 'm6-stages');
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -600));
    await pumpFor(tester, 0.4);
    await shot(tester, 'm7-stages-scrolled');
    await tester.ensureVisible(find.text('اصطد هنا 🏖️'));
    await pumpFor(tester, 0.3);
    await tester.tap(find.text('اصطد هنا 🏖️'));
    await pumpFor(tester, 0.6);
    expect(container.read(playerProvider).currentStage, 'mukalla');
    expect(game.stage.id, 'mukalla');

    // نتيجة رمية أكملت المرحلة
    final r = CastResult(
      fish: [
        CaughtFish(species: fish.byId('kanad')!, weightKg: 4.2, value: 120),
        CaughtFish(species: fish.byId('emperor')!, weightKg: 1.1, value: 14)..isNew = true,
      ],
      maxDepth: 92,
      end: DescentEnd.reachedDepth,
      seed: 3,
      stageId: 'aden',
    )..completedStage = true;
    game.lastResult = r;
    game.overlays.add('results');
    await pumpFor(tester, 1.4);
    await shot(tester, 'm8-results-stage-complete');
    expect(find.text('🎉 أكملت «خليج عدن»!'), findsOneWidget);
  });
}
