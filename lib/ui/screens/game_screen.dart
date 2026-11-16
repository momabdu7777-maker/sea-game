import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../game/sea_hunter_game.dart';
import '../../services/game_audio.dart';
import '../../state/providers.dart';
import '../overlays/fight_overlay.dart';
import '../overlays/help_overlay.dart';
import '../overlays/hud_overlay.dart';
import '../overlays/results_overlay.dart';
import '../overlays/shop_overlay.dart';
import '../overlays/stages_overlay.dart';

/// الشاشة الرئيسية: لعبة Flame + واجهات Flutter فوقها.
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  late final GameAudio _audio;
  late final SeaHunterGame _game;
  int? _pointer;

  @override
  void initState() {
    super.initState();
    _audio = GameAudio()..init(enabled: ref.read(playerProvider).soundOn);
    _game = SeaHunterGame(
      config: ref.read(gameConfigProvider),
      catalog: ref.read(fishCatalogProvider),
      readPlayer: () => ref.read(playerProvider),
      onCastFinished: (r) => ref.read(playerProvider.notifier).applyCastResult(r),
      audio: _audio,
      stages: ref.read(stageCatalogProvider),
    );
  }

  Vector2 _v(Offset o) => Vector2(o.dx, o.dy);

  @override
  Widget build(BuildContext context) {
    ref.listen(playerProvider.select((p) => p.soundOn), (_, on) => _audio.setEnabled(on));

    // Listener بدل GestureDetector: يستقبل اللمس فوراً بدون تأخير "منطقة السحب"
    // وهذا مهم جداً لإحساس الصنارة. نتابع إصبعاً واحداً فقط.
    return Scaffold(
      backgroundColor: Colors.black,
      body: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) {
          _audio.userGesture();
          // لمسة على زر في الواجهة: لا تبدأ رمية
          if (_game.consumeUiTouch()) return;
          if (_pointer != null) return;
          _pointer = e.pointer;
          _game.pointerDown(_v(e.localPosition));
        },
        onPointerMove: (e) {
          if (e.pointer != _pointer) return;
          _game.pointerMove(_v(e.localPosition), _v(e.delta));
        },
        onPointerUp: (e) {
          if (e.pointer != _pointer) return;
          _pointer = null;
          _game.pointerUp();
        },
        onPointerCancel: (e) {
          if (e.pointer != _pointer) return;
          _pointer = null;
          _game.pointerUp();
        },
        child: GameWidget<SeaHunterGame>(
          game: _game,
          // Flame يفرض اليسار-لليمين على الواجهات إن لم نحدد الاتجاه
          textDirection: TextDirection.rtl,
          overlayBuilderMap: {
            'hud': (context, game) => HudOverlay(game: game),
            'fight': (context, game) => FightOverlay(game: game),
            'results': (context, game) => ResultsOverlay(game: game),
            'help': (context, game) => HelpOverlay(game: game),
            'shop': (context, game) => ShopOverlay(game: game),
            'stages': (context, game) => StagesOverlay(game: game),
          },
          // الشرح يظهر تلقائياً في أول تشغيل
          initialActiveOverlays: ['hud', if (!ref.read(playerProvider).seenHelp) 'help'],
        ),
      ),
    );
  }
}
