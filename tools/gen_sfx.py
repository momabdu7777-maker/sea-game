"""مولّد أصوات مؤقتة (Placeholder) للعبة — يُستبدل لاحقاً بأصوات احترافية.
التشغيل: python3 tools/gen_sfx.py  (يكتب إلى assets/audio)"""
import math, random, struct, wave, os

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio')
random.seed(7)

def write(name, samples):
    peak = max(1e-9, max(abs(s) for s in samples))
    k = 0.9 / peak
    with wave.open(os.path.join(OUT, name), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, s * k)) * 32767)) for s in samples))

def env(i, n, a=0.01, r=1.0):
    t = i / n
    att = min(1.0, t / a) if a > 0 else 1.0
    return att * (1 - t) ** r

def lowpass(xs, alpha):
    y, out = 0.0, []
    for x in xs:
        y += alpha * (x - y); out.append(y)
    return out

def noise(n): return [random.uniform(-1, 1) for _ in range(n)]

# whoosh: ضوضاء بمرشح متغير
n = int(SR * 0.38); xs = noise(n); y = 0.0; out = []
for i, x in enumerate(xs):
    t = i / n; a = 0.02 + 0.25 * math.sin(math.pi * t)
    y += a * (x - y); out.append(y * math.sin(math.pi * t) ** 1.5)
write('whoosh.wav', out)

# splash: انفجار ضوضاء + ارتطام منخفض
n = int(SR * 0.55); xs = lowpass(noise(n), 0.35)
out = [xs[i] * env(i, n, 0.005, 3) + 0.6 * math.sin(2 * math.pi * (120 - 60 * i / n) * i / SR) * env(i, n, 0.002, 6) for i in range(n)]
write('splash.wav', out)

# pop: نغمة تهبط سريعاً (التقاط سمكة)
n = int(SR * 0.13); ph = 0.0; out = []
for i in range(n):
    f = 900 - 500 * i / n; ph += 2 * math.pi * f / SR
    out.append(math.sin(ph) * env(i, n, 0.01, 2))
write('pop.wav', out)

# thunk: ارتطام بعائق
n = int(SR * 0.28); xs = lowpass(noise(n), 0.15); ph = 0.0; out = []
for i in range(n):
    f = 140 - 80 * i / n; ph += 2 * math.pi * f / SR
    out.append((math.sin(ph) * 0.9 + xs[i] * 0.5) * env(i, n, 0.002, 4))
write('thunk.wav', out)

# coin: نغمتان معدنيتان
n = int(SR * 0.22); out = []
for i in range(n):
    f = 1320 if i < n * 0.35 else 1980
    out.append((math.sin(2 * math.pi * f * i / SR) + 0.3 * math.sin(4 * math.pi * f * i / SR)) * env(i, n, 0.005, 2.5))
write('coin.wav', out)

# tick: نقرة بكرة الصنارة
n = int(SR * 0.025)
write('tick.wav', [math.sin(2 * math.pi * 2400 * i / SR) * env(i, n, 0.0, 3) for i in range(n)])

# fanfare: أربيجيو انتصار
notes = [523.25, 659.25, 783.99, 1046.5]; out = []
for k, f in enumerate(notes):
    m = int(SR * (0.12 if k < 3 else 0.4))
    for i in range(m):
        out.append((math.sin(2 * math.pi * f * i / SR) + 0.25 * math.sin(6 * math.pi * f * i / SR)) * env(i, m, 0.01, 1.5))
write('fanfare.wav', out)

# waves: موج هادئ قابل للتكرار (ضوضاء بنية بموجة سعة بطيئة)
n = int(SR * 8); b = 0.0; out = []
for i in range(n):
    b = 0.985 * b + 0.06 * random.uniform(-1, 1)
    t = i / SR
    amp = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(2 * math.pi * t / 4.0 - math.pi / 2)) ** 2
    out.append(b * amp)
fade = int(SR * 0.5)  # دمج النهاية بالبداية لتكرار بلا قفزة
for i in range(fade):
    w_ = i / fade; out[i] = out[i] * w_ + out[n - fade + i] * (1 - w_)
write('waves.wav', out[: n - fade])
# reel: طقطقة بكرة الصنارة أثناء الشد (نقرة معدنية قصيرة + رنين)
n = int(SR * 0.06); xs = noise(n); ph = 0.0; out = []
for i in range(n):
    ph += 2 * math.pi * 1650 / SR
    out.append((xs[i] * 0.6 * env(i, n, 0.0, 9) + math.sin(ph) * 0.7 * env(i, n, 0.0, 5)))
write('reel.wav', out)

# snap: "طق" انقطاع الخيط — فرقعة حادة ثم رنين وتر يهبط
n = int(SR * 0.45); xs = noise(n); ph = 0.0; out = []
for i in range(n):
    t = i / n
    f = 950 * (1 - t) ** 2 + 120; ph += 2 * math.pi * f / SR
    crack = xs[i] * env(i, n, 0.0, 30)
    twang = (math.sin(ph) + 0.4 * math.sin(2.01 * ph)) * env(i, n, 0.004, 3.5) * 0.55
    out.append(crack + twang)
write('snap.wav', out)

# strain: صرير الخيط المشدود (يُشغَّل عند الخطر)
n = int(SR * 0.32); ph = 0.0; out = []
for i in range(n):
    t = i / n
    f = 520 + 90 * math.sin(2 * math.pi * 11 * t); ph += 2 * math.pi * f / SR
    saw = (ph / math.pi) % 2 - 1
    out.append(saw * math.sin(math.pi * t) ** 1.2 * 0.6)
write('strain.wav', lowpass(out, 0.3))
print('ok')
