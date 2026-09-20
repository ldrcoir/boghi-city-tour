#!/usr/bin/env python3
"""Synthesize all game audio: SFX + chiptune music loop. Pure numpy, no dependencies on any brand."""
import numpy as np
import wave
import os

SR = 22050
OUT = "/home/z/my-project/game/assets/audio"
os.makedirs(OUT, exist_ok=True)

def save(name, data, vol=0.9):
    data = np.asarray(data, dtype=np.float64)
    peak = np.max(np.abs(data)) or 1.0
    data = data / peak * vol
    pcm = (data * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print(f"{name:16s} {len(data)/SR:.2f}s")

def t(dur):
    return np.linspace(0, dur, int(SR * dur), endpoint=False)

def env(n, a=0.01, d=None):
    """attack/decay envelope over n samples"""
    if d is None:
        d = n / SR
    x = t(d)
    e = np.minimum(x / max(a, 1e-4), 1.0) * np.exp(-3.2 * x / d)
    return e[:n]

def sine(f, dur):
    return np.sin(2 * np.pi * f * t(dur))

def square(f, dur, duty=0.5):
    return np.where((f * t(dur)) % 1.0 < duty, 1.0, -1.0)

def tri(f, dur):
    return 2 * np.abs(2 * ((f * t(dur)) % 1) - 1) - 1

def sweep(f0, f1, dur, kind="sine"):
    x = t(dur)
    f = f0 + (f1 - f0) * (x / dur)
    ph = 2 * np.pi * np.cumsum(f) / SR
    if kind == "square":
        return np.where((ph / (2 * np.pi)) % 1 < 0.5, 1.0, -1.0)
    return np.sin(ph)

def noise(dur):
    return np.random.uniform(-1, 1, int(SR * dur))

def lowpass(x, alpha):
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += alpha * (v - acc)
        y[i] = acc
    return y

# ---------------- SFX ----------------
# horn: Boghi's happy double beep (signature!)
def horn():
    a = square(660, 0.16, 0.4) * env(int(SR*0.16), 0.005, 0.16)
    b = square(880, 0.22, 0.4) * env(int(SR*0.22), 0.005, 0.22)
    gap = np.zeros(int(SR * 0.06))
    return np.concatenate([a, gap, b])

# coin: sparkle blip up
def coin():
    a = sine(1320, 0.06) * env(int(SR*0.06), 0.002, 0.06)
    b = sine(1980, 0.12) * env(int(SR*0.12), 0.002, 0.12)
    return np.concatenate([a, b])

# jump: quick rising whoosh
def jump():
    x = sweep(320, 940, 0.28)
    return x * env(len(x), 0.004, 0.28)

# boost: airy rising roar
def boost():
    x = sweep(140, 720, 0.55, "square") * 0.4
    n = lowpass(noise(0.55), 0.25) * 0.8
    e = env(int(SR*0.55), 0.01, 0.55)
    return (x + n) * e

# crash/hit: thumpy noise burst
def crash():
    n = lowpass(noise(0.35), 0.12) * 1.0
    th = sine(90, 0.25) * env(int(SR*0.25), 0.002, 0.25) * 0.9
    n[:len(th)] += th
    return n * env(int(SR*0.35), 0.002, 0.35)

# win: little fanfare
def win():
    notes = [523.25, 659.25, 783.99, 1046.5]
    parts = []
    for i, f in enumerate(notes):
        d = 0.16 if i < 3 else 0.5
        s = (square(f, d, 0.35) * 0.6 + tri(f/2, d) * 0.5)
        parts.append(s * env(int(SR*d), 0.004, d))
    return np.concatenate(parts)

# fail: descending sad horn
def fail():
    a = square(392, 0.25, 0.4) * env(int(SR*0.25), 0.005, 0.25)
    b = square(311, 0.45, 0.4) * env(int(SR*0.45), 0.005, 0.45)
    return np.concatenate([a, b])

# engine idle loop
def engine():
    dur = 1.0
    x = t(dur)
    f = 82 + 6 * np.sin(2 * np.pi * 9 * x)
    ph = 2 * np.pi * np.cumsum(f) / SR
    s = np.sign(np.sin(ph)) * 0.35 + np.sin(ph * 0.5) * 0.65
    return lowpass(s, 0.09)

save("horn.wav", horn(), 0.75)
save("coin.wav", coin(), 0.7)
save("jump.wav", jump(), 0.8)
save("boost.wav", boost(), 0.85)
save("crash.wav", crash(), 0.9)
save("win.wav", win(), 0.85)
save("fail.wav", fail(), 0.8)
save("engine.wav", engine(), 0.5)

# ---------------- MUSIC LOOP ----------------
# 8 bars, 120 BPM, happy chiptune with a Persian-shaded melody
BPM = 112
beat = 60.0 / BPM
total = beat * 4 * 8  # 8 bars of 4/4

def note_freq(semi_from_a4):
    return 440.0 * 2 ** (semi_from_a4 / 12)

C4, D4, E4, F4, G4, A4, B4 = -9, -7, -5, -4, -2, 0, 2
C5, D5, E5, F5, G5, A5, B5 = 3, 5, 7, 8, 10, 12, 14

def render_note(buf, start, dur, freq, wave_kind="square", vol=0.5, duty=0.35):
    i0 = int(start * SR)
    n = int(dur * SR)
    if i0 + n > len(buf):
        n = len(buf) - i0
    if n <= 0:
        return
    x = t(dur)[:n]
    if wave_kind == "square":
        s = np.where((freq * x) % 1.0 < duty, 1.0, -1.0) * 0.6
    elif wave_kind == "tri":
        s = tri(freq, dur)[:n]
    else:
        s = np.sin(2 * np.pi * freq * x)
    e = env(n, 0.008, dur)
    buf[i0:i0+n] += s * e * vol

buf = np.zeros(int(total * SR) + 1)

# chord roots (per 2 bars): C, Am, F, G
roots = [C4, A3 := -12, F3 := -16, G3 := -14]  # C4, A3, F3, G3 (as semitones from A4)
chords = [
    [C4, E4, G4],           # C
    [A3 := -12, C4, E4],    # Am
    [F3 := -16, A3 := -12, C4],  # F
    [G3 := -14, B4, D5],    # G
]

# melody: 8 bars, eighth notes, Persian-shaded pentatonic-ish phrase
mel = [
    # bar1        bar2
    [C5, E5, G5, E5,  A5, G5, E5, D5],
    [C5, D5, E5, G5,  E5, D5, C5, None],
    [D5, F5, A5, F5,  B5, A5, F5, E5],
    [D5, E5, F5, G5,  E5, None, C5, None],
    [C5, E5, G5, E5,  A5, G5, E5, D5],
    [C5, D5, E5, G5,  E5, D5, C5, None],
    [A4, C5, D5, E5,  D5, C5, A4, G4],
    [C5, None, C5, C5,  C5, None, None, None],
]

for bar in range(8):
    ch = chords[(bar // 2) % 4]
    bar_t = bar * 4 * beat
    # bass: root eighths
    for i in range(8):
        f = note_freq(ch[0] - 12 if i % 4 == 0 else ch[0])
        render_note(buf, bar_t + i * beat / 2, beat / 2 * 0.9, f, "tri", 0.45)
    # chord pad on beat 1
    for semi in ch:
        render_note(buf, bar_t, beat * 1.8, note_freq(semi), "square", 0.10, 0.5)
    # melody eighths
    for i, semi in enumerate(mel[bar]):
        if semi is None:
            continue
        render_note(buf, bar_t + i * beat / 2, beat / 2 * 0.95, note_freq(semi), "square", 0.30, 0.30)

# percussion: kick on 1&3, hat on 8ths
rng = np.random.default_rng(7)
for bar in range(8):
    bar_t = bar * 4 * beat
    for b in (0, 2):
        i0 = int((bar_t + b * beat) * SR)
        n = int(0.12 * SR)
        kick = np.sin(2 * np.pi * np.linspace(120, 45, n) * 0.5) * np.exp(-np.linspace(0, 30, n))
        buf[i0:i0+n] += kick[:min(n, len(buf)-i0)] * 0.8
    for i in range(8):
        i0 = int((bar_t + i * beat / 2) * SR)
        n = int(0.05 * SR)
        hat = rng.uniform(-1, 1, n) * np.exp(-np.linspace(0, 8, n)) * 0.25
        buf[i0:i0+n] += hat[:min(n, len(buf)-i0)]

save("music_loop.wav", buf, 0.8)
print("ALL AUDIO DONE")
