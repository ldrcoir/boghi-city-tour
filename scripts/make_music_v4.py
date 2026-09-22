#!/usr/bin/env python3
"""Boghi City Tour — Theme v4 «ماریمبای محله» (F major, 108 BPM, 32 bars ≈ 71s).
سبک کاملاً جدید به‌خواهش کاربر: ماریمبای نرم + جعبه‌موزیک + یوکللی
+ گروو ملایم بچگانه. بدون سنتور تیز، بدون سaw بیپی، بدون فانک متراکم.
لوپ بی‌درز wrap-add. خروجی: stereo 44.1k WAV + OGG q5.
"""
import numpy as np
import subprocess, sys, os

SR = 44100
BPM = 108.0
BEAT = 60.0 / BPM
BAR = BEAT * 4
BARS = 32

OUT_WAV = "/tmp/boghi_music_v4.wav"
OUT_OGG = "/home/z/my-project/game/assets/audio/music_loop.ogg"

NOTE_FREQS = {}
A4 = 440.0
NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
for octv in range(1, 8):
    for i, nm in enumerate(NAMES):
        midi = 12 * (octv + 1) + i
        NOTE_FREQS[(nm, octv)] = A4 * 2 ** ((midi - 69) / 12)

def hz(name, octv):
    return NOTE_FREQS[(name, octv)]

def wrap_add(buf, sig, start_s):
    """افزودن سیگنال با پیچش دور لوپ — لوپ بی‌درز"""
    n = len(buf)
    i0 = int(start_s * SR) % n
    L = len(sig)
    if i0 + L <= n:
        buf[i0:i0 + L] += sig
    else:
        k = n - i0
        buf[i0:] += sig[:k]
        buf[:L - k] += sig[k:]

def adsr(n, a=0.01, d=0.10, s=0.65, r=0.08):
    an = max(1, int(a * SR)); dn = max(1, int(d * SR)); rn = max(1, int(r * SR))
    sn = max(0, n - an - dn - rn)
    env = np.concatenate([
        np.linspace(0, 1, an),
        np.linspace(1, s, dn),
        np.full(sn, s),
        np.linspace(s, 0, rn),
    ])
    return env[:n] if len(env) >= n else np.pad(env, (0, n - len(env)))

def marimba(f, n, vel=1.0):
    """ماریمبا: سینوس اصلی + هارمونیک ۴م کوتاه — چکش نرم"""
    t = np.arange(n) / SR
    body = np.sin(2 * np.pi * f * t)
    clack = 0.22 * np.sin(2 * np.pi * f * 4.02 * t) * np.exp(-t * 42)
    thump = 0.15 * np.sin(2 * np.pi * f * 0.5 * t) * np.exp(-t * 18)
    env = np.exp(-t * 3.2) * adsr(n, 0.004, 0.1, 0.5, 0.12)
    return vel * env * (body + clack + thump)

def musicbox(f, n, vel=1.0):
    """جعبه‌موزیک: سینوس + پارشیال ۲ و ۶ — براق و معصوم"""
    t = np.arange(n) / SR
    s = (np.sin(2 * np.pi * f * t)
         + 0.35 * np.sin(2 * np.pi * f * 2.01 * t)
         + 0.12 * np.sin(2 * np.pi * f * 6.03 * t))
    env = np.exp(-t * 2.6)
    return vel * env * s

def uke(f, n, vel=1.0):
    """پلاک یوکللی: مثلثی با دی‌کی سریع و فیلتر"""
    t = np.arange(n) / SR
    ph = (f * t) % 1.0
    tri = 2 * np.abs(2 * ph - 1) - 1
    env = np.exp(-t * 7.5) * adsr(n, 0.002, 0.06, 0.3, 0.1)
    return vel * env * tri

def soft_bass(f, n, vel=1.0):
    t = np.arange(n) / SR
    s = np.sin(2 * np.pi * f * t) + 0.18 * (2 * (f * t % 1.0) - 1)
    env = adsr(n, 0.008, 0.09, 0.7, 0.1) * np.exp(-t * 1.4)
    return vel * env * s

