#!/usr/bin/env python3
"""Boghi City Tour — multi-voice chiptune-funk theme, Persian flavor.
Sections: intro / A / B / A' with drums, bass, chords, lead, santur plucks.
Output: 44.1kHz stereo WAV -> encoded to OGG by ffmpeg downstream.
"""
import numpy as np, wave, sys

SR = 44100
BPM = 112.0
BEAT = 60.0 / BPM          # one beat (quarter)
BAR = BEAT * 4             # 4/4 bar
# D hijaz-ish: D, Eb, F#, G, A, Bb, C  -> fun "Persian funk" flavor
NOTE = {n: 440.0 * 2 ** ((i - 9) / 12) for i, n in enumerate(
    ['C','C#','D','Eb','E','F','F#','G','Ab','A','Bb','B'])}

def hz(name, octv): return NOTE[name] * 2 ** (octv - 4)

def env(n, a, d, s_level, r, sus_n):
    """attack/decay/sustain/release envelope over n samples"""
    e = np.zeros(n)
    a_n = max(1, int(a * SR)); d_n = max(1, int(d * SR)); r_n = max(1, int(r * SR))
    e[:a_n] = np.linspace(0, 1, a_n)
    de = np.linspace(1, s_level, d_n); e[a_n:a_n+d_n] = de[:max(0, min(d_n, n-a_n))]
    sus_end = min(n - r_n, a_n + d_n + sus_n)
    if sus_end > a_n + d_n: e[a_n+d_n:sus_end] = s_level
    if r_n < n: e[sus_end if sus_end > 0 else n-r_n:] = np.linspace(
        e[n-r_n-1] if n-r_n-1 > 0 else s_level, 0, r_n)
    return e[:n]

def sq(ph, duty=0.5): return np.where((ph % 1.0) < duty, 1.0, -1.0)
def saw(ph): return 2.0 * (ph % 1.0) - 1.0

def voice(freq, n, kind, duty=0.5, vib=0.0, detune_c=0.0):
    t = np.arange(n) / SR
    f = freq * np.ones(n)
    if vib > 0: f = f * (1 + vib * np.sin(2 * np.pi * 5.5 * t))
    ph = np.cumsum(f) / SR
    if kind == 'square':  w = sq(ph, duty)
    elif kind == 'saw':   w = saw(ph)
    elif kind == 'pulse12': w = sq(ph, 0.125)
    else: w = np.sin(2 * np.pi * ph)
    if detune_c > 0:  # detuned second osc for width/fatness
        ph2 = np.cumsum(f * 2 ** (detune_c / 1200.0)) / SR
        w2 = sq(ph2, duty) if kind == 'square' else np.sin(2 * np.pi * ph2)
        w = 0.6 * w + 0.4 * w2
    return w

def karplus(freq, n, damp=0.996):
    """santur-like plucked string"""
    N = int(SR / freq)
    buf = np.random.uniform(-1, 1, N)
    out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % N]
        buf[i % N] = damp * 0.5 * (buf[i % N] + buf[(i + 1) % N])
    return out

def place(mix, sig, at, gain=1.0):
    i = int(at * SR)
    j = min(len(mix[0]), i + len(sig))
    if j > i:
        mix[0][i:j] += sig[:j-i] * gain
        mix[1][i:j] += sig[:j-i] * gain

def place_st(mix, sigL, sigR, at, gain=1.0):
    i = int(at * SR)
    j = min(len(mix[0]), i + len(sigL))
    if j > i:
        mix[0][i:j] += sigL[:j-i] * gain
        mix[1][i:j] += sigR[:j-i] * gain

# ---------- drums ----------
def kick(n=int(0.28 * SR)):
    t = np.arange(n) / SR
    f = 130 * np.exp(-t * 26) + 42
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 15) * 1.1

def snare(n=int(0.22 * SR)):
    t = np.arange(n) / SR
    noise = np.random.uniform(-1, 1, n)
    body = np.sin(2 * np.pi * 190 * t) * 0.5
    return (noise * 0.8 + body) * np.exp(-t * 24)

def hat(n=int(0.09 * SR), open_=False):
    t = np.arange(n) / SR
    noise = np.random.uniform(-1, 1, n)
    for _ in range(2):  # crude highpass
        noise = np.diff(noise, prepend=0)
    return noise * np.exp(-t * (18 if open_ else 60)) * 0.6

# ---------- song structure ----------
n_bars = {'intro': 2, 'A': 8, 'B': 8, 'A2': 8}
order = ['intro', 'A', 'B', 'A2']
total_bars = sum(n_bars.values())
dur = total_bars * BAR
mix = [np.zeros(int(dur * SR) + SR), np.zeros(int(dur * SR) + SR)]

# chord progression per bar (root, quality) — D minor-ish funk
prog_A = [('D', 'm7'), ('D', 'm7'), ('G', 'm7'), ('G', 'm7'),
          ('Bb', 'maj'), ('Bb', 'maj'), ('A', '7'), ('A', '7')]
prog_B = [('D', 'm7'), ('F', 'maj'), ('G', 'm7'), ('A', '7'),
          ('D', 'm7'), ('F', 'maj'), ('Bb', 'maj'), ('A', '7')]
CHORD_TONES = {'m7': (0, 3, 7, 10), 'maj': (0, 4, 7, 11), '7': (0, 4, 7, 10)}

def bar_time(bi): return order_map[bi]

