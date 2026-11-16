import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../state/player_state.dart';

/// حفظ محلي باستخدام Hive — يعمل بدون إنترنت.
/// في المرحلة 6 سيُضاف مزامنة مع Firestore فوق هذه الطبقة.
class SaveRepository {
  SaveRepository._(this._box);

  /// حفظ في الذاكرة فقط (للاختبارات).
  @visibleForTesting
  SaveRepository.inMemory() : _box = null;

  final Box<dynamic>? _box;
  final Map<String, dynamic> _memory = {};

  static const _boxName = 'sea_hunter_save';
  static const _playerKey = 'player';

  static Future<SaveRepository> open() async {
    await Hive.initFlutter();
    return SaveRepository._(await Hive.openBox<dynamic>(_boxName));
  }

  PlayerState loadPlayer() {
    final raw = _box == null ? _memory[_playerKey] : _box.get(_playerKey);
    if (raw is Map) return PlayerState.fromMap(Map<String, dynamic>.from(raw));
    return PlayerState.initial();
  }

  Future<void> savePlayer(PlayerState s) async {
    final box = _box;
    if (box == null) {
      _memory[_playerKey] = s.toMap();
    } else {
      await box.put(_playerKey, s.toMap());
    }
  }
}