def pad_chord(freqs, n, vel=1.0):
    t = np.arange(n) / SR
    s = np.zeros(n)
    for f in freqs:
        for det in (0.997, 1.0, 1.004):
            s += np.sin(2 * np.pi * f * det * t + np.random.rand() * 6.28)
    s /= (len(freqs) * 3)
    env = adsr(n, 0.6, 0.2, 0.85, 0.9)
    return vel * env * s

def lowpass(x, cutoff):
    X = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / SR)
    X[freqs > cutoff] *= 0.0
    return np.fft.irfft(X, len(x))

def kick(n=None, vel=1.0):
    n = n or int(0.16 * SR)
    t = np.arange(n) / SR
    f = 120 * np.exp(-t * 26) + 44
    s = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 16)
    return vel * s

def shaker(n=None, vel=1.0):
    n = n or int(0.07 * SR)
    x = np.random.randn(n)
    x = lowpass(x, 7500) - lowpass(x, 1800)
    t = np.arange(n) / SR
    return vel * x * np.exp(-t * 60) * 0.5

def clap(n=None, vel=1.0):
    n = n or int(0.12 * SR)
    x = np.zeros(n)
    for i, off in enumerate((0.0, 0.012, 0.024)):
        j = int(off * SR)
        m = n - j
        burst = lowpass(np.random.randn(m), 3200) * np.exp(-np.arange(m) / SR * (55 + i * 22))
        x[j:] += burst * (0.7 - i * 0.18)
    return vel * x * 0.6

def stereo(sig, pan=0.0):
    """pan -1..1"""
    gl = np.sqrt(0.5 * (1 - pan)); gr = np.sqrt(0.5 * (1 + pan))
    return sig * gl, sig * gr

