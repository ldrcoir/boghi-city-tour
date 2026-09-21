#!/usr/bin/env python3
"""Generate clank.wav — metallic wrench clang for Ustad Faner's workshop."""
import numpy as np
import wave

SR = 22050
DUR = 0.45
t = np.arange(int(SR * DUR)) / SR

# درهم‌تنیده‌ای از پارسیال‌های غیرهارمونیک فلز
partials = [(880, 1.0, 0.9), (1450, 0.7, 0.55), (2320, 0.5, 0.35), (3610, 0.35, 0.22)]
sig = np.zeros_like(t)
for f, a, dec in partials:
    sig += a * np.sin(2 * np.pi * f * t) * np.exp(-t / (dec * 0.1))

# ضربهٔ نویزی اول ۲۰ms
rng = np.random.default_rng(7)
noise = rng.standard_normal(len(t)) * np.exp(-t / 0.008) * 0.6
sig += noise

# کلیپ نرم + نرمالایز
sig = np.tanh(sig * 1.4)
sig /= np.abs(sig).max() + 1e-9
pcm = (sig * 0.85 * 32767).astype(np.int16)

with wave.open("/home/z/my-project/game/assets/audio/clank.wav", "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(pcm.tobytes())
print("clank.wav OK", len(pcm), "samples")
