import 'package:hive_ce_flutter/hive_flutter.dart';

import '../state/player_state.dart';

/// حفظ محلي باستخدام Hive — يعمل بدون إنترنت.
/// في المرحلة 6 سيُضاف مزامنة مع Firestore فوق هذه الطبقة.
class SaveRepository {
  SaveRepository._(this._box);

  final Box<dynamic> _box;

  static const _boxName = 'sea_hunter_save';
  static const _playerKey = 'player';

  static Future<SaveRepository> open() async {
    await Hive.initFlutter();
    return SaveRepository._(await Hive.openBox<dynamic>(_boxName));
  }

  PlayerState loadPlayer() {
    final raw = _box.get(_playerKey);
    if (raw is Map) return PlayerState.fromMap(Map<String, dynamic>.from(raw));
    return PlayerState.initial();
  }

  Future<void> savePlayer(PlayerState s) => _box.put(_playerKey, s.toMap());
}
