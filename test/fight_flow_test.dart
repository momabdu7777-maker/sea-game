import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sea_hunter/config/game_config.dart';
import 'package:sea_hunter/data/fish_species.dart';
import 'package:sea_hunter/game/sea_hunter_game.dart';
import 'package:sea_hunter/services/game_audio.dart';
import 'package:sea_hunter/state/player_state.dart';
import 'package:sea_hunter/state/providers.dart';
import 'package:sea_hunter/ui/overlays/fight_overlay.dart';
import 'package:sea_hunter/ui/overlays/hud_overlay.dart';
import 'package:sea_hunter/ui/overlays/results_overlay.dart';
import 'package:sea_hunter/ui/theme.dart';

/// اختبار شامل لحلقة اللعبة الحقيقية: رمية ← نزول ← صعود ← صراع سمكة كبيرة ← النتيجة.
/// لحفظ صور الشاشة:  SHOTS_DIR=/some/dir flutter test test/fight_flow_test.dart
void main() {
  final shotsDir = Platform.environment['SHOTS_DIR'];
  final boundary = GlobalKey();

  Future<void> shot(WidgetTester tester, String name) async {
    if (shotsDir == null) return;
    await tester.runAsync(() async {
      final img = await (boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage();
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$shotsDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  Future<SeaHunterGame> start(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final catalog = FishCatalog.parse(File('assets/data/fish.json').readAsStringSync());
    final game = SeaHunterGame(
      config: const GameConfig(),
      catalog: catalog,
      // خيط أطول (مستوى 2) لتكثر الأسماك الكبيرة في البحر
      readPlayer: () => PlayerState.initial().copyWith(lineLevel: 2),
      onCastFinished: (r) => r,
      audio: GameAudio(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [fishCatalogProvider.overrideWithValue(catalog), playerProvider.overrideWith(_TestPlayer.new)],
        child: MaterialApp(
          theme: buildTheme(),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: RepaintBoundary(
              key: boundary,
              child: GameWidget<SeaHunterGame>(
                game: game,
                textDirection: TextDirection.rtl,
                overlayBuilderMap: {
                  'hud': (context, g) => HudOverlay(game: g),
                  'fight': (context, g) => FightOverlay(game: g),
                  'results': (context, g) => ResultsOverlay(game: g),
                },
                initialActiveOverlays: const ['hud'],
              ),
            ),
          ),
        ),
      ),
    );
    await pumpFor(tester, 0.5);
    return game;
  }

  /// يرمي ثم ينتظر الصعود، وينقل أول سمكة كبيرة إلى الصنارة ليبدأ الصراع.
  Future<bool> castIntoFight(WidgetTester tester, SeaHunterGame game) async {
    for (var attempt = 0; attempt < 12; attempt++) {
      if (game.phase.value == CastPhase.results) game.newCast();
      await pumpFor(tester, 0.3);
      game.pointerDown(Vector2(195, 380));
      for (var i = 1; i <= 20; i++) {
        game.pointerMove(Vector2(195, 380 + i * 20.0), Vector2(0, 20));
        await tester.pump(const Duration(milliseconds: 16));
      }
      game.pointerUp();
      for (var f = 0; f < 60 * 40 && game.phase.value != CastPhase.ascending; f++) {
        if (game.phase.value == CastPhase.results) break;
        await tester.pump(const Duration(milliseconds: 16));
      }
      if (game.phase.value != CastPhase.ascending) continue;
      final big = game.fishes.where((f) => f.needsFight && f.isSwimming).toList();
      if (big.isEmpty) {
        for (var f = 0; f < 60 * 40 && game.phase.value != CastPhase.results; f++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        continue;
      }
      big.first.position.setFrom(game.hook.position);
      for (var f = 0; f < 10 && game.phase.value != CastPhase.fighting; f++) {
        big.first.position.setFrom(game.hook.position);
        await tester.pump(const Duration(milliseconds: 16));
      }
      if (game.phase.value == CastPhase.fighting) return true;
    }
    return false;
  }

  testWidgets('صراع كامل: الشد الذكي يفوز وتظهر النتيجة', (tester) async {
    final game = await start(tester);
    expect(await castIntoFight(tester, game), isTrue, reason: 'لم يبدأ صراع خلال 12 رمية');
    await pumpFor(tester, 1.2);
    await shot(tester, 'fight-1-start');
    // سياسة بسيطة: اضغط إذا كان المؤشر تحت مركز المنطقة الخضراء
    var holding = false;
    for (var f = 0; f < 60 * 60 && game.fightOutcome.value == null; f++) {
      final fs = game.fightSession.value;
      if (fs != null) {
        final want = fs.indicator < fs.zoneCenter;
        if (want != holding) {
          holding = want;
          holding ? game.pointerDown(Vector2(195, 600)) : game.pointerUp();
        }
      }
      await tester.pump(const Duration(milliseconds: 16));
      if (f == 60 * 3) await shot(tester, 'fight-2-mid');
    }
    game.pointerUp();
    expect(game.fightOutcome.value, isNotNull);
    expect(game.fightOutcome.value!.won, isTrue);
    await pumpFor(tester, 0.8);
    await shot(tester, 'fight-3-won');
    for (var f = 0; f < 60 * 40 && game.phase.value != CastPhase.results; f++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(game.phase.value, CastPhase.results);
    await pumpFor(tester, 1);
    await shot(tester, 'fight-4-results');
  });

  testWidgets('صراع بلا تحكم: ينقطع الخيط وتضيع السمكة', (tester) async {
    final game = await start(tester);
    expect(await castIntoFight(tester, game), isTrue);
    for (var f = 0; f < 60 * 60 && game.fightOutcome.value == null; f++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(game.fightOutcome.value?.won, isFalse);
    await pumpFor(tester, 0.6);
    await shot(tester, 'fight-5-lost');
    for (var f = 0; f < 60 * 40 && game.phase.value != CastPhase.results; f++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(game.phase.value, CastPhase.results);
    await pumpFor(tester, 1);
    await shot(tester, 'fight-6-results-lost');
  });
}

/// لاعب للاختبار بدون Hive.
class _TestPlayer extends PlayerNotifier {
  @override
  PlayerState build() => PlayerState.initial().copyWith(lineLevel: 2);
}

Future<void> pumpFor(WidgetTester tester, double seconds) async {
  for (var i = 0; i < (seconds * 60).round(); i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}
