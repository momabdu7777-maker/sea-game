import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'ui/screens/game_screen.dart';
import 'ui/theme.dart';

class SeaHunterApp extends StatelessWidget {
  const SeaHunterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'صياد البحر العربي',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      // العربية واتجاه من اليمين لليسار في كل الواجهات
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // على الشاشات العريضة (متصفح الكمبيوتر أو جوال بالعرض) تظهر اللعبة بعمود بشكل جوال في المنتصف
      builder: (context, child) => _PhoneFrame(child: child!),
      home: const GameScreen(),
    );
  }
}

class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final size = mq.size;
    final maxWidth = math.max(360.0, size.height * 0.6);
    if (size.width <= maxWidth) return child;
    return ColoredBox(
      color: const Color(0xFF041B33),
      child: Center(
        child: SizedBox(
          width: maxWidth,
          child: MediaQuery(
            data: mq.copyWith(size: Size(maxWidth, size.height)),
            child: ClipRect(child: child),
          ),
        ),
      ),
    );
  }
}
