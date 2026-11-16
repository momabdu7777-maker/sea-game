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
import 'package:sea_hunter/data/fish_species.dart';
import 'package:sea_hunter/data/save_repository.dart';
import 'package:sea_hunter/data/stage.dart';
import 'package:sea_hunter/game/sea_hunter_game.dart';
import 'package:sea_hunter/services/game_audio.dart';
import 'package:sea_hunter/state/player_state.dart';
import 'package:sea_hunter/state/providers.dart';
import 'package:sea_hunter/ui/overlays/fight_overlay.dart';
import 'package:sea_hunter/ui/overlays/help_overlay.dart';
import 'package:sea_hunter/ui/overlays/hud_overlay.dart';
import 'package:sea_hunter/ui/overlays/results_overlay.dart';
import 'package:sea_hunter/ui/overlays/shop_overlay.dart';
import 'package:sea_hunter/ui/overlays/stages_overlay.dart';
import 'package:sea_hunter/ui/theme.dart';

/// صور شاشة لصفحة التحميل والمتاجر (390×844 بكثافة 1.5 = 585×1266) من اللعبة الحقيقية.
/// لا يعمل إلا مع SHOTS_DIR:
///   SHOTS_DIR=/some/dir flutter test test/store_shots_test.dart
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
    await tester.runAsync(() async {
      final img = await (boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage(pixelRatio: 1.5);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$shotsDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  Future<void> pumpFor(WidgetTester tester, double seconds) async {
    for (var i = 0; i < (seconds * 60).round(); i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<(SeaHunterGame, ProviderContainer)> start(WidgetTester tester, PlayerState player, {List<String> overlays = const []}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fish = FishCatalog.parse(File('assets/data/fish.json').readAsStringSync());
    final stages = StageCatalog.parse(File('assets/data/stages.json').readAsStringSync());
    final save = SaveRepository.inMemory();
    await save.savePlayer(player);
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
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: base.copyWith(textTheme: base.textTheme.apply(fontFamilyFallback: const ['Symbols', 'Emoji'])),
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
                  'fight': (context, g) => FightOverlay(game: g),
                  'results': (context, g) => ResultsOverlay(game: g),
                  'help': (context, g) => HelpOverlay(game: g),
                  'shop': (context, g) => ShopOverlay(game: g),
                  'stages': (context, g) => StagesOverlay(game: g),
                },
                initialActiveOverlays: ['hud', ...overlays],
              ),
            ),
          ),
        ),
      ),
    );
    await pumpFor(tester, 1.2);
    return (game, container);
  }

  /// يسحب للرمي بقوة [power] (0..1) ويُبقي الإصبع على الشاشة.
  Future<void> pull(WidgetTester tester, SeaHunterGame game, double power) async {
    game.pointerDown(Vector2(195, 420));
    final dy = 844 * game.config.maxPullScreenFraction * power;
    for (var i = 1; i <= 20; i++) {
      game.pointerMove(Vector2(195 - i * 2.0, 420 + dy * i / 20), Vector2(-2, dy / 20));
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  final player = PlayerState.initial().copyWith(
    coins: 340,
    totalCasts: 14,
    seenHelp: true,
    catchCounts: {'sardine': 9, 'thamad': 3},
    stageProgress: {'mukalla': const StageProgress(catches: 8, bestDepth: 61, species: {'sardine', 'anchovy', 'thamad', 'crab'})},
  );

  testWidgets('صور الرمي والنزول', (tester) async {
    final (game, _) = await start(tester, player);
    await shot(tester, 'menu');
    await pull(tester, game, 0.78);
    await pumpFor(tester, 0.2);
    await shot(tester, 'cast');
    game.pointerUp();
    await pumpFor(tester, 2.4);
    // حرّك الصنارة قليلاً كما يفعل اللاعب
    for (var i = 0; i < 20; i++) {
      game.pointerMove(Vector2(195, 500), Vector2(i < 10 ? -3 : 3, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await shot(tester, 'descend');
  }, skip: shotsDir == null);

  testWidgets('صور الصراع والنتيجة', (tester) async {
    // عدن بخيط 175 م: هامور وتونة وقرش في البحر
    final p = player.copyWith(lineLevel: 3, completedStages: {'mukalla'}, currentStage: 'aden', lineStrengthLevel: 1);
    final (game, _) = await start(tester, p);
    var fought = false;
    for (var attempt = 0; attempt < 15 && !fought; attempt++) {
      if (game.phase.value == CastPhase.results) game.newCast();
      await pumpFor(tester, 0.3);
      await pull(tester, game, 1);
      game.pointerUp();
      for (var f = 0; f < 60 * 40 && game.phase.value != CastPhase.ascending; f++) {
        if (game.phase.value == CastPhase.results) break;
        await tester.pump(const Duration(milliseconds: 16));
      }
      if (game.phase.value != CastPhase.ascending) continue;
      final big = game.fishes.where((f) => f.needsFight && f.isSwimming && f.species.id != 'hamour').toList();
      if (big.isEmpty) {
        for (var f = 0; f < 60 * 40 && game.phase.value != CastPhase.results; f++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        continue;
      }
      for (var f = 0; f < 10 && game.phase.value != CastPhase.fighting; f++) {
        big.first.position.setFrom(game.hook.position);
        await tester.pump(const Duration(milliseconds: 16));
      }
      fought = game.phase.value == CastPhase.fighting;
    }
    expect(fought, isTrue);
    var holding = false;
    var shotTaken = false;
    for (var f = 0; f < 60 * 60 && game.fightOutcome.value == null; f++) {
      final fs = game.fightSession.value;
      if (fs != null) {
        final want = fs.indicator < fs.zoneCenter;
        if (want != holding) {
          holding = want;
          holding ? game.pointerDown(Vector2(195, 600)) : game.pointerUp();
        }
        if (!shotTaken && fs.progress > 0.55 && fs.dangerFraction < 0.2) {
          shotTaken = true;
          await shot(tester, 'fight');
        }
      }
      await tester.pump(const Duration(milliseconds: 16));
    }
    game.pointerUp();
    // بقية الصعود: التقط الأسماك القريبة
    for (var f = 0; f < 60 * 40 && game.phase.value != CastPhase.results; f++) {
      final swimming = game.fishes.where((x) => x.isSwimming && !x.needsFight && (x.y - game.hook.y).abs() < 200).toList();
      if (swimming.isNotEmpty && game.phase.value == CastPhase.ascending) {
        game.pointerMove(Vector2(195, 500), Vector2((swimming.first.x - game.hook.x).clamp(-6, 6).toDouble() / 1.25, 0));
      }
      await tester.pump(const Duration(milliseconds: 16));
    }
    await pumpFor(tester, 1.5);
    await shot(tester, 'results');
  }, skip: shotsDir == null);

  testWidgets('صور القوائم', (tester) async {
    final (game, _) = await start(
      tester,
      player.copyWith(
        coins: 520,
        lineLevel: 2,
        completedStages: {'mukalla'},
        currentStage: 'aden',
        stageProgress: {
          'mukalla': const StageProgress(catches: 14, bestDepth: 84, species: {'a', 'b', 'c', 'd', 'e', 'f'}),
          'aden': const StageProgress(catches: 17, fightsWon: 1, bestDepth: 131),
        },
      ),
    );
    game.openMenu('stages');
    await pumpFor(tester, 0.8);
    await shot(tester, 'stages');
    game.closeMenu('stages');
    game.openMenu('shop');
    await pumpFor(tester, 0.8);
    await shot(tester, 'shop');
    game.closeMenu('shop');
    game.openMenu('help');
    await pumpFor(tester, 0.8);
    await shot(tester, 'help');
  }, skip: shotsDir == null);
}
