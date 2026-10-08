#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""gen16_sfx — صداهای واقعی‌گرایانه v0.15:
wind.wav   — باد/غلتش جاده با سرعت (لوپ بی‌درز ۴ ثانیه)
ui.wav     — کلیک منو (تیک کوتاه گرم)
shift.wav  — تعویض دنده (تامپ بم + کلیک مکانیکی)
done.wav   — تیک تأیید (پنل/شروع)
"""
import numpy as np, wave, os

SR = 44100
OUT = "/home/z/my-project/game/assets/audio"

def save(name, x, sr=SR):
    x = np.clip(x, -1.0, 1.0)
    data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(data.tobytes())
    print("saved", name, len(x) / sr, "s")

def loopable(x, fade=0.02):
    """لوپ بی‌درز: کراس‌فید ابتدا/انتها"""
    n = int(len(x) * fade)
    if n < 2:
        return x
    ramp = np.linspace(0, 1, n)
    x[:n] = x[:n] * ramp + x[-n:] * (1 - ramp)
    return x[:-n]

rng = np.random.RandomState(16)

# ── باد/غلتش — نویز باندپس + موج آهسته ──
dur = 4.0
t = np.arange(int(SR * dur)) / SR
noise = rng.randn(len(t))
# باندپس ساده با FFT
sp = np.fft.rfft(noise)
freqs = np.fft.rfftfreq(len(t), 1 / SR)
band = np.exp(-((freqs - 420) / 380) ** 2) * 1.6 + np.exp(-((freqs - 90) / 60) ** 2) * 0.8
x = np.fft.irfft(sp * band, len(t))
x /= np.abs(x).max() / 0.5
lfo = 0.72 + 0.28 * np.sin(2 * np.pi * 0.37 * t + 1.2) * np.sin(2 * np.pi * 0.11 * t)
x = loopable(x * lfo * 0.9)
save("wind.wav", x)

# ── کلیک منو — تیک گرم ──
n = int(SR * 0.055)
tt = np.arange(n) / SR
click = rng.randn(n) * np.exp(-tt * 260)
sine = np.sin(2 * np.pi * 1150 * tt) * np.exp(-tt * 150) * 0.7
sine2 = np.sin(2 * np.pi * 520 * tt) * np.exp(-tt * 90) * 0.5
ui = click * 0.35 + sine + sine2
ui[:24] *= np.linspace(0, 1, 24)
save("ui.wav", ui * 0.8)

# ── تعویض دنده — تامپ بم + کلیک مکانیکی ──
n = int(SR * 0.16)
tt = np.arange(n) / SR
f = 190 * np.exp(-tt * 14) + 46
thump = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt * 22) * 0.9
mech = rng.randn(n) * np.exp(-tt * 480) * 0.5
mech[:40] *= np.linspace(0, 1, 40)
shift = thump + mech
save("shift.wav", shift * 0.85)

# ── تیک تأیید ──
n = int(SR * 0.30)
tt = np.arange(n) / SR
a = np.sin(2 * np.pi * 880 * tt) * np.exp(-tt * 24) * 0.5
b = np.sin(2 * np.pi * 1320 * (tt - 0.07).clip(0)) * np.where(tt > 0.07, np.exp(-(tt - 0.07) * 20), 0) * 0.45
done = a + b
save("done.wav", done * 0.8)

print("sfx v16 done")
