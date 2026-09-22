#!/usr/bin/env python3
"""Boghi City Tour v2 — richer multi-voice theme (82s), Persian funk flavor.
Structure: intro(4) A(8) B(8, lead) A2(8) B2(8, lead high) tag(2) = 38 bars.
Upgrades vs v1: stereo santur arps, full funk drums + fills, catchy lead in
two registers, distinctive intro riser, seamless loop-friendly tag.
"""
import numpy as np, wave

SR = 44100
BPM = 112.0
BEAT = 60.0 / BPM
BAR = BEAT * 4
np.random.seed(7)  # reproducible mix

NOTE = {n: 440.0 * 2 ** ((i - 9) / 12) for i, n in enumerate(
    ['C', 'C#', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'Ab', 'A', 'Bb', 'B'])}

def hz(name, octv): return NOTE[name] * 2 ** (octv - 4)

def env(n, a, d, s_level, r, sus_n):
    e = np.zeros(n)
    a_n = max(1, int(a * SR)); d_n = max(1, int(d * SR)); r_n = max(1, int(r * SR))
    e[:a_n] = np.linspace(0, 1, a_n)
    de = np.linspace(1, s_level, d_n); e[a_n:a_n+d_n] = de[:max(0, min(d_n, n - a_n))]
    sus_end = min(n - r_n, a_n + d_n + sus_n)
    if sus_end > a_n + d_n: e[a_n+d_n:sus_end] = s_level
    if r_n < n:
        st = sus_end if sus_end > 0 else n - r_n
        e[st:] = np.linspace(e[st - 1] if st > 0 else s_level, 0, n - st)
    return e[:n]

def sq(ph, duty=0.5): return np.where((ph % 1.0) < duty, 1.0, -1.0)

def voice(freq, n, kind, duty=0.5, vib=0.0, detune_c=0.0, glide_to=None):
    t = np.arange(n) / SR
    f = freq * np.ones(n)
    if glide_to is not None:  # slide (for bass turns)
        f = freq * (glide_to / freq) ** np.clip(t / max(t[-1], 1e-6), 0, 1)
    if vib > 0: f = f * (1 + vib * np.sin(2 * np.pi * 5.5 * t))
    ph = np.cumsum(f) / SR
    if kind == 'square':    w = sq(ph, duty)
    elif kind == 'pulse25': w = sq(ph, 0.25)
    elif kind == 'tri':     w = 2.0 * np.abs(2.0 * (ph % 1.0) - 1.0) - 1.0
    else:                   w = np.sin(2 * np.pi * ph)
    if detune_c > 0:
        ph2 = np.cumsum(f * 2 ** (detune_c / 1200.0)) / SR
        w2 = sq(ph2, duty) if kind == 'square' else np.sin(2 * np.pi * ph2)
        w = 0.6 * w + 0.4 * w2
    return w

def karplus(freq, n, damp=0.996):
    N = int(SR / freq)
    buf = np.random.uniform(-1, 1, N)
    out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % N]
        buf[i % N] = damp * 0.5 * (buf[i % N] + buf[(i + 1) % N])
    return out

def place(mix, sig, at, gain=1.0):
    i = int(at * SR); j = min(len(mix[0]), i + len(sig))
    if j > i:
        mix[0][i:j] += sig[:j-i] * gain
        mix[1][i:j] += sig[:j-i] * gain

def place_st(mix, sigL, sigR, at, gain=1.0):
    i = int(at * SR); j = min(len(mix[0]), i + len(sigL))
    if j > i:
        mix[0][i:j] += sigL[:j-i] * gain
        mix[1][i:j] += sigR[:j-i] * gain

# ---------- drums ----------
def kick():
    n = int(0.30 * SR); t = np.arange(n) / SR
    f = 135 * np.exp(-t * 24) + 44
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 14) * 1.15

def snare(n=int(0.22 * SR)):
    t = np.arange(n) / SR
    noise = np.random.uniform(-1, 1, n)
    body = np.sin(2 * np.pi * 195 * t) * 0.5
    return (noise * 0.75 + body) * np.exp(-t * 22)

def hat(n=int(0.09 * SR), open_=False):
    t = np.arange(n) / SR
    noise = np.random.uniform(-1, 1, n)
    for _ in range(2):
        noise = np.diff(noise, prepend=0)
    return noise * np.exp(-t * (16 if open_ else 60)) * 0.55

def riser(n):
    t = np.arange(n) / SR
    noise = np.random.uniform(-1, 1, n)
    for _ in range(3):
        noise = np.diff(noise, prepend=0)
    return noise * (t / t[-1]) ** 2 * 0.5

# ---------- song ----------
n_bars = {'intro': 4, 'A': 8, 'B': 8, 'A2': 8, 'B2': 8, 'tag': 2}
order = ['intro', 'A', 'B', 'A2', 'B2', 'tag']
total_bars = sum(n_bars.values())
dur = total_bars * BAR
mix = [np.zeros(int(dur * SR) + SR), np.zeros(int(dur * SR) + SR)]

