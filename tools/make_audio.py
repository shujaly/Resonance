from __future__ import annotations

import math
import random
import wave
from array import array
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "audio"
OUT.mkdir(exist_ok=True)
RATE = 22050
TAU = 2 * math.pi


def save(name: str, values: list[float]) -> None:
    data = array("h")
    for value in values:
        data.append(round(max(-1.0, min(1.0, value)) * 32767))
    with wave.open(str(OUT / f"{name}.wav"), "wb") as audio:
        audio.setnchannels(1)
        audio.setsampwidth(2)
        audio.setframerate(RATE)
        audio.writeframes(data.tobytes())


def samples(duration: float, render) -> list[float]:
    return [render(i / RATE) for i in range(round(duration * RATE))]


def note(semitones_from_a4: int) -> float:
    return 440.0 * 2 ** (semitones_from_a4 / 12)


CHORDS = [
    [note(-21), note(-17), note(-14)],
    [note(-25), note(-21), note(-17)],
    [note(-24), note(-19), note(-16)],
    [note(-26), note(-21), note(-17)],
]


def pad(chord: list[float], t: float) -> float:
    return sum(
        math.sin(TAU * f * t) * 0.046
        + math.sin(TAU * (f * 1.003) * t) * 0.019
        + math.sin(TAU * f * 2 * t) * 0.008
        for f in chord
    )


def music_base(t: float) -> float:
    section = int(t // 4) % 4
    phase = t % 4
    cross = max(0.0, min(1.0, (phase - 3.75) / 0.25))
    body = pad(CHORDS[section], t) * (1 - cross) + pad(CHORDS[(section + 1) % 4], t) * cross
    beat = t % 0.5
    bass_f = CHORDS[section][0] / 2
    bass = 0.052 * math.exp(-beat * 7) * math.sin(TAU * bass_f * t)
    tremolo = 0.92 + 0.08 * math.sin(TAU * t / 8)
    edge = min(1.0, t / 0.08, (16.0 - t) / 0.08)
    return (body * tremolo + bass) * max(0.0, edge)


def music_high(t: float) -> float:
    section = int(t // 4) % 4
    beat_num = int(t / 0.5)
    part = t % 0.5
    sequence = [0, 1, 2, 1, 2, 1, 0, 1]
    frequency = CHORDS[section][sequence[beat_num % 8]] * 4
    chime = math.exp(-part * 9) * (
        math.sin(TAU * frequency * t) * 0.065
        + math.sin(TAU * frequency * 2.01 * t) * 0.021
    )
    tick = math.exp(-part * 45) * math.sin(TAU * 1700 * t) * 0.017
    edge = min(1.0, t / 0.08, (16.0 - t) / 0.08)
    return (chime + tick) * max(0.0, edge)


def bell(t: float, base: float, decay: float = 1.0) -> float:
    partials = [(1.0, 0.46), (2.01, 0.25), (2.68, 0.16), (3.91, 0.08), (5.4, 0.04)]
    ring = sum(weight * math.sin(TAU * base * harmonic * t) for harmonic, weight in partials)
    attack = min(1.0, t / 0.009)
    return ring * attack * math.exp(-t * 2.4 / decay)


def ring(t: float) -> float:
    shimmer = 0.095 * math.exp(-t * 4.0) * math.sin(TAU * (1020 + 120 * t) * t)
    return 0.7 * bell(t, 466.16, 1.0) + shimmer


def jump(t: float) -> float:
    return 0.18 * math.exp(-t * 15) * math.sin(TAU * (360 + 1100 * t) * t)


def land(t: float) -> float:
    return 0.13 * math.exp(-t * 33) * math.sin(TAU * (110 - 45 * t) * t)


def collect(t: float) -> float:
    scale = [587.33, 739.99, 880.0]
    return sum(
        0.23 * math.exp(-max(0.0, t - index * 0.12) * 8)
        * math.sin(TAU * frequency * max(0.0, t - index * 0.12))
        if t >= index * 0.12 else 0.0
        for index, frequency in enumerate(scale)
    )


def checkpoint(t: float) -> float:
    return 0.22 * bell(t, 659.25, 0.6)


def fail(t: float) -> float:
    return 0.16 * math.exp(-t * 7) * math.sin(TAU * (390 - 280 * t) * t)


def start(t: float) -> float:
    return 0.12 * bell(t, 392.0, 0.7) + (0.10 * bell(t - 0.16, 587.33, 0.7) if t > 0.16 else 0.0)


def finish(t: float) -> float:
    tones = [(0.0, 392.0), (0.24, 523.25), (0.48, 659.25), (0.72, 783.99)]
    return sum(0.27 * bell(t - at, frequency, 1.7) if t >= at else 0.0 for at, frequency in tones)


def rain() -> list[float]:
    rng = random.Random(74193)
    smooth = 0.0
    values = []
    duration = 6.0
    for i in range(round(duration * RATE)):
        t = i / RATE
        smooth = smooth * 0.82 + rng.uniform(-1.0, 1.0) * 0.18
        slow = math.sin(TAU * t * 0.7) * 0.009
        edge = min(1.0, t / 0.35, (duration - t) / 0.35)
        values.append((smooth * 0.085 + slow) * max(0.0, edge))
    return values


def main() -> None:
    save("music_base", samples(16.0, music_base))
    save("music_high", samples(16.0, music_high))
    save("rain", rain())
    for name, duration, render in [
        ("ring", 2.0, ring),
        ("jump", 0.3, jump),
        ("land", 0.18, land),
        ("collect", 0.9, collect),
        ("checkpoint", 0.8, checkpoint),
        ("fail", 0.55, fail),
        ("start", 1.0, start),
        ("finish", 3.0, finish),
    ]:
        save(name, samples(duration, render))
    print(f"Created 11 audio files in {OUT}")


if __name__ == "__main__":
    main()
