import 'dart:io';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sea_hunter/config/game_config.dart';
import 'package:sea_hunter/data/fish_species.dart';
import 'package:sea_hunter/game/sea_hunter_game.dart';
import 'package:sea_hunter/services/game_audio.dart';
import 'package:sea_hunter/state/player_state.dart';

void main() {
  // اختبار تراجعي: كانت الكاميرا لا تتحرك أبداً لأن viewfinder.position في Flame يُرجع نسخة.
  testWidgets('الكاميرا تتبع camTop فعلاً (العالم يتحرك مع الصنارة)', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final catalog = FishCatalog.parse(File('assets/data/fish.json').readAsStringSync());
    final game = SeaHunterGame(
      config: const GameConfig(),
      catalog: catalog,
      readPlayer: PlayerState.initial,
      onCastFinished: (r) => r,
      audio: GameAudio(),
    );
    await tester.pumpWidget(GameWidget(game: game));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    // وضع التصويب: سطح الماء على بُعد ~42% من أعلى الشاشة
    expect(game.camTop, lessThan(-300));
    expect(game.camera.viewfinder.position.y, closeTo(game.camTop, 1));
  });
}