prog_A = [('D', 'm7'), ('D', 'm7'), ('G', 'm7'), ('G', 'm7'),
          ('Bb', 'maj'), ('Bb', 'maj'), ('A', '7'), ('A', '7')]
prog_B = [('D', 'm7'), ('F', 'maj'), ('G', 'm7'), ('A', '7'),
          ('D', 'm7'), ('F', 'maj'), ('Bb', 'maj'), ('A', '7')]
CHORD_TONES = {'m7': (0, 3, 7, 10), 'maj': (0, 4, 7, 11), '7': (0, 4, 7, 10)}

timeline = []
ab = 0
for sec in order:
    for b in range(n_bars[sec]):
        timeline.append((sec, b, ab)); ab += 1

kick_pat  = [0, 0.75, 1.5, 2.25, 3.0]
snare_pat = [1.0, 3.0]
hat_pat   = [x * 0.5 for x in range(8)]
hat16     = [x * 0.25 for x in range(16)]

# lead melody (bars within B/B2 sections; note, start-beat, len-beats)
lead_bars = [
    (0, [(0, 0.5, 'D5'), (0.5, 0.25, 'Eb5'), (0.75, 0.75, 'F#5'), (1.5, 0.5, 'D5'),
         (2.25, 0.75, 'A4'), (3.0, 1.0, 'C5')]),
    (2, [(0, 0.75, 'C5'), (0.75, 0.25, 'Bb4'), (1.0, 1.0, 'A4'), (2.25, 0.5, 'G4'),
         (2.75, 1.25, 'F#4')]),
    (4, [(0, 0.5, 'D5'), (0.5, 0.25, 'Eb5'), (0.75, 0.75, 'F#5'), (1.5, 0.5, 'G5'),
         (2.0, 1.0, 'A5'), (3.0, 0.75, 'G5')]),
    (6, [(0, 0.75, 'F#5'), (0.75, 0.25, 'Eb5'), (1.0, 1.5, 'D5'), (2.75, 1.25, 'A4')]),
]
lead_high = [
    (0, [(0, 0.5, 'A5'), (0.5, 0.25, 'Bb5'), (0.75, 0.75, 'A5'), (1.5, 0.5, 'G5'),
         (2.0, 1.0, 'F#5'), (3.0, 1.0, 'D5')]),
    (2, [(0, 0.75, 'F#5'), (0.75, 0.25, 'G5'), (1.0, 1.0, 'A5'), (2.25, 0.75, 'C6'),
         (3.0, 1.0, 'A5')]),
    (4, [(0, 0.5, 'D6'), (0.5, 0.25, 'C6'), (0.75, 0.75, 'A5'), (1.5, 0.5, 'G5'),
         (2.0, 1.0, 'F#5'), (3.0, 0.75, 'G5')]),
    (6, [(0, 0.75, 'A5'), (0.75, 0.25, 'G5'), (1.0, 1.5, 'F#5'), (2.75, 1.25, 'D5')]),
]

def note_f(nm):
    octv = 5 if nm[1].isdigit() else 4
    return hz(nm[0] + ('#' if '#' in nm else ''), octv)

