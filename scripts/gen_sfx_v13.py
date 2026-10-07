#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
افکت‌های صوتی نسخه مسابقه (v0.13) — بدون کپی‌رایت، تولید کامل برنامه‌ای:
- skid.wav  : لوپ بی‌درز جیغ لاستیک موقع دریفت
- nitro.wav : ووش نیترو (سویپ نویز + ساب-باس)
- lap.wav   : زنگ تکمیل دور (دو نُت)
- beep.wav  : بیپ شمارش معکوس (GO با pitch بالاتر پخش می‌شود)
"""
import numpy as np, wave, os

SR = 22050
OUT = "/home/z/my-project/game/assets/audio"
os.makedirs(OUT, exist_ok=True)

def save(name, x, vol=0.9):
    x = np.clip(x * vol, -1, 1)
    pcm = (x * 32767).astype(np.int16)
    with wave.open(f"{OUT}/{name}.wav", "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("OK", name, len(x) / SR, "s")

def loopify(x):
    """کراس‌فید انتها به ابتدا برای لوپ بی‌درز"""
    n = len(x) // 8
    fade = np.linspace(0, 1, n)
    x[:n] = x[:n] * fade + x[-n:] * (1 - fade)
    return x[:-n]

def bandnoise(n, lo_f, hi_f, seed=7):
    rng = np.random.default_rng(seed)
    x = rng.standard_normal(n)
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1 / SR)
    mask = np.clip((f - lo_f) / max(60.0, lo_f * 0.4), 0, 1) * np.clip((hi_f - f) / max(60.0, hi_f * 0.15), 0, 1)
    return np.fft.irfft(X * np.clip(mask, 0, 1), n)

# ─── skid: جیغ لاستیک — لوپ بی‌درز، حامل ~900-2400Hz با مدولاسیون ───
n = int(SR * 0.85)
t = np.arange(n) / SR
core = bandnoise(n, 850, 2600, seed=11)
mod = 0.72 + 0.28 * np.sin(2 * np.pi * 37 * t) * np.sin(2 * np.pi * 11 * t + 1.3)
grit = bandnoise(n, 180, 700, seed=5) * 0.45
x = (core * mod + grit) * (0.55 + 0.45 * np.clip(np.sin(2 * np.pi * 3.1 * t + 0.5), 0, 1))
save("skid", loopify(x), 0.62)

# ─── nitro: ووش بالا رونده + ساب — 0.8s ───
n = int(SR * 0.8)
t = np.arange(n) / SR
env = np.clip(t / 0.18, 0, 1) * np.exp(-3.2 * t)
sweep_f = 300 + 2600 * (t / 0.8) ** 1.6
ph = 2 * np.pi * np.cumsum(sweep_f) / SR
whoosh = bandnoise(n, 200, 4000, seed=3) * env
sub = (np.sin(ph) * 0.5 + 0.5) * env * 0.7
crackle = bandnoise(n, 1500, 5500, seed=9) * env * np.abs(np.sin(2 * np.pi * 55 * t)) * 0.8
save("nitro", whoosh + sub + crackle, 0.8)

# ─── lap: دو نُت زنگ (E6→A6) ───
def tone(f, dur, dec):
    t = np.arange(int(SR * dur)) / SR
    return np.sin(2 * np.pi * f * t) * np.exp(-dec * t) + 0.35 * np.sin(2 * np.pi * f * 2 * t) * np.exp(-dec * 2.2 * t)
a = tone(1318, 0.28, 9)
b = tone(1760, 0.5, 6)
x = np.zeros(int(SR * 0.85))
x[: len(a)] += a * 0.8
x[int(SR * 0.16): int(SR * 0.16) + len(b)] += b
save("lap", x, 0.72)

# ─── beep: بیپ شمارش معکوس ───
n = int(SR * 0.22)
t = np.arange(n) / SR
env = np.clip(t / 0.008, 0, 1) * np.exp(-14 * t) * (1 - np.clip((t - 0.16) / 0.06, 0, 1))
x = np.sign(np.sin(2 * np.pi * 640 * t)) * 0.35 + np.sin(2 * np.pi * 640 * t) * 0.65
save("beep", x * env, 0.66)
print("DONE")
