"""Composes the calm base-screen music loop (assets/audio/base_theme.ogg).

An original piece synthesized from scratch with numpy, so there is nothing to license:
a warm pad on a slow I-vi-IV-V progression, a marimba-like arpeggio, a soft bass, light
shaker ticks and a quiet snare brush every other bar (a light military touch).
Run: python tools/make_music.py  (needs numpy and ffmpeg on the PATH)
"""
import numpy as np, subprocess, wave, os

RATE = 32000
BPM = 84
BEAT = 60.0 / BPM
BARS = 16
LEN = int(RATE * BEAT * 4 * BARS)
rng = np.random.default_rng(7)
out = np.zeros(LEN)

def hz(n):  # MIDI note to frequency
    return 440.0 * 2 ** ((n - 69) / 12.0)

def env(n, a, r):
    t = np.arange(n) / RATE
    e = np.minimum(1.0, t / max(a, 1e-4)) * np.exp(-t / r)
    return e

def add(start, sig):
    i = int(start * RATE)
    j = min(LEN, i + len(sig))
    out[i:j] += sig[: j - i]
    if i + len(sig) > LEN:  # wrap so the loop is seamless
        rest = sig[j - i:]
        out[: len(rest)] += rest

# C major: C  Am  F  G, each chord two bars, played twice.
CHORDS = [[48, 55, 60, 64, 67], [45, 52, 57, 60, 64], [41, 48, 53, 57, 60], [43, 50, 55, 59, 62]]
bar = BEAT * 4
for b in range(BARS):
    ch = CHORDS[(b // 2) % 4]
    t0 = b * bar
    # Pad: soft detuned sines with a slow swell, one per bar.
    n = int(RATE * bar * 1.15)
    t = np.arange(n) / RATE
    swell = np.minimum(1, t / 0.6) * np.minimum(1, np.maximum(0, (bar * 1.15 - t)) / 0.5)
    pad = sum(np.sin(2 * np.pi * hz(m + 12) * t * d) for m in ch[1:] for d in (1.0, 1.003))
    add(t0, 0.035 * pad * swell)
    # Bass: root on beats 1 and 3.
    for k in (0, 2):
        n = int(RATE * BEAT * 1.8)
        t = np.arange(n) / RATE
        bass = np.sin(2 * np.pi * hz(ch[0] - 12) * t) + 0.3 * np.sin(2 * np.pi * hz(ch[0]) * t)
        add(t0 + k * BEAT, 0.22 * bass * env(n, 0.02, 0.6))
    # Marimba arpeggio in eighths: up through the chord, a gentle pattern.
    pattern = [2, 3, 4, 3, 2, 3, 4, 3] if b % 2 == 0 else [2, 4, 3, 4, 2, 4, 3, 1]
    for k, idx in enumerate(pattern):
        n = int(RATE * 0.9)
        t = np.arange(n) / RATE
        f = hz(ch[idx] + 12)
        note = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(2 * np.pi * f * 4 * t) * np.exp(-t / 0.05)
        vel = 0.11 if k % 2 == 0 else 0.07
        add(t0 + k * BEAT / 2, vel * note * env(n, 0.003, 0.32))
    # Shaker on the off-beats and a soft brush on beat 4 every other bar.
    for k in range(8):
        n = int(RATE * 0.06)
        noise = rng.standard_normal(n)
        noise = np.diff(np.concatenate([[0], noise]))  # brighter
        add(t0 + k * BEAT / 2 + BEAT / 4, 0.012 * noise * env(n, 0.001, 0.02))
    if b % 2 == 1:
        n = int(RATE * 0.25)
        noise = rng.standard_normal(n)
        add(t0 + 3 * BEAT, 0.03 * noise * env(n, 0.005, 0.08))

# Gentle room: a few soft echoes.
wet = np.zeros(LEN)
for d, g in ((0.11, 0.25), (0.23, 0.16), (0.37, 0.1)):
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
