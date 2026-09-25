import math
import wave
from array import array
from pathlib import Path

RATE = 22050
TAU = math.tau
OUT = Path(__file__).resolve().parents[1] / "audio"


def write(name, duration, synth):
    samples = array("h")
    for index in range(int(duration * RATE)):
        t = index / RATE
        value = max(-1.0, min(1.0, synth(t)))
        samples.append(int(value * 32767))
    with wave.open(str(OUT / f"{name}.wav"), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(samples.tobytes())


def sine(f, t):
    return math.sin(TAU * f * t)


def bell(f, t):
    return (sine(f, t) + 0.40*sine(f*2.01, t) + 0.18*sine(f*2.68, t)) * math.exp(-t*8)


write("reject", 0.22, lambda t: 0.21*math.exp(-t*22)*(sine(155-75*t,t)+0.18*sine(375,t)))
write("bronze", 0.55, lambda t: 0.21*bell(523.25,t)+0.18*bell(783.99,max(0,t-0.12))*(t>=0.12))
write("echo", 0.70, lambda t: 0.18*math.exp(-t*4.5)*(sine(660+130*t,t)+0.38*sine(1324,t)))
write("glass", 0.35, lambda t: 0.12*math.exp(-t*11)*(sine(990,t)+0.44*sine(1490,t)))
write("stone", 0.20, lambda t: 0.20*math.exp(-t*28)*(sine(88,t)+0.25*sine(163,t)))
write("menu", 0.18, lambda t: 0.11*math.exp(-t*17)*(sine(750,t)+0.27*sine(1490,t)))
print("Created six additional sound cues")
