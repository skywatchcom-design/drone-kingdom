"""Composes the 30-second store-video track (docs/store/video/promo_music.ogg).

An original piece synthesized from scratch with numpy, so there is nothing to license.
Upbeat and driving (owner, 12.10.2026: "rhythmic music for an ad"): D minor at 128 BPM, exactly
16 bars = 30 s, so every shot of the video can cut on a bar line (one bar = 1.875 s).
  bars 0-1   hook: a big hit, low drone, ticking hats
  bars 2-3   build: snare roll and a riser into bar 4
  bars 4-11  full groove: kick, snare, hats, eighth-note bass, brass stabs, horn motif
  bars 12-13 Iron Fang: toms and the motif an octave up
  bar 14     final hit for the logo, ringing out to 30 s
Run: python tools/make_promo_music.py  (needs numpy, scipy and ffmpeg on the PATH)
"""
import numpy as np, subprocess, wave, os
from scipy.signal import lfilter

RATE = 44100
BPM = 128
BEAT = 60.0 / BPM
BAR = BEAT * 4
BARS = 16
LEN = int(RATE * BAR * BARS)
rng = np.random.default_rng(23)
out = np.zeros(LEN)


def hz(n):
    return 440.0 * 2 ** ((n - 69) / 12.0)


def tt(dur):
    return np.arange(int(RATE * dur)) / RATE


def env(n, a, r):
    t = np.arange(n) / RATE
    return np.minimum(1.0, t / max(a, 1e-4)) * np.exp(-t / r)


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / RATE)
    return lfilter([1 - a], [1, -a], x)


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def saw(f, t):
    return 2 * ((f * t) % 1.0) - 1


def add(start, sig, gain=1.0):
    i = int(start * RATE)
    if i >= LEN:
        return
    j = min(LEN, i + len(sig))
    out[i:j] += gain * sig[: j - i]


def kick(start, vel=1.0):
    t = tt(0.45)
    f = 48 + 110 * np.exp(-t / 0.035)
    body = np.sin(2 * np.pi * np.cumsum(f) / RATE) * env(len(t), 0.001, 0.16)
    click = rng.standard_normal(len(t)) * env(len(t), 0.0005, 0.004)
    add(start, 0.55 * vel * (body + 0.3 * click))


def snare(start, vel=1.0):
    t = tt(0.3)
    noise = highpass(lowpass(rng.standard_normal(len(t)), 7000.0), 900.0)
    body = np.sin(2 * np.pi * 185 * t) * env(len(t), 0.001, 0.05)
    add(start, 0.32 * vel * (noise * env(len(t), 0.001, 0.09) + 0.6 * body))


def hat(start, vel=1.0, open_=False):
    t = tt(0.25 if open_ else 0.06)
    noise = highpass(rng.standard_normal(len(t)), 7000.0)
    add(start, 0.09 * vel * noise * env(len(t), 0.0005, 0.08 if open_ else 0.018))


def tom(start, note, vel=1.0):
    t = tt(0.5)
    f = hz(note) * (1 + 0.5 * np.exp(-t / 0.04))
    s = np.sin(2 * np.pi * np.cumsum(f) / RATE) * env(len(t), 0.001, 0.2)
    add(start, 0.4 * vel * s)


def boom(start, vel=1.0, length=3.0):
    """Cinematic impact: a deep falling sine, a noise burst and a long low tail."""
    t = tt(length)
    f = 30 + 70 * np.exp(-t / 0.12)
    sub = np.sin(2 * np.pi * np.cumsum(f) / RATE) * env(len(t), 0.002, length * 0.35)
    burst = lowpass(rng.standard_normal(len(t)), 2500.0) * env(len(t), 0.001, 0.25)
    add(start, 0.75 * vel * (sub + 0.5 * burst))


def brass(start, notes, dur, vel=1.0, cutoff=1800.0):
    t = tt(dur)
    s = sum(saw(hz(n) * d, t) for n in notes for d in (0.997, 1.0, 1.004))
    shape = np.minimum(1, t / 0.015) * np.exp(-t / max(dur * 0.6, 0.05))
    add(start, 0.05 * vel * lowpass(s, cutoff) * shape)


# D minor: Dm  Bb  F  C, one chord per bar.
CHORDS = [[38, 50, 53, 57, 62], [34, 46, 50, 53, 58], [41, 48, 53, 57, 60], [36, 48, 52, 55, 60]]

# Hook: a hit, a low drone and ticking sixteenths.
boom(0.0, 1.0, 3.5)
drone = tt(BAR * 4)
add(0.0, 0.07 * lowpass(saw(hz(26), drone) + saw(hz(26) * 1.006, drone), 300.0) * np.minimum(1, drone / 0.5) * np.minimum(1, (BAR * 4 - drone) / 0.2))
for k in range(32):
    hat(k * BEAT / 4, 0.5 + 0.3 * (k % 4 == 0))
