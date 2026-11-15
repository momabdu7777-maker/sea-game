"""يولّد مقاسات الأيقونة لأندرويد والويب من tools/icon/*.png (شغّل render_icon_test.dart أولاً).
التشغيل من جذر المشروع:  python3 tools/icon/make_icons.py
"""
import os
from PIL import Image, ImageDraw

base = Image.open('tools/icon/icon-1024.png').convert('RGBA')
bleed = Image.open('tools/icon/icon-bleed-1536.png').convert('RGBA')


def rounded(img, size, radius=0.2):
    im = img.resize((size, size), Image.LANCZOS)
    big = size * 4
    m = Image.new('L', (big, big), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, big - 1, big - 1], radius=int(big * radius), fill=255)
    im.putalpha(m.resize((size, size), Image.LANCZOS))
    return im


def crop_center(img, frac):
    w = img.width
    c = int(w * frac)
    o = (w - c) // 2
    return img.crop((o, o, o + c, o + c))


res = 'android/app/src/main/res'
for name, legacy, adaptive in [('mdpi', 48, 108), ('hdpi', 72, 162), ('xhdpi', 96, 216), ('xxhdpi', 144, 324), ('xxxhdpi', 192, 432)]:
    d = f'{res}/mipmap-{name}'
    os.makedirs(d, exist_ok=True)
    rounded(base, legacy).save(f'{d}/ic_launcher.png')
    bleed.resize((adaptive, adaptive), Image.LANCZOS).convert('RGB').save(f'{d}/ic_launcher_background.png')

os.makedirs(f'{res}/mipmap-anydpi-v26', exist_ok=True)
with open(f'{res}/mipmap-anydpi-v26/ic_launcher.xml', 'w') as f:
    f.write('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background" />
    <foreground android:drawable="@android:color/transparent" />
</adaptive-icon>
''')

# الويب: الأيقونات العادية بزوايا دائرية، و maskable بهامش 10% (المنطقة الآمنة 80%)
rounded(base, 192).save('web/icons/Icon-192.png')
rounded(base, 512).save('web/icons/Icon-512.png')
mask = crop_center(bleed, 1.25 / 1.5)
mask.resize((192, 192), Image.LANCZOS).convert('RGB').save('web/icons/Icon-maskable-192.png')
mask.resize((512, 512), Image.LANCZOS).convert('RGB').save('web/icons/Icon-maskable-512.png')
rounded(base, 64).save('web/favicon.png')
rounded(base, 512).save('tools/icon/icon-512.png')  # لصفحة التحميل
print('done')
