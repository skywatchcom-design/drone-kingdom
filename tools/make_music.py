"""Composes the base-screen music loop (assets/audio/base_theme.ogg).

An original piece synthesized from scratch with numpy, so there is nothing to license.
Slow and martial (owner feedback 7.10.2026: the first calm version was too sleepy):
D minor at 70 BPM on i-VI-III-VII, low brass-like pads, a string ostinato, timpani on the
downbeats, a military snare pattern with rolls, and a horn melody that answers itself every
four bars.
Run: python tools/make_music.py  (needs numpy and ffmpeg on the PATH)
"""
import numpy as np, subprocess, wave, os

RATE = 32000
BPM = 70
BEAT = 60.0 / BPM
BAR = BEAT * 4
BARS = 16
LEN = int(RATE * BAR * BARS)
rng = np.random.default_rng(11)
out = np.zeros(LEN)


def hz(n):  # MIDI note to frequency
    return 440.0 * 2 ** ((n - 69) / 12.0)


def tt(dur):
    return np.arange(int(RATE * dur)) / RATE


def env(n, a, r):
    t = np.arange(n) / RATE
    return np.minimum(1.0, t / max(a, 1e-4)) * np.exp(-t / r)


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / RATE)
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y


def saw(f, t):
    return 2 * ((f * t) % 1.0) - 1


def add(start, sig):
    i = int(start * RATE) % LEN
    j = min(LEN, i + len(sig))
    out[i:j] += sig[: j - i]
    if i + len(sig) > LEN:  # wrap so the loop is seamless
        rest = sig[j - i:]
        out[: len(rest)] += rest


# D minor: Dm  Bb  F  C, one chord per bar, four times.
CHORDS = [[38, 50, 53, 57, 62], [34, 46, 50, 53, 58], [41, 48, 53, 57, 60], [36, 48, 52, 55, 60]]
for b in range(BARS):
    ch = CHORDS[b % 4]
    t0 = b * BAR
    # Brass pad: filtered saws, swelling in over the bar.
    t = tt(BAR * 1.05)
    swell = np.minimum(1, t / 0.9) * np.minimum(1, np.maximum(0, BAR * 1.05 - t) / 0.3)
    pad = sum(saw(hz(m) * d, t) for m in ch[1:4] for d in (1.0, 1.004))
    add(t0, 0.05 * lowpass(pad, 900.0) * swell)
    # Low string ostinato in eighths on the root and fifth.
    for k in range(8):
        n = ch[0] + 12 + (7 if k % 4 == 2 else 0)
        t = tt(BEAT / 2 * 0.95)
        s = lowpass(saw(hz(n), t), 1200.0) * env(len(t), 0.01, 0.25)
        add(t0 + k * BEAT / 2, (0.11 if k % 2 == 0 else 0.07) * s)
    # Timpani on beat 1 (and beat 3 every other bar): a tuned thump.
    for k in ((0, 2) if b % 2 else (0,)):
        t = tt(1.2)
        f = hz(ch[0]) * (1 + 0.15 * np.exp(-t / 0.05))
        timp = np.sin(2 * np.pi * np.cumsum(f) / RATE) * env(len(t), 0.002, 0.45)
        timp += 0.3 * rng.standard_normal(len(t)) * env(len(t), 0.001, 0.02)
        add(t0 + k * BEAT, 0.42 * timp)
    # Military snare: hits on 2 and 4, a roll into the next bar every second bar.
    def snare(start, vel):
        t = tt(0.22)
        noise = lowpass(rng.standard_normal(len(t)), 5000.0)
        body = np.sin(2 * np.pi * 190 * t)
        add(start, vel * (0.8 * noise + 0.4 * body) * env(len(t), 0.001, 0.07))
    snare(t0 + BEAT, 0.12)
    snare(t0 + 3 * BEAT, 0.12)
    snare(t0 + 3.5 * BEAT, 0.06)
    if b % 2 == 1:
        for k in range(6):
            snare(t0 + 3 * BEAT + k * BEAT / 12, 0.035 + 0.008 * k)

# Horn melody: a four-bar call and its answer, entering on bar 5 and bar 13.
MOTIF = [(62, 1.5), (65, 0.5), (69, 1.0), (67, 1.0), (65, 2.0), (62, 2.0),
         (60, 1.5), (62, 0.5), (65, 1.0), (64, 1.0), (62, 4.0)]
for start_bar, shift in ((4, 0), (12, -2)):
    pos = start_bar * BAR
    for note, beats in MOTIF:
        dur = beats * BEAT
        t = tt(dur * 1.05)
        f = hz(note + shift) * (1 + 0.004 * np.sin(2 * np.pi * 5.0 * t) * np.minimum(1, t / 0.4))
        ph = 2 * np.pi * np.cumsum(f) / RATE
        tone = np.sin(ph) + 0.45 * np.sin(2 * ph) + 0.2 * np.sin(3 * ph)
        shape = np.minimum(1, t / 0.08) * np.minimum(1, np.maximum(0, dur * 1.05 - t) / 0.12)
        add(pos, 0.09 * lowpass(tone, 2400.0) * shape)
        pos += dur

# A hall: a few soft echoes.
wet = np.zeros(LEN)
for d, g in ((0.13, 0.22), (0.29, 0.15), (0.47, 0.09)):
    wet += g * np.roll(out, int(d * RATE))
mix = out + wet
mix = mix / np.max(np.abs(mix)) * 0.8
pcm = (mix * 32767).astype(np.int16)
wav = "assets/audio/base_theme.wav"
with wave.open(wav, "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE); w.writeframes(pcm.tobytes())
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "3", "assets/audio/base_theme.ogg"], check=True)
os.remove(wav)
print("length %.1f s" % (LEN / RATE))