brass(BAR, CHORDS[0][1:4], BEAT * 1.5, 0.9)

# Build: snare roll swelling into bar 4, and a noise riser.
for k in range(24):
    at = 2 * BAR + k * BEAT / 2 if k < 8 else 3 * BAR + (k - 8) * BEAT / 4
    snare(at, 0.25 + 0.75 * k / 23)
for b in (2, 3):
    kick(b * BAR, 0.9)
    kick(b * BAR + 2 * BEAT, 0.7)
rt = tt(BAR * 2)
riser = highpass(rng.standard_normal(len(rt)), 1500.0) * (rt / (BAR * 2)) ** 2
add(2 * BAR, 0.18 * riser)

# Groove (bars 4-13): kick on every beat, snare on 2 and 4, sixteenth hats, eighth bass, brass stabs.
for b in range(4, 14):
    ch = CHORDS[b % 4]
    t0 = b * BAR
    for k in range(4):
        kick(t0 + k * BEAT)
    snare(t0 + BEAT)
    snare(t0 + 3 * BEAT)
    for k in range(16):
        hat(t0 + k * BEAT / 4, 1.0 if k % 2 == 0 else 0.55, open_=(k % 8 == 6))
    for k in range(8):
        n = ch[0] + (12 if k % 2 else 0)
        t = tt(BEAT / 2 * 0.9)
        s = lowpass(saw(hz(n), t) + 0.5 * np.sin(2 * np.pi * hz(n) * t), 700.0) * env(len(t), 0.003, 0.18)
        add(t0 + k * BEAT / 2, 0.16 * s)
    # Brass stabs on the off-beat pattern 1, 2-and, 4.
    for pos, ln in ((0.0, 0.5), (1.5, 0.35), (3.0, 0.6)):
        brass(t0 + pos * BEAT, ch[1:4], ln * BEAT * 2, 0.8)
    if b in (12, 13):
        for k, n in enumerate((50, 47, 45, 43)):
            tom(t0 + 3 * BEAT + k * BEAT / 4, n, 0.9)
    if b == 13:
        for k in range(8):
            snare(t0 + 2 * BEAT + k * BEAT / 4, 0.4 + 0.08 * k)

# Horn motif over bars 6-9 and an octave up over bars 12-13.
MOTIF = [(62, 1.0), (65, 0.5), (69, 1.5), (67, 1.0), (65, 1.0), (69, 1.0), (74, 2.0),
         (72, 1.0), (70, 1.0), (69, 1.0), (65, 1.0), (67, 2.0), (62, 2.0)]
for start_bar, shift, gain in ((6, 0, 0.08), (12, 12, 0.06)):
    pos = start_bar * BAR
    for note, beats in MOTIF:
        dur = beats * BEAT
        if pos >= 14 * BAR:
            break
        t = tt(dur * 1.02)
        f = hz(note + shift) * (1 + 0.004 * np.sin(2 * np.pi * 5.5 * t) * np.minimum(1, t / 0.25))
        ph = 2 * np.pi * np.cumsum(f) / RATE
        tone = np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.25 * np.sin(3 * ph) + 0.1 * np.sin(4 * ph)
        shape = np.minimum(1, t / 0.03) * np.minimum(1, np.maximum(0, dur * 1.02 - t) / 0.06)
        add(pos, gain * lowpass(tone, 3200.0) * shape)
        pos += dur

# Final hit at bar 14 for the logo: a boom and a held brass chord ringing out.
boom(14 * BAR, 1.1, 4.0)
kick(14 * BAR, 1.2)
brass(14 * BAR, [38, 50, 57, 62, 65], BAR * 2, 1.4, 2400.0)

# A short hall, then a soft limiter.
wet = np.zeros(LEN)
for d, g in ((0.09, 0.18), (0.21, 0.12), (0.37, 0.07)):
    wet[int(d * RATE):] += g * out[: LEN - int(d * RATE)]
mix = out + lowpass(wet, 5000.0)
fade = np.ones(LEN)
fade[-int(RATE * 0.6):] = np.linspace(1, 0, int(RATE * 0.6))
mix = np.tanh(3.2 * mix / np.max(np.abs(mix))) * fade
mix = mix / np.max(np.abs(mix)) * 0.9
pcm = (mix * 32767).astype(np.int16)
os.makedirs("docs/store/video", exist_ok=True)
wav = "docs/store/video/promo_music.wav"
with wave.open(wav, "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE); w.writeframes(pcm.tobytes())
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "5", "docs/store/video/promo_music.ogg"], check=True)
os.remove(wav)
print("length %.2f s, bar %.4f s" % (LEN / RATE, BAR))
