"""Turns the black/white picture pairs from scenes/dev/bake_pictures.tscn into transparent webp
files in assets/textures/pictures. A pixel's alpha is 1 - (white - black); its color is what
shows over black divided by that alpha."""
import glob
import os

import numpy as np
from PIL import Image

SRC = "tmp/bake"
DST = "assets/textures/pictures"
os.makedirs(DST, exist_ok=True)
for black_path in sorted(glob.glob(f"{SRC}/*_black.png")):
    name = os.path.basename(black_path)[: -len("_black.png")]
    b = np.asarray(Image.open(black_path).convert("RGB"), dtype=np.float32) / 255.0
    w = np.asarray(Image.open(f"{SRC}/{name}_white.png").convert("RGB"), dtype=np.float32) / 255.0
    alpha = np.clip(1.0 - (w - b).mean(axis=2), 0.0, 1.0)
    color = np.clip(b / np.maximum(alpha, 1e-3)[..., None], 0.0, 1.0)
    rgba = np.dstack([color, alpha]) * 255.0
    Image.fromarray(rgba.round().astype(np.uint8), "RGBA").save(f"{DST}/{name}.webp", quality=85)
    print("wrote", name)