# build timeline
timeline = []  # (section, bar_index_within_section, absolute_bar)
ab = 0
for sec in order:
    for b in range(n_bars[sec]):
        timeline.append((sec, b, ab)); ab += 1

kick_pat  = [0, 0.75, 1.5, 2.25, 3.0]           # funk kick
snare_pat = [1.0, 3.0]
hat_pat   = [x * 0.5 for x in range(8)]

for sec, b, ab in timeline:
    t0 = ab * BAR
    prog = prog_A if sec in ('A', 'A2', 'intro') else prog_B
    root, qual = prog[b % len(prog)]
    tones = CHORD_TONES[qual]
    r = hz(root, 2)

    # --- drums (skip most of intro) ---
    if sec != 'intro':
        for p in kick_pat:  place(mix, kick(), t0 + p * BEAT, 0.9)
        for p in snare_pat: place(mix, snare(), t0 + p * BEAT, 0.75)
        for i, p in enumerate(hat_pat):
            place(mix, hat(open_=(i == 7)), t0 + p * BEAT, 0.4)
    else:  # intro: hats + kick pickup
        for i, p in enumerate(hat_pat): place(mix, hat(), t0 + p * BEAT, 0.35)
        place(mix, kick(), t0 + 3.0 * BEAT, 0.8)

    # --- bass: root+octave funk pattern ---
    pat = [0, 0.5, 0.75, 1.5, 2.0, 2.75, 3.0, 3.5]
    for k, p in enumerate(pat):
        octv = 1 if k in (3, 7) else 2
        f = r * 2 ** (octv - 2) if octv == 1 else r
        n = int(0.42 * BEAT * SR)
        w = voice(f if octv == 2 else f * 2, n, 'square', 0.5, detune_c=6)
        e = env(n, 0.004, 0.06, 0.55, 0.05, n)
        place(mix, w * e, t0 + p * BEAT, 0.21)

    # --- chord stabs (off-beat pulse) ---
    if sec != 'intro':
        for p in (0.5, 1.5, 2.5, 3.25):
            for iv in tones:
                f = r * 2 ** (iv / 12.0) * 2  # mid register
                n = int(0.30 * BEAT * SR)
                w = voice(f, n, 'square', 0.25, detune_c=9)
                e = env(n, 0.005, 0.05, 0.4, 0.06, n)
                panL, panR = w * 0.8, w * 0.8
                place_st(mix, panL, panR, t0 + p * BEAT, 0.15)

    # --- santur plucks (Persian sparkle) ---
    if sec in ('A', 'B', 'A2'):
        arp = [0, 7, 12, 15, 12, 7] if qual in ('m7',) else [0, 7, 12, 16, 12, 7]
        for k, iv in enumerate(arp):
            f = r * 2 ** (iv / 12.0) * 4
            n = int(0.5 * BEAT * SR)
            w = karplus(f, n)
            place(mix, w, t0 + (k * 0.66) * BEAT, 0.22)

# --- lead melody over A2 (call-and-answer phrase) ---
lead_bars = [(0,[(0,0.5,'D5'),(0.5,0.25,'Eb5'),(0.75,0.75,'F#5'),(1.5,0.5,'D5'),
                 (2.25,0.75,'A4'),(3.0,1.0,'C5')]),
             (2,[(0,0.75,'C5'),(0.75,0.25,'Bb4'),(1.0,1.0,'A4'),(2.25,0.5,'G4'),
                 (2.75,1.25,'F#4')]),
             (4,[(0,0.5,'D5'),(0.5,0.25,'Eb5'),(0.75,0.75,'F#5'),(1.5,0.5,'G5'),
                 (2.0,1.0,'A5'),(3.0,0.75,'G5')]),
             (6,[(0,0.75,'F#5'),(0.75,0.25,'Eb5'),(1.0,1.5,'D5'),(2.75,1.25,'A4')])]
for sec, b, ab in timeline:
    if sec == 'A2':
        for lb, notes in lead_bars:
            if lb == b:
                for (p, ln, nm) in notes:
                    nm2 = nm; octv = 5 if nm2[1].isdigit() else 4
                    f = hz(nm2[0] + ('#' if '#' in nm2 else ''), octv)
                    n = int(ln * BEAT * SR * 0.92)
                    w = voice(f, n, 'square', 0.4, vib=0.006, detune_c=4)
                    e = env(n, 0.01, 0.08, 0.7, 0.09, n)
                    place_st(mix, w * 1.0, w * 0.85, ab * BAR + p * BEAT, 0.26)

# fade edges, soft clip, write
L, R = mix[0][:int(dur*SR)], mix[1][:int(dur*SR)]
fade = int(0.03 * SR)
L[:fade] *= np.linspace(0, 1, fade); L[-fade:] *= np.linspace(1, 0, fade)
R[:fade] *= np.linspace(0, 1, fade); R[-fade:] *= np.linspace(1, 0, fade)
# loop-friendly: crossfade last beat into a gentle tail (engine loops via finished anyway)
peak = max(1e-9, np.max(np.abs([L, R])))
L = np.tanh(L / peak * 1.15) * 0.85
R = np.tanh(R / peak * 1.15) * 0.85
out = np.stack([L, R], axis=1)
pcm = (out * 32767).astype('<i2')
with wave.open('/home/z/my-project/build/music_loop_raw.wav', 'wb') as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes(pcm.tobytes())
print('OK bars=%d dur=%.1fs peak=%.2f' % (total_bars, dur, peak))
