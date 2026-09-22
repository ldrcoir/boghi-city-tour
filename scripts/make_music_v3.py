#!/usr/bin/env python3
"""Boghi City Tour — Theme v3 «بوقی در شهر» (68s, F major, 126 BPM).
Character: warm cheerful Persian-kart groove.
Layers: funk drums, sub-bass with slides, plucky chord stabs, santur tremolo
(Persian identity), lead melody (sine+saw, vibrato, ping-pong delay), wide pad,
16th arpeggio. Seamless wrap-around loop. Output: stereo 44.1k WAV + OGG.
"""
import numpy as np, wave, subprocess, sys

SR = 44100
BPM = 126.0
BEAT = 60.0 / BPM
BAR = BEAT * 4
EIGHTH = BEAT / 2
SIXT = BEAT / 4

NOTE = {n: 440.0 * 2 ** ((i - 9) / 12) for i, n in enumerate(
    ['C', 'C#', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'Ab', 'A', 'Bb', 'B'])}

def hz(name, octv):
    return NOTE[name] * 2 ** (octv - 4)

# ---------------------------------------------------------------- helpers
def wrap_add(buf, sig, start_s):
    """Add signal into circular buffer (seamless loop tails)."""
    n = len(buf)
    i0 = int(start_s * SR) % n
    L = len(sig)
    idx = (np.arange(L) + i0) % n
    np.add.at(buf, idx, sig)

def adsr(n, a=0.01, d=0.08, s=0.7, r=0.06):
    e = np.zeros(n)
    an = max(1, int(a * SR)); dn = max(1, int(d * SR)); rn = max(1, int(r * SR))
    an = min(an, n)
    e[:an] = np.linspace(0, 1, an)
    if an + dn < n:
        e[an:an + dn] = np.linspace(1, s, dn)
        sus = n - rn - (an + dn)
        if sus > 0:
            e[an + dn:an + dn + sus] = s
        st = max(an + dn, n - rn)
        e[st:] = np.linspace(e[st - 1] if st > 0 else s, 0, n - st)
    else:
        e[an:] = np.linspace(1, 0, n - an)
    return e

def osc_sine(f, n, vib=0.0, vib_hz=5.2):
    t = np.arange(n) / SR
    f = np.full(n, f)
    if vib: f = f * (1 + vib * np.sin(2 * np.pi * vib_hz * t))
    return np.sin(2 * np.pi * np.cumsum(f) / SR)

def osc_saw(f, n, vib=0.0):
    t = np.arange(n) / SR
    f = np.full(n, f)
    if vib: f = f * (1 + vib * np.sin(2 * np.pi * 5.2 * t))
    ph = np.cumsum(f) / SR
    return 2.0 * (ph % 1.0) - 1.0

def osc_tri(f, n):
    ph = np.cumsum(np.full(n, f)) / SR
    return 2.0 * np.abs(2.0 * (ph % 1.0) - 1.0) - 1.0

def lowpass(x, cutoff):
    from numpy.fft import rfft, irfft
    X = rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / SR)
    # gentle one-pole-like rolloff
    X *= 1.0 / (1.0 + (freqs / max(cutoff, 20)) ** 2.2)
    return irfft(X, len(x))

def delay_pp(bufL, bufR, sig, pan, time_s, fb=0.32, taps=4, level=0.35):
    """Ping-pong delay: adds sig + echoes alternating L/R."""
    n = len(bufL)
    d = int(time_s * SR)
    g = level
    # initial tap at pan
    wrap_add(bufL, sig * max(0, 1 - pan), 0) if False else None
    # echoes alternate sides
    echo = sig.copy()
    t = time_s
    for k in range(1, taps + 1):
        echo = np.concatenate([np.zeros(d), echo[:-d]]) if d < len(echo) else echo * 0
        echo = echo * fb
        if k % 2 == 1:
            wrap_add(bufR, echo * g, 0)
        else:
            wrap_add(bufL, echo * g, 0)
        g *= fb * 0.9

# ---------------------------------------------------------------- song data
# chords as (root, quality) per bar, F major
PROG_A = [('F', 'maj'), ('Dm', 'min'), ('Bb', 'maj'), ('C', 'maj')] * 2
PROG_B = [('Bb', 'maj'), ('C', 'maj'), ('F', 'maj'), ('Dm', 'min'),
          ('Bb', 'maj'), ('C', 'maj'), ('F', 'maj'), ('C', 'maj')]
PROG_T = [('Bb', 'maj'), ('C', 'maj'), ('F', 'maj'), ('C', 'maj')]

