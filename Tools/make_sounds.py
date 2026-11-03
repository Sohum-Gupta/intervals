"""Synthesise the bundled alert sounds. Run: python3 Tools/make_sounds.py
Writes WAV to a temp folder and converts to AIFF with afconvert, so the
repo has no audio dependencies beyond macOS itself."""
import math, os, random, struct, subprocess, sys, tempfile, wave

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "Intervals", "Resources", "Sounds")

def env(t, attack, decay):
    if t < attack:
        return t / attack
    return math.exp(-(t - attack) / decay)

def render(name, seconds, fn):
    n = int(RATE * seconds)
    samples = [fn(i / RATE) for i in range(n)]
    peak = max(abs(s) for s in samples) or 1.0
    scale = 0.8 / peak
    # Fade the last 20 ms to avoid clicks at the end.
    fade = int(RATE * 0.02)
    data = bytearray()
    for i, s in enumerate(samples):
        if i > n - fade:
            s *= (n - i) / fade
        data += struct.pack("<h", int(max(-1, min(1, s * scale)) * 32767))
    tmp = tempfile.mkdtemp()
    wav = os.path.join(tmp, name + ".wav")
    with wave.open(wav, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes(bytes(data))
    aiff = os.path.join(OUT, name + ".aiff")
    subprocess.run(["afconvert", "-f", "AIFF", "-d", "BEI16", wav, aiff], check=True)
    print("wrote", os.path.relpath(aiff))

def tone(f, t, partials=((1, 1.0),)):
    return sum(a * math.sin(2 * math.pi * f * k * t) for k, a in partials)

# Chime: two soft bell-like notes, E5 then B5.
def chime(t):
    p = ((1, 1.0), (2, 0.35), (3, 0.12), (4.2, 0.05))
    a = tone(659.25, t, p) * env(t, 0.005, 0.35)
    b = tone(987.77, t - 0.18, p) * env(max(t - 0.18, 0), 0.005, 0.45) if t > 0.18 else 0
    return a + 0.9 * b

# Bell: one struck note with inharmonic partials and a long tail.
def bell(t):
    p = ((1, 1.0), (2.0, 0.5), (2.98, 0.3), (4.2, 0.18), (5.4, 0.1))
    return tone(523.25, t, p) * env(t, 0.003, 0.9)

# Soft click: a short filtered noise burst with a low thump.
_rng = random.Random(7)
_noise = [_rng.uniform(-1, 1) for _ in range(RATE)]
def soft_click(t):
    i = int(t * RATE)
    n = sum(_noise[max(i - k, 0)] for k in range(6)) / 6   # crude low-pass
    thump = math.sin(2 * math.pi * 180 * t) * env(t, 0.002, 0.03)
    return n * env(t, 0.001, 0.012) * 0.6 + thump * 0.8

# Marimba: two quick wooden notes, C5 then G5, with the 4th partial marimba emphasises.
def marimba(t):
    p = ((1, 1.0), (4, 0.4), (9.2, 0.08))
    a = tone(523.25, t, p) * env(t, 0.002, 0.18)
    b = tone(783.99, t - 0.16, p) * env(max(t - 0.16, 0), 0.002, 0.22) if t > 0.16 else 0
    return a + b

# Tick: one soft tick at the start of a one-second file, looped during work.
def tick(t):
    i = int(t * RATE)
    n = sum(_noise[max(i - k, 0)] for k in range(4)) / 4
    return (n * env(t, 0.0005, 0.006) * 0.5 + math.sin(2 * math.pi * 2200 * t) * env(t, 0.0005, 0.004) * 0.5) * 0.35

os.makedirs(OUT, exist_ok=True)
render("Chime", 1.2, chime)
render("Bell", 2.0, bell)
render("SoftClick", 0.15, soft_click)
render("Marimba", 0.8, marimba)
render("Tick", 1.0, tick)
