"""High-quality seamless Pomodoro ambient loops (mono 44.1 kHz WAV)."""
from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

import numpy as np

SR = 44100
DURATION_SEC = 40
OUT = Path(__file__).resolve().parents[1] / "assets" / "sounds"


def save_wav(path: Path, data: np.ndarray) -> None:
    peak = float(np.max(np.abs(data))) or 1.0
    norm = np.clip(data / peak * 0.78, -1.0, 1.0)
    pcm = (norm * 32767).astype(np.int16)
    with wave.open(str(path), "w") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SR)
        wf.writeframes(pcm.tobytes())


def seamless(data: np.ndarray, fade_sec: float = 2.5) -> np.ndarray:
    n = len(data)
    fade = min(int(fade_sec * SR), n // 6)
    t = np.linspace(0, np.pi, fade)
    w = 0.5 - 0.5 * np.cos(t)
    out = data.copy()
    blend = out[:fade] * (1 - w) + out[-fade:] * w
    out[:fade] = blend
    out[-fade:] = blend
    return out


def white(n: int, seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    return rng.standard_normal(n)


def brown(n: int, seed: int) -> np.ndarray:
    x = white(n, seed)
    y = np.cumsum(x)
    y -= np.mean(y)
    return y / (np.max(np.abs(y)) or 1.0)


def pink(n: int, seed: int) -> np.ndarray:
    w = np.fft.rfft(white(n, seed))
    freqs = np.arange(len(w))
    freqs[0] = 1
    w /= np.sqrt(freqs)
    y = np.fft.irfft(w, n=n)
    return y / (np.max(np.abs(y)) or 1.0)


def lowpass(x: np.ndarray, alpha: float) -> np.ndarray:
    y = np.empty_like(x)
    prev = 0.0
    for i, s in enumerate(x):
        prev = prev + alpha * (s - prev)
        y[i] = prev
    return y


def moving_avg(x: np.ndarray, win: int) -> np.ndarray:
    kernel = np.ones(win) / win
    return np.convolve(x, kernel, mode="same")


def rain(seed: int = 101) -> np.ndarray:
    n = SR * DURATION_SEC
    rng = random.Random(seed)
    layer = pink(n, seed)
    layer = lowpass(layer, 0.05)
    layer = layer - moving_avg(layer, int(0.02 * SR))
    drops = np.zeros(n)
    for _ in range(120):
        pos = rng.randrange(0, n - int(0.06 * SR))
        length = int(rng.uniform(0.008, 0.035) * SR)
        amp = rng.uniform(0.03, 0.11)
        env = np.sin(np.linspace(0, np.pi, length))
        drops[pos : pos + length] += amp * env
    t = np.arange(n) / SR
    mod = 0.72 + 0.28 * np.sin(2 * np.pi * 0.08 * t + 0.4)
    return seamless((layer * 0.65 + drops) * mod)


def cafe(seed: int = 202) -> np.ndarray:
    n = SR * DURATION_SEC
    rng = random.Random(seed)
    murmur = pink(n, seed + 1)
    murmur = lowpass(murmur, 0.04)
    # Warm mid chatter band
    murmur = murmur - moving_avg(murmur, int(0.003 * SR))
    clinks = np.zeros(n)
    for _ in range(18):
        pos = rng.randrange(0, n - int(0.15 * SR))
        length = int(rng.uniform(0.015, 0.07) * SR)
        freq = rng.uniform(700, 1800)
        amp = rng.uniform(0.012, 0.04)
        t = np.arange(length) / SR
        env = np.exp(-t * 14)
        tone = np.sin(2 * np.pi * freq * t) * env
        clinks[pos : pos + length] += amp * tone
    t = np.arange(n) / SR
    mod = 0.78 + 0.22 * np.sin(2 * np.pi * 0.05 * t)
    return seamless(murmur * 0.55 * mod + clinks)


def forest(seed: int = 303) -> np.ndarray:
    n = SR * DURATION_SEC
    rng = random.Random(seed)
    wind = brown(n, seed)
    wind = lowpass(wind, 0.025)
    birds = np.zeros(n)
    for _ in range(10):
        pos = rng.randrange(0, n - int(0.5 * SR))
        length = int(rng.uniform(0.06, 0.28) * SR)
        t = np.arange(length) / SR
        f0 = rng.uniform(1400, 3800)
        amp = rng.uniform(0.018, 0.05)
        freq = f0 + 350 * np.sin(2 * np.pi * 8 * t)
        phase = np.cumsum(freq) / SR * 2 * np.pi
        env = np.sin(np.pi * np.minimum(1.0, t / 0.03)) * np.exp(-t * 2.5)
        birds[pos : pos + length] += amp * np.sin(phase) * env
    rustle = pink(n, seed + 9)
    rustle = lowpass(rustle, 0.08) * 0.08
    t = np.arange(n) / SR
    mod = 0.8 + 0.2 * np.sin(2 * np.pi * 0.035 * t + 1.1)
    return seamless(wind * 0.42 * mod + birds + rustle)


def calm_noise(seed: int = 404) -> np.ndarray:
    n = SR * DURATION_SEC
    x = brown(n, seed)
    x = lowpass(x, 0.03)
    return seamless(x)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    files = {
        "ambient_rain.wav": rain(),
        "ambient_cafe.wav": cafe(),
        "ambient_forest.wav": forest(),
        "ambient_brown_noise.wav": calm_noise(),
    }
    for name, data in files.items():
        path = OUT / name
        save_wav(path, data)
        print(f"Wrote {path.name} ({path.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