CHORD_TONES = {
    ('F', 'maj'): ['F', 'A', 'C'], ('Dm', 'min'): ['D', 'F', 'A'],
    ('Bb', 'maj'): ['Bb', 'D', 'F'], ('C', 'maj'): ['C', 'E', 'G'],
}
ROOT_OCT = {'F': 2, 'Dm': 2, 'Bb': 1, 'C': 2}

def bass_root(name):
    return name.replace('m', '')

# lead melody: list of (bar_index_in_section, note, octv, beats)
MEL_A = [
    (0, 'F', 5, 3), (0, 'G', 5, 1), (0, 'A', 5, 2), (0, 'F', 5, 2),
    (1, 'D', 5, 2), (1, 'E', 5, 2), (1, 'F', 5, 2), (1, 'D', 5, 2),
    (2, 'F', 5, 1), (2, 'G', 5, 1), (2, 'A', 5, 2), (2, 'C', 6, 2), (2, 'A', 5, 2),
    (3, 'G', 5, 3), (3, 'E', 5, 1), (3, 'G', 5, 2), (3, 'C', 5, 2),
    (4, 'C', 6, 2), (4, 'A', 5, 2), (4, 'G', 5, 2), (4, 'F', 5, 2),
    (5, 'F', 5, 2), (5, 'E', 5, 2), (5, 'D', 5, 2), (5, 'A', 4, 2),
    (6, 'Bb', 4, 2), (6, 'D', 5, 2), (6, 'F', 5, 2), (6, 'Bb', 5, 2),
    (7, 'A', 5, 2), (7, 'G', 5, 2), (7, 'F', 5, 2), (7, 'E', 5, 2),
]
MEL_B = [
    (0, 'D', 6, 1), (0, 'C', 6, 1), (0, 'Bb', 5, 2), (0, 'F', 5, 2), (0, 'D', 5, 2),
    (1, 'E', 5, 2), (1, 'G', 5, 2), (1, 'C', 6, 4),
    (2, 'A', 5, 2), (2, 'F', 5, 2), (2, 'C', 6, 2), (2, 'A', 5, 2),
    (3, 'A', 5, 2), (3, 'G', 5, 2), (3, 'F', 5, 2), (3, 'E', 5, 2),
    (4, 'D', 5, 2), (4, 'F', 5, 2), (4, 'Bb', 5, 2), (4, 'A', 5, 2),
    (5, 'G', 5, 2), (5, 'E', 5, 2), (5, 'G', 5, 2), (5, 'C', 6, 2),
    (6, 'F', 5, 4), (6, 'A', 5, 2), (6, 'C', 6, 2),
    (7, 'G', 5, 2), (7, 'E', 5, 2), (7, 'C', 5, 4),
]

