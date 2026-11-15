# صياد البحر العربي 🎣

لعبة صيد أركيد للجوال — Flutter + Flame + Riverpod + Hive.

## المرحلة الحالية: 2 (صراع الأسماك الكبيرة)

- **المرحلة 1:** الرمي بالسحب ← النزول وتفادي العوائق ← الصعود والتقاط الأسماك ← القذف الاحتفالي ← شاشة النتيجة.
- **المرحلة 2:** عند تعلّق سمكة كبيرة (هامور، تونة صفراء الزعانف، قرش، قرش الحوت) يبدأ صراع:
  اضغط باستمرار = شد، أفلت = إرخاء — أبقِ المؤشر داخل المنطقة الخضراء حتى يمتلئ شريط التقدم.
  البقاء خارجها طويلاً يقطع الخيط («كانت بيدك! 💔») وتظهر السمكة الضائعة في شاشة النتيجة.
  - صعوبة الصراع: `fightPower` و `fightMinWeight` لكل سمكة في `assets/data/fish.json`.
  - كل أرقام الصراع (`fight*`) في `lib/config/game_config.dart`.
  - المنطق في `lib/game/systems/fight_session.dart` (مستقل عن الرسم ومُختبَر في `test/fight_test.dart`).
  - الواجهة في `lib/ui/overlays/fight_overlay.dart`.

## العب الآن

- **من المتصفح:** https://momabdu7777-maker.github.io/sea-game/play/
- **تحميل لأندرويد (APK):** https://momabdu7777-maker.github.io/sea-game/

## بنية المشروع

```
assets/
  data/fish.json          ← بيانات الأسماك (عدّل/أضف هنا بدون لمس الكود)
  audio/*.wav             ← أصوات مؤقتة (تُولَّد بـ tools/gen_sfx.py)
  fonts/Tajawal-*.ttf
lib/
  main.dart               ← تهيئة Hive + تحميل JSON + ProviderScope
  app.dart                ← MaterialApp عربي RTL
  config/game_config.dart ← كل أرقام اللعبة (سرعات، كثافة، أسعار، ألوان العمق)
  data/                   ← نماذج البيانات + الحفظ المحلي
  state/                  ← Riverpod: حالة اللاعب الدائمة
  art/fish_visual.dart    ← رسم الأسماك المؤقت — نقطة استبدال واحدة بالرسومات النهائية
  services/               ← الصوت والاهتزاز
  game/
    sea_hunter_game.dart  ← آلة حالات الرمية + الكاميرا + الإدخال
    systems/sea_spawner.dart ← توليد البحر ببذرة (Seed) — قابل للاختبار
    systems/fight_session.dart ← منطق صراع السمكة الكبيرة
    components/           ← القارب، الصنارة، الخيط، الأسماك، العوائق، المؤثرات...
  ui/                     ← واجهات Flutter: HUD، لوحة الصراع، شاشة النتيجة
web/                      ← نسخة المتصفح (شاشة التحميل، الأيقونات، manifest)
tools/icon/               ← توليد أيقونة اللعبة من رسم الأسماك نفسه
test/                     ← اختبارات المنطق + اختبار شامل للصراع (fight_flow_test)
```

## التشغيل

```bash
export PATH=$HOME/development/flutter/bin:$PATH
flutter pub get
flutter run                 # على جوال موصول بـ USB (وضع debug)
flutter run --release       # لتجربة الأداء الحقيقي (60fps)
flutter build apk --release # ملف APK في build/app/outputs/flutter-apk/app-release.apk
flutter test

# نسخة الويب (لـ GitHub Pages تحت /sea-game/play/)
flutter build web --release --base-href /sea-game/play/ --no-web-resources-cdn

# إعادة توليد الأيقونة
flutter test tools/icon/render_icon_test.dart && python3 tools/icon/make_icons.py
```

## النشر على GitHub Pages

موقع التحميل في الفرع `gh-pages`: صفحة `index.html` + ملف `sea-hunter.apk` + اللعبة في `play/` (ناتج `build/web`).
عند التحديث: ارفع رقم `version` في pubspec.yaml، ابنِ الـ APK والويب، انسخهما إلى الفرع `gh-pages`
وحدّث رقم الإصدار والحجم وبصمة SHA-256 في صفحة التحميل.

## ⚠️ مفتاح التوقيع

`android/sea-hunter-release.jks` و `android/key.properties` — احتفظ بنسخة احتياطية منهما.
فقدانهما يعني عدم القدرة على إصدار تحديثات للنسخ المثبتة أو في Google Play. لا ترفعهما إلى git (مستثنيان في .gitignore).
