import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/fish_species.dart';
import 'data/save_repository.dart';
import 'data/stage.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // التحميل قبل تشغيل الواجهة: الحفظ المحلي + بيانات الأسماك والمراحل
  final save = await SaveRepository.open();
  final catalog = await FishCatalog.loadFromAssets();
  final stages = await StageCatalog.loadFromAssets();

  runApp(
    ProviderScope(
      overrides: [
        saveRepositoryProvider.overrideWithValue(save),
        fishCatalogProvider.overrideWithValue(catalog),
        stageCatalogProvider.overrideWithValue(stages),
      ],
      child: const SeaHunterApp(),
    ),
  );
}