# ---------------------------------------------------------------- render
def render():
    bars_total = 8 + 8 + 8 + 8 + 4
    n_total = int(round(bars_total * BAR * SR))
    bufL = np.zeros(n_total); bufR = np.zeros(n_total)

    def bar_start(i): return i * BAR

    all_bars = (PROG_A + PROG_B + PROG_A + PROG_B + PROG_T)

    # ---- drums (A and B sections, plus A' B'; tag: sparse) --------------
    for bi in range(bars_total):
        t0 = bar_start(bi)
        tag = bi >= 32
        # kick
        for b in ([0, 2] if not tag else [0]):
            n = int(0.14 * SR)
            t = np.arange(n) / SR
            f = 120 * np.exp(-t * 28) + 42
            k = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 17)
            wrap_add(bufL, k * 0.85, t0 + b * BEAT)
            wrap_add(bufR, k * 0.85, t0 + b * BEAT)
        if bi % 4 == 3 and not tag:  # syncopated kick
            n = int(0.12 * SR)
            t = np.arange(n) / SR
            f = 110 * np.exp(-t * 26) + 40
            k = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 15)
            wrap_add(bufL, k * 0.6, t0 + 3.5 * BEAT)
            wrap_add(bufR, k * 0.6, t0 + 3.5 * BEAT)
        # snare/clap 2 & 4
        if not tag or bi == 33:
            for b in [1, 3]:
                n = int(0.16 * SR)
                nz = np.random.default_rng(bi * 10 + b).standard_normal(n)
                body = np.sin(2 * np.pi * 190 * np.arange(n) / SR) * np.exp(-np.arange(n) / SR * 34)
                s = (nz * np.exp(-np.arange(n) / SR * 30) * 0.6 + body * 0.5)
                wrap_add(bufL, s * 0.5, t0 + b * BEAT)
                wrap_add(bufR, s * 0.52, t0 + b * BEAT)
        # hats 16ths
        for s16 in range(16 if not tag else 8):
            acc = 0.9 if s16 % 4 == 2 else (0.55 if s16 % 2 == 0 else 0.8)
            n = int(0.045 * SR)
            nz = np.random.default_rng(bi * 100 + s16).standard_normal(n)
            h = nz * np.exp(-np.arange(n) / SR * 140)
            hp = h - np.concatenate([[0], h[:-1]]) * 0.92  # crude highpass
            v = 0.16 * acc
            wrap_add(bufL, hp * v * 0.85, t0 + s16 * SIXT)
            wrap_add(bufR, hp * v * 1.1, t0 + s16 * SIXT)
        # open hat on 4& every 2nd bar
        if bi % 2 == 1 and not tag:
            n = int(0.22 * SR)
            nz = np.random.default_rng(bi).standard_normal(n)
            h = nz * np.exp(-np.arange(n) / SR * 22)
            hp = h - np.concatenate([[0], h[:-1]]) * 0.94
            wrap_add(bufL, hp * 0.12, t0 + 3.5 * BEAT)
            wrap_add(bufR, hp * 0.13, t0 + 3.5 * BEAT)
        # tag fill: tom ramp
        if bi == 35:
            for j, b in enumerate([2, 2.5, 3, 3.5]):
                n = int(0.18 * SR)
                t = np.arange(n) / SR
                f0 = 220 - j * 40
                tm = np.sin(2 * np.pi * (f0 * np.exp(-t * 3)) * t) * np.exp(-t * 14)
                wrap_add(bufL, tm * 0.4 * (1 + j * 0.12), t0 + b * BEAT)
                wrap_add(bufR, tm * 0.4 * (1 + j * 0.12), t0 + b * BEAT)

    # ---- bass -----------------------------------------------------------
    for bi, (ch, q) in enumerate(all_bars):
        t0 = bar_start(bi)
        rname = bass_root(ch)
        r = hz(rname, ROOT_OCT[ch])
        for b8 in range(8):
            oct_up = b8 in (3, 7)
            f = r * (2 if oct_up else 1)
            n = int(EIGHTH * SR * 0.98)
            e = adsr(n, 0.004, 0.06, 0.6, 0.05)
            x = osc_tri(f, n) * 0.7 + osc_saw(f, n) * 0.3
            x = lowpass(x, 420)
            wrap_add(bufL, x * e * 0.30, t0 + b8 * EIGHTH)
            wrap_add(bufR, x * e * 0.30, t0 + b8 * EIGHTH)

    # ---- chord plucks (off-beat stabs) -----------------------------------
    for bi, (ch, q) in enumerate(all_bars):
        t0 = bar_start(bi)
        tones = CHORD_TONES[(ch, q)]
        for stab_b in [0.5, 1.5, 2.5, 3.5]:
            for oi, tn in enumerate(tones):
                f = hz(tn, 4)
                n = int(0.30 * SR)
                e = adsr(n, 0.004, 0.14, 0.25, 0.16)
                x = osc_saw(f, n, vib=0.0) * 0.6 + osc_tri(f, n) * 0.4
                x = lowpass(x, 2600)
                p = 0.45 if oi % 2 == 0 else 0.55
                wrap_add(bufL, x * e * 0.085 * p * 2, t0 + stab_b * BEAT)
                wrap_add(bufR, x * e * 0.085 * (2 - p * 2), t0 + stab_b * BEAT)

    # ---- santur tremolo (Persian identity — B sections + tag) ------------
    for sec_off, prog in [(8, PROG_B), (24, PROG_B), (32, PROG_T)]:
        for k, (ch, q) in enumerate(prog):
            bi = sec_off + k
            t0 = bar_start(bi)
            tones = CHORD_TONES[(ch, q)]
            rng = np.random.default_rng(1000 + bi)
            for s16 in range(16):
                tn = tones[(s16 // 2) % 3]
                f = hz(tn, 5 if s16 % 4 < 2 else 4)
                n = int(SIXT * SR * 1.15)
                e = np.exp(-np.arange(n) / SR * 26)
                x = osc_tri(f, n) * 0.65 + osc_sine(f * 2.001, n) * 0.35
                x = x * e
                side = 0.75 if s16 % 4 < 2 else 0.35
                wrap_add(bufL, x * 0.075 * side * 2, t0 + s16 * SIXT)
                wrap_add(bufR, x * 0.075 * (2 - side * 2), t0 + s16 * SIXT)

    # ---- pad (wide, sections B and A') -----------------------------------
    for sec_off in [8, 16, 24]:
        for k, (ch, q) in enumerate([PROG_B, PROG_A, PROG_B][[8, 16, 24].index(sec_off)]):
            bi = sec_off + k
            t0 = bar_start(bi)
            tones = CHORD_TONES[(ch, q)]
            n = int(BAR * SR)
            for oi, tn in enumerate(tones):
                f = hz(tn, 3)
                ph = np.random.default_rng(bi * 7 + oi).uniform(0, 1)
                t = np.arange(n) / SR
                fl = f * 1.002; fr = f * 0.998
                pl = 2 * ((np.cumsum(np.full(n, fl)) / SR + ph) % 1.0) - 1
                pr = 2 * ((np.cumsum(np.full(n, fr)) / SR + ph) % 1.0) - 1
                e = np.sin(np.pi * np.minimum(t / BAR, 1.0)) ** 1.5
                xl = lowpass(pl * e, 1300); xr = lowpass(pr * e, 1300)
                wrap_add(bufL, xl * 0.030, t0)
                wrap_add(bufR, xr * 0.030, t0)

    # ---- lead melody (A + B + A' + B') -----------------------------------
    def play_mel(mel, sec_off, gain, harm=0.35, delay_on=True):
        for (b_in, nn, octv, beats) in mel:
            bi = sec_off + b_in
            t0 = bar_start(bi)
            dur = beats * BEAT
            n = int(dur * SR * 0.96)
            f = hz(nn, octv)
            x = osc_sine(f, n, vib=0.006) * (1 - harm) + osc_saw(f, n, vib=0.006) * harm
            x = lowpass(x, 3400)
            e = adsr(n, 0.012, 0.10, 0.72, 0.10)
            sig = x * e * gain
            wrap_add(bufL, sig * 0.5, t0)
            wrap_add(bufR, sig * 0.5, t0)
            if delay_on:
                # dotted-8th ping-pong echoes
                d = int(0.357 * SR)
                g = 0.30
                echo = sig.copy()
                for k in range(1, 5):
                    echo = np.concatenate([np.zeros(d), echo])[:n_total] if len(echo) + d <= n_total else np.concatenate([np.zeros(d), echo[:-d]])
                    echo = echo * g
                    dst = bufR if k % 2 == 1 else bufL
                    i0 = int(t0 * SR) % n_total
                    idx = (np.arange(len(echo)) + i0) % n_total
                    np.add.at(dst, idx, echo * 0.5)
                    g *= 0.32
    play_mel(MEL_A, 0, 0.40)
    play_mel(MEL_B, 8, 0.44)
    play_mel(MEL_A, 16, 0.38)
    play_mel(MEL_B, 24, 0.46, harm=0.5)

    # ---- 16th arp (quiet sparkle, A sections) ----------------------------
    for sec_off in [0, 16]:
        for k, (ch, q) in enumerate(PROG_A):
            bi = sec_off + k
            t0 = bar_start(bi)
            tones = CHORD_TONES[(ch, q)]
            for s16 in range(16):
                tn = tones[s16 % 3]
                f = hz(tn, 6 if s16 % 2 else 5)
                n = int(SIXT * SR * 0.9)
                e = np.exp(-np.arange(n) / SR * 34)
                x = osc_sine(f, n) * e
                side = 0.8 if s16 % 4 < 2 else 0.3
                wrap_add(bufL, x * 0.028 * side * 2, t0 + s16 * SIXT)
                wrap_add(bufR, x * 0.028 * (2 - side * 2), t0 + s16 * SIXT)

    return bufL, bufR

if __name__ == '__main__':
    L, R = render()
    peak = max(np.abs(L).max(), np.abs(R).max())
    L = np.tanh(L / peak * 1.15) * 0.90
    R = np.tanh(R / peak * 1.15) * 0.90
    st = np.stack([L, R], axis=1)
    rms = np.sqrt((st ** 2).mean())
    print(f'peak={peak:.3f} rms_after={rms:.3f} dur={len(L)/SR:.2f}s')
    pcm = (st * 32767).astype(np.int16)
    with wave.open('/home/z/my-project/build/music_v3_raw.wav', 'wb') as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error',
                    '-i', '/home/z/my-project/build/music_v3_raw.wav',
                    '-c:a', 'libvorbis', '-q:a', '5',
                    '/home/z/my-project/game/assets/audio/music_loop.ogg'], check=True)
    print('OK -> game/assets/audio/music_loop.ogg')