def render():
    n_total = int(round(BARS * BAR * SR))
    L = np.zeros(n_total); R = np.zeros(n_total)

    def bar(i): return i * BAR

    # ------- آکوردها: F | F | Bb | C | F | Dm | Bb | C  (هر آکورد ۲ میزان)
    PROG = [
        [("F", 3), ("A", 3), ("C", 4)], [("F", 3), ("A", 3), ("C", 4)],
        [("A#", 3), ("D", 4), ("F", 4)], [("C", 4), ("E", 4), ("G", 4)],
        [("F", 3), ("A", 3), ("C", 4)], [("D", 4), ("F", 4), ("A", 4)],
        [("A#", 3), ("D", 4), ("F", 4)], [("C", 4), ("E", 4), ("G", 4)],
    ]

    # ------- ملودی ماریمبا (پنتاتونیک F) — پرسش و پاسخ بچگانه
    # (name, octv, start_beat_in_2bars, dur_beats, vel)
    PHRASES = {
        "A": [("F",4,0.0,0.75,.9),("A",4,0.75,0.75,.8),("G",4,1.5,0.5,.85),("F",4,2.0,1.0,.9),
              ("C",5,3.5,0.5,.85),("A",4,4.0,0.75,.8),("G",4,5.0,1.5,.85)],
        "A2": [("F",4,0.0,0.75,.9),("A",4,0.75,0.75,.8),("C",5,1.5,0.75,.9),("D",5,2.25,0.75,.9),
               ("C",5,3.0,1.0,.9),("A",4,4.0,0.75,.8),("G",4,4.75,0.75,.8),("F",4,5.5,1.5,.95)],
        "B": [("A",4,0.0,0.75,.85),("C",5,0.75,0.75,.9),("D",5,1.5,1.0,.95),("C",5,2.5,0.75,.85),
              ("A",4,3.25,0.75,.8),("G",4,4.0,1.0,.9),("A",4,5.0,0.5,.8),("G",4,5.5,0.5,.75)],
        "C": [("G",4,0.0,0.5,.85),("A",4,0.5,0.5,.85),("G",4,1.0,0.75,.9),("F",4,1.75,1.25,1.0)],
    }
    # چینش فرازها روی ۸ میزان اینترو-ورس (۲ میزان برای هر فراز)
    VERSE = ["A", "A2", "B", "C"]
    # کورس: همان فرازها یک اکتاو بالاتر با جعبه‌موزیک دوبل
    CHORUS = ["A", "B", "A2", "C"]

    def put_phrase(key, bar_i, oct_shift=0, vel_mul=1.0):
        for (nm, oc, sb, db, vl) in PHRASES[key]:
            f = hz(nm, oc + oct_shift)
            dur = db * BEAT
            n = max(int(dur * SR * 1.6), int(0.3 * SR))
            sig = marimba(f, n, vel=vl * vel_mul)
            pan = 0.12 if sb < 3 else -0.10
            sl, sr_ = stereo(sig, pan)
            wrap_add(L, sl, bar(bar_i) + sb * BEAT)
            wrap_add(R, sr_, bar(bar_i) + sb * BEAT)

    def put_box_double(key, bar_i):
        """جعبه‌موزیک دوبل نازک روی نت‌های بلند فراز کورس"""
        for (nm, oc, sb, db, vl) in PHRASES[key]:
            if db >= 0.75:
                f = hz(nm, oc + 1)
                n = int(db * BEAT * SR * 2.2)
                sig = musicbox(f, n, vel=0.16 * vl)
                sl, sr_ = stereo(sig, 0.32)
                wrap_add(L, sl, bar(bar_i) + sb * BEAT + 0.012)
                wrap_add(R, sr_, bar(bar_i) + sb * BEAT + 0.012)

    # ------- آرامش: بخش‌بندی ۳۲ میزانی
    # میزان‌های 0-7 : اینترو (یوکللی + شیکر + فرازهای ماریمبا نرم)
    # میزان‌های 8-15: ورس کامل (بیس + کیک اضافه می‌شود)
    # میزان‌های 16-23: کورس (+ کلپ + اکتاو بالا + جعبه‌موزیک)
    # میزان‌های 24-29: پل (پد + جعبه‌موزیک تنها)
    # میزان‌های 30-31: برگشت (فیل ترن‌اراند)
    for b8 in range(0, 32, 2):
        chord = PROG[(b8 // 2) % 8]
        freqs = [hz(nm, oc) for nm, oc in chord]

        # پد — همه‌جا ولی در پل بلندتر
        pv = 0.05 if b8 < 24 else 0.085
        sig = pad_chord([f / 2 for f in freqs], int(2 * BAR * SR), vel=pv)
        sl, sr_ = stereo(sig, 0.0)
        wrap_add(L, sl, bar(b8)); wrap_add(R, sr_, bar(b8))

        # یوکللی — الگوی کالیپسوی ملایم (۱، ۲&، ۳، ۴&)
        for b in range(2):
            beats = [(0, .9), (1.5, .6), (2.0, .8), (3.5, .6)]
            for bt, v in beats:
                t0 = bar(b8 + b) + bt * BEAT
                for k, f in enumerate(freqs):
                    n = int(0.5 * BEAT * SR)
                    sig = uke(f, n, vel=0.30 * v)
                    p = 0.35 * (k - 1)
                    sl, sr_ = stereo(sig, p)
                    wrap_add(L, sl, t0 + k * 0.008)
                    wrap_add(R, sr_, t0 + k * 0.008)

        # شیکر — هشتم‌ها، در کورس کمی بلندتر
        sv = 0.5 if 16 <= b8 < 24 else 0.34
        for e in range(8):
            t0 = bar(b8) + e * 0.5 * BEAT
            v = sv * (1.0 if e % 2 == 0 else 0.55)
            sig = shaker(vel=v)
            sl, sr_ = stereo(sig, 0.25)
            wrap_add(L, sl, t0); wrap_add(R, sr_, t0)

    # بیس + کیک — از ورس به بعد (میزان ۸+)
    for b8 in range(8, 32, 2):
        chord = PROG[(b8 // 2) % 8]
        root_f = hz(chord[0][0], chord[0][1] - 1)
        fifth_f = root_f * 1.5
        for b in range(2):
            t0 = bar(b8 + b)
            for bt, f, v in ((0.0, root_f, .95), (1.0, root_f, .7), (1.75, fifth_f, .75),
                             (2.0, root_f, .9), (3.0, fifth_f, .6), (3.5, root_f, .7)):
                n = int(0.45 * BEAT * SR)
                sig = soft_bass(f, n, vel=0.5 * v)
                wrap_add(L, sig, t0 + bt * BEAT); wrap_add(R, sig, t0 + bt * BEAT)
            # کیک نرم روی ۱ و ۳
            for bt in (0.0, 2.0):
                sig = kick(vel=0.72)
                wrap_add(L, sig, t0 + bt * BEAT); wrap_add(R, sig, t0 + bt * BEAT)

    # کلپ — فقط کورس (میزان ۱۶-۲۳)
    for b in range(16, 24):
        for bt in (1.0, 3.0):
            sig = clap(vel=0.5)
            sl, sr_ = stereo(sig, -0.08)
            wrap_add(L, sl, bar(b) + bt * BEAT)
            wrap_add(R, sr_, bar(b) + bt * BEAT)

    # ملودی‌ها
    for i, key in enumerate(VERSE):
        vel = 0.75 if i == 0 else 0.95
        put_phrase(key, i * 2, 0, vel)
    for i, key in enumerate(CHORUS):
        put_phrase(key, 16 + i * 2, 1, 0.9)
        put_box_double(key, 16 + i * 2)

    # پل (میزان ۲۴-۲۹): جعبه‌موزیک معصوم روی پد — نفس‌گیری
    BRIDGE = [("F",5,0.0,1.5,.7),("G",5,2.0,0.5,.6),("A",5,2.5,1.5,.75),
              ("C",6,4.5,0.5,.6),("A",5,5.0,1.0,.7),("G",5,6.0,1.5,.7),
              ("F",5,8.0,1.5,.75),("G",5,10.0,0.5,.6),("A",5,10.5,1.0,.7),
              ("D",6,11.5,1.0,.65),("C",6,12.5,2.0,.8),
              ("A",5,16.0,1.0,.7),("G",5,17.0,1.0,.65),("F",5,18.0,2.5,.8),
              ("G",5,21.0,1.0,.6),("A",5,22.0,1.0,.65),("A#",5,23.0,1.0,.7)]
    for (nm, oc, sb, db, vl) in BRIDGE:
        f = hz(nm, oc)
        n = int(db * BEAT * SR * 2.0)
        sig = musicbox(f, n, vel=0.30 * vl)
        sl, sr_ = stereo(sig, 0.18 if sb < 12 else -0.18)
        wrap_add(L, sl, bar(24) + sb * BEAT)
        wrap_add(R, sr_, bar(24) + sb * BEAT)

    # برگشت پایانی (میزان ۳۰-۳۱): فراز C ماریمبا + رولد شیکر
    put_phrase("C", 30, 0, 1.0)
    for e in range(8):
        v = 0.3 + e * 0.08
        sig = shaker(vel=v)
        wrap_add(L, sig, bar(31) + e * 0.5 * BEAT)
        wrap_add(R, sig, bar(31) + e * 0.5 * BEAT)

    # ------- میکس نهایی
    mix = np.stack([L, R], axis=1)
    # سافت‌کلیپ ملایم و نرمالایز به -1.5dBFS
    mix = np.tanh(mix * 1.15)
    peak = np.max(np.abs(mix))
    mix = mix / peak * (10 ** (-1.5 / 20))
    pcm = (mix * 32767).astype(np.int16)
    import wave
    w = wave.open(OUT_WAV, "w")
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes(pcm.tobytes()); w.close()
    print("WAV:", OUT_WAV, round(n_total / SR, 1), "s")

def encode():
    subprocess.run([
        "ffmpeg", "-y", "-loglevel", "error",
        "-i", OUT_WAV, "-c:a", "libvorbis", "-q:a", "5",
        OUT_OGG,
    ], check=True)
    print("OGG:", OUT_OGG, os.path.getsize(OUT_OGG), "bytes")

if __name__ == "__main__":
    np.random.seed(4)
    render()
    encode()
