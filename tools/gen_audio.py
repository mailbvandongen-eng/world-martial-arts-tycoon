#!/usr/bin/env python3
"""Synthesises the game's original sound effects into assets/audio/*.wav.

Everything is generated from scratch (noise, sine waves, envelopes), so the
sounds are original and free to use. Upload them in the Creator Dashboard and
put the asset ids into src/shared/Config/Audio.lua (see docs/SETUP.md).
"""
import os
import wave

import numpy as np

RATE = 44100
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "audio")
rng = np.random.default_rng(7)


def t(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def env(n, attack=0.005, decay=0.2):
    x = np.arange(n) / RATE
    a = np.clip(x / attack, 0, 1)
    return a * np.exp(-x / decay)


def tone(freq, seconds, decay=0.3, kind="sine"):
    x = t(seconds)
    if kind == "square":
        w = np.sign(np.sin(2 * np.pi * freq * x)) * 0.5
    elif kind == "tri":
        w = 2 * np.abs(2 * ((freq * x) % 1) - 1) - 1
    else:
        w = np.sin(2 * np.pi * freq * x)
    return w * env(len(x), 0.004, decay)


def noise(seconds, decay=0.1, lowpass=0.0):
    n = rng.standard_normal(int(RATE * seconds))
    if lowpass > 0:
        out = np.zeros_like(n)
        acc = 0.0
        for i, v in enumerate(n):
            acc += lowpass * (v - acc)
            out[i] = acc
        n = out / (np.max(np.abs(out)) + 1e-9)
    return n * env(len(n), 0.002, decay)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def seq(*parts, gap=0.0):
    pad = np.zeros(int(RATE * gap))
    out = []
    for p in parts:
        out.extend([p, pad])
    return np.concatenate(out)


def thump(freq=60, seconds=0.35):
    x = t(seconds)
    f = freq * (1 + 2 * np.exp(-x * 30))
    phase = 2 * np.pi * np.cumsum(f) / RATE
    return np.sin(phase) * env(len(x), 0.002, 0.12)


def save(name, data, gain=0.8):
    data = data / (np.max(np.abs(data)) + 1e-9) * gain
    pcm = (data * 32767).astype(np.int16)
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())


def main():
    save("cash", seq(tone(1320, 0.12, 0.08), tone(1760, 0.25, 0.15), gap=0.02))
    save("construct", seq(*[mix(noise(0.08, 0.03, 0.3), tone(220, 0.08, 0.03, "square")) for _ in range(4)], gap=0.09))
    save("build_done", seq(tone(523, 0.15, 0.1), tone(659, 0.15, 0.1), tone(784, 0.15, 0.1), tone(1047, 0.5, 0.3), gap=0.0))
    save("levelup", seq(tone(392, 0.12, 0.1, "tri"), tone(523, 0.12, 0.1, "tri"), tone(659, 0.12, 0.1, "tri"), mix(tone(784, 0.7, 0.4, "tri"), tone(1047, 0.7, 0.4))))
    save("purchase", mix(tone(880, 0.6, 0.3), tone(1320, 0.6, 0.25), noise(0.3, 0.05, 0.05) * 0.2))
    save("unlock", seq(tone(659, 0.1, 0.08), tone(988, 0.1, 0.08), mix(tone(1319, 0.6, 0.35), tone(1976, 0.6, 0.2) * 0.4)))
    save("click", tone(1800, 0.04, 0.01) * 0.6)
    save("error", seq(tone(200, 0.12, 0.08, "square"), tone(150, 0.2, 0.12, "square"), gap=0.03))
    save("bag_hit", mix(thump(70, 0.3), noise(0.15, 0.03, 0.15) * 0.6))
    save("pad_kick", mix(noise(0.12, 0.02, 0.4), thump(140, 0.15) * 0.5))
    save("mat_fall", mix(thump(45, 0.5), noise(0.4, 0.08, 0.05) * 0.8))
    save("stomp", mix(thump(38, 0.6), noise(0.3, 0.06, 0.03) * 0.5))
    whistle_x = t(0.6)
    trill = np.sin(2 * np.pi * (2600 + 120 * np.sin(2 * np.pi * 28 * whistle_x)) * whistle_x)
    save("whistle", trill * env(len(whistle_x), 0.01, 0.4), gain=0.5)
    save("footstep", noise(0.08, 0.02, 0.2), gain=0.5)
    save("rankup", seq(tone(784, 0.1, 0.08), tone(988, 0.1, 0.08), tone(1175, 0.1, 0.08), mix(tone(1568, 0.8, 0.5), tone(1175, 0.8, 0.5) * 0.5)))
    save("announce", seq(mix(tone(523, 0.35, 0.3, "tri"), tone(659, 0.35, 0.3, "tri")), mix(tone(784, 0.8, 0.6, "tri"), tone(1047, 0.8, 0.6, "tri")), gap=0.05))
    # gym ambience: soft room noise with occasional distant bag hits (6 s loop)
    amb = noise(6.0, 1e9, 0.02) * 0.15
    for start in (0.4, 1.7, 2.1, 3.6, 4.9, 5.3):
        hit = thump(65, 0.3) * 0.25
        i = int(start * RATE)
        amb[i: i + len(hit)] += hit[: len(amb) - i]
    save("ambience_gym", amb, gain=0.35)
    # background music: a calm 8-bar loop in A minor pentatonic (16 s)
    notes = [220, 262, 294, 330, 392, 440, 392, 330, 294, 262, 220, 196, 220, 262, 330, 294]
    melody = np.concatenate([tone(f, 0.5, 0.35, "tri") * 0.6 for f in notes])
    bass = np.concatenate([tone(f / 2, 2.0, 1.2) for f in (110, 87.3, 98, 110)])
    beat = np.concatenate([mix(thump(55, 0.5) * 0.4, np.zeros(int(RATE * 0.5))) for _ in range(16)])
    music = mix(np.tile(melody, 2), np.tile(bass, 2), np.tile(beat, 2))
    save("music", music, gain=0.5)
    print("wrote", len(os.listdir(OUT)), "files to", os.path.relpath(OUT))


if __name__ == "__main__":
    main()