for sec, b, ab in timeline:
    t0 = ab * BAR
    prog = prog_B if sec in ('B', 'B2') else prog_A
    if sec == 'tag':
        root, qual = ('D', '7'); tones = CHORD_TONES[qual]
    else:
        root, qual = prog[b % len(prog)]
        tones = CHORD_TONES[qual]
    r = hz(root, 2)
    full = sec not in ('intro', 'tag')
    last_bar = (b == n_bars[sec] - 1)

    # --- drums ---
    if full:
        for p in kick_pat: place(mix, kick(), t0 + p * BEAT, 0.9)
        for p in snare_pat: place(mix, snare(), t0 + p * BEAT, 0.72)
        for i, p in enumerate(hat_pat):
            place(mix, hat(open_=(i == 7 and not last_bar)), t0 + p * BEAT, 0.38)
        if sec in ('B', 'B2'):  # 16th ghost hats for drive
            for p in hat16:
                if int(p * 4) % 2 == 1:
                    place(mix, hat(int(0.05 * SR)), t0 + p * BEAT, 0.16)
        if last_bar:  # snare fill into next section
            for k, p in enumerate([2.0, 2.25, 2.5, 2.75, 3.0, 3.25, 3.5, 3.75]):
                place(mix, snare(int(0.12 * SR)), t0 + p * BEAT, 0.3 + 0.05 * k)
    elif sec == 'intro':
        for i, p in enumerate(hat_pat): place(mix, hat(), t0 + p * BEAT, 0.33)
        place(mix, kick(), t0 + 3.0 * BEAT, 0.8)
        if last_bar:
            place(mix, riser(int(BAR * SR)), t0, 0.5)  # «همین حالا شروع می‌شود!»

    # --- bass ---
    if sec != 'intro' or last_bar:
        pat = [0, 0.5, 0.75, 1.5, 2.0, 2.75, 3.0, 3.5]
        for k, p in enumerate(pat):
            f = r if k not in (3, 7) else r * 0.5
            n = int(0.42 * BEAT * SR)
            w = voice(f, n, 'square', 0.5, detune_c=6)
            e = env(n, 0.004, 0.06, 0.55, 0.05, n)
            place(mix, w * e, t0 + p * BEAT, 0.22)

    # --- chord stabs (panned) ---
    if full:
        for i, p in enumerate((0.5, 1.5, 2.5, 3.25)):
            for iv in tones:
                f = r * 2 ** (iv / 12.0) * 2
                n = int(0.30 * BEAT * SR)
                w = voice(f, n, 'square', 0.25, detune_c=9)
                e = env(n, 0.005, 0.05, 0.4, 0.06, n)
                g = 0.62 if i % 2 == 0 else 0.38  # alternate width
                place_st(mix, w * g, w * (1.0 - g), t0 + p * BEAT, 0.16)

    # --- santur arps (wide stereo) ---
    if sec in ('A', 'B', 'A2', 'B2'):
        arp = [0, 7, 12, 15, 12, 7] if qual == 'm7' else ([0, 7, 12, 16, 12, 7] if qual == 'maj' else [0, 7, 12, 16, 19, 16])
        for k, iv in enumerate(arp):
            f = r * 2 ** (iv / 12.0) * 4
            n = int(0.5 * BEAT * SR)
            w = karplus(f, n)
            w2 = karplus(f * 1.003, n)  # doubled strings — real santur chorus
            side = k % 2
            place_st(mix, (w if side == 0 else w * 0.3) + w2 * 0.5,
                          (w * 0.3 if side == 0 else w) + w2 * 0.5,
                     t0 + (k * 0.66) * BEAT, 0.20)

    # --- intro santur motif (the «new build!» signature) ---
    if sec == 'intro':
        motif = [('D', 4, 0.0), ('A', 4, 0.5), ('Bb', 4, 1.0), ('A', 4, 1.5),
                 ('F#', 4, 2.0), ('D', 4, 2.5), ('Eb', 4, 3.0), ('D', 4, 3.5)]
        for nm, oc, p in motif:
            f = hz(nm, oc); n = int(0.6 * BEAT * SR)
            place(mix, karplus(f, n), t0 + p * BEAT, 0.26)

    # --- tag: santur roll + resolve ---
    if sec == 'tag':
        for k, iv in enumerate([0, 3, 7, 10, 12, 15, 19, 22]):
            f = r * 2 ** (iv / 12.0) * 4
            n = int(0.7 * BEAT * SR)
            place(mix, karplus(f, n), t0 + (0.25 * k) * BEAT, 0.22)

# --- lead melodies (B = mid, B2 = high + doubled) ---
for sec, b, ab in timeline:
    if sec not in ('B', 'B2'):
        continue
    t0 = ab * BAR
    for lb, notes in (lead_high if sec == 'B2' else lead_bars):
        if lb == b:
            for (p, ln, nm) in notes:
                f = note_f(nm)
                n = int(ln * BEAT * SR * 0.92)
                w = voice(f, n, 'pulse25', vib=0.007, detune_c=4)
                e = env(n, 0.01, 0.08, 0.7, 0.09, n)
                g = 0.26 if sec == 'B' else 0.30
                place_st(mix, w * 1.0, w * 0.82, t0 + p * BEAT, g)
                if sec == 'B2':  # quiet octave double for lift
                    w8 = voice(f * 2, n, 'pulse25', vib=0.007)
                    place_st(mix, w8 * 0.6, w8 * 0.6, t0 + p * BEAT, 0.07)

# ---------- mixdown ----------
L, R = mix[0][:int(dur * SR)], mix[1][:int(dur * SR)]
fade = int(0.025 * SR)
L[:fade] *= np.linspace(0, 1, fade); R[:fade] *= np.linspace(0, 1, fade)
L[-fade:] *= np.linspace(1, 0, fade); R[-fade:] *= np.linspace(1, 0, fade)
# loop-friendly: short crossfade of tail into start vibe (audio loops in-engine)
xf = int(0.15 * SR)
L[-xf:] = L[-xf:] * np.linspace(1, 0, xf) + L[:xf] * np.linspace(0, 1, xf)
R[-xf:] = R[-xf:] * np.linspace(1, 0, xf) + R[:xf] * np.linspace(0, 1, xf)
peak = max(1e-9, np.max(np.abs([L, R])))
L = np.tanh(L / peak * 1.25) * 0.86
R = np.tanh(R / peak * 1.25) * 0.86
out = np.stack([L, R], axis=1)
pcm = (out * 32767).astype('<i2')
with wave.open('/home/z/my-project/build/music_loop_raw.wav', 'wb') as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes(pcm.tobytes())
print('OK bars=%d dur=%.1fs peak=%.2f' % (total_bars, dur, peak))
