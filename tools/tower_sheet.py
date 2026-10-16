"""Glue the 15 tower shots from scenes/dev/tower_sheet.tscn into one sheet (3 rows x 5 levels).

python tools/tower_sheet.py <dir with s0000NNNN.png> <out.png> [crop]
"""
import sys
from pathlib import Path
from PIL import Image

src, out = Path(sys.argv[1]), sys.argv[2]
crop = int(sys.argv[3]) if len(sys.argv) > 3 else 520
files = sorted(src.glob("s*.png"))
sheet = Image.new("RGB", (crop * 5, crop * 3))
for k in range(15):
    im = Image.open(files[3 * k + 2])
    w, h = im.size
    box = ((w - crop) // 2, (h - crop) // 2, (w + crop) // 2, (h + crop) // 2)
    sheet.paste(im.crop(box), ((k % 5) * crop, (k // 5) * crop))
sheet.save(out)
