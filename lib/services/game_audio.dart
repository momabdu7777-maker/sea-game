import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';

/// المؤثرات الصوتية المتاحة. الملفات في assets/audio (مؤقتة، تُولّد بـ tools/gen_sfx.py).
enum Sfx {
  whoosh('whoosh.wav'),
  splash('splash.wav'),
  pop('pop.wav'),
  thunk('thunk.wav'),
  coin('coin.wav'),
  tick('tick.wav'),
  fanfare('fanfare.wav'),
  reel('reel.wav'),
  snap('snap.wav'),
  strain('strain.wav');

  const Sfx(this.file);
  final String file;
}

/// خدمة الصوت. كل الاستدعاءات آمنة: أي خطأ في الصوت لا يوقف اللعبة.
class GameAudio {
  bool _enabled = true;
  bool _ready = false;

  /// في المتصفح لا يُسمح بتشغيل الصوت قبل أول تفاعل من المستخدم.
  bool _unlocked = !kIsWeb;
  final Map<Sfx, AudioPool> _pools = {};

  /// أصوات متكررة بسرعة تستخدم Pool لتقليل التأخير على الجوالات الضعيفة.
  static const _pooled = {Sfx.pop: 4, Sfx.coin: 5, Sfx.tick: 3, Sfx.reel: 4};

  Future<void> init({required bool enabled}) async {
    _enabled = enabled;
    try {
      await FlameAudio.audioCache.loadAll([for (final s in Sfx.values) s.file, 'waves.wav']);
      for (final e in _pooled.entries) {
        _pools[e.key] = await FlameAudio.createPool(e.key.file, maxPlayers: e.value);
      }
      await FlameAudio.bgm.initialize();
      _ready = true;
      if (_enabled && _unlocked) _startAmbience();
    } catch (e) {
      debugPrint('Audio init failed: $e');
    }
  }

  bool get enabled => _enabled;

  /// يُستدعى مع كل لمسة؛ أول لمسة في المتصفح تفتح الصوت وتبدأ صوت الموج.
  void userGesture() {
    if (_unlocked) return;
    _unlocked = true;
    if (_ready && _enabled) _startAmbience();
  }

  void setEnabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    if (!_ready || !_unlocked) return;
    if (value) {
      _startAmbience();
    } else {
      FlameAudio.bgm.stop().ignore();
    }
  }

  void play(Sfx sfx, {double volume = 1}) {
    if (!_enabled || !_ready || !_unlocked) return;
    try {
      final pool = _pools[sfx];
      if (pool != null) {
        pool.start(volume: volume).ignore();
      } else {
        FlameAudio.play(sfx.file, volume: volume).ignore();
      }
    } catch (_) {}
  }

  void _startAmbience() {
    // صوت موج هادئ متكرر (الموسيقى الشعبية الساحلية تأتي في مرحلة لاحقة)
    FlameAudio.bgm.play('waves.wav', volume: 0.35).ignore();
  }

  void dispose() {
    FlameAudio.bgm.dispose();
    for (final p in _pools.values) {
      p.dispose();
    }
  }
}
