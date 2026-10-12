"""Cuts the 30-second store video (docs/store/video/skywatch_store_1080p.mp4).

Approved 12.10.2026: direction C "mixed" (https://claude.ai/artifact/BkDGMrvmSVVLVPLbGjA16Z): a
cinematic hook without HUD, then gameplay with HUD; captions are logo-style tags (a big white word on
dark olive with a gold edge, and a gold tag) sliding in from the left. English only, landscape 1920x1080.
Every shot starts on a bar line of tools/make_promo_music.py (128 BPM, one bar = 1.875 s).

Footage comes from the game's movie writer (tools/record_store_video.sh), all real gameplay, so
it fits Apple's App Preview rules (no prices, no other platforms, nothing outside the app).
Run: python tools/make_store_video.py  (needs Pillow and ffmpeg; Black Ops One in tmp/fonts)
"""
import os, subprocess
from PIL import Image, ImageDraw, ImageFont, ImageFilter

RAW = "tmp/vid"
WORK = "tmp/vid/build"
OUT = "docs/store/video/skywatch_store_1080p.mp4"
MUSIC = "docs/store/video/promo_music.ogg"
FONT = "tmp/fonts/BlackOpsOne-Regular.ttf"
LOGO = "assets/icon/logo.png"
BAR = 60.0 / 128 * 4
W, H = 1920, 1080

# (clip folder, start second in the clip, bars, caption words, gold tag, white flash at the cut)
SHOTS = [
    ("f_follow", 22.5, 2, ["DRONES", "TANKS"], "ONE COMMAND", False),
    ("f_home", 0.3, 2, ["BUILD"], "YOUR BASE", True),
    ("f_upgrade", 0.6, 1, ["UPGRADE"], "EVERY LEVEL LOOKS NEW", True),
    ("f_raidhud", 0.4, 2, ["DEPLOY"], "YOUR ARMY", True),
    ("f_follow", 3.5, 2, ["BREACH"], "THE WALLS", True),
    ("f_follow", 15.0, 2, ["STRIKE"], "FROM THE SKY", True),
    ("f_fang", 3.5, 2, ["RAID"], "IRON FANG", True),
    ("f_raidhud", 16.0, 1, ["WIN"], "THE LOOT", True),
]
END_BARS = 2


def run(args):
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error"] + args, check=True)


def caption_png(words, tag, path):
    """A stack of word plates and a gold tag, on a transparent canvas."""
    big = ImageFont.truetype(FONT, 92)
    small = ImageFont.truetype(FONT, 36)
    img = Image.new("RGBA", (1100, 140 * len(words) + 120), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    y = 0
    for w in words:
        box = d.textbbox((0, 0), w, font=big)
        pw, ph = box[2] - box[0] + 64, 120
        d.rectangle([0, y, pw + 16, y + ph], fill=(24, 30, 16, 214))
        d.rectangle([0, y, 16, y + ph], fill=(242, 182, 50, 255))
        d.text((16 + 32 - box[0], y + (ph - (box[3] - box[1])) / 2 - box[1] + 2), w, font=big, fill=(255, 255, 255, 255))
        y += ph + 14
    box = d.textbbox((0, 0), tag, font=small)
    tw, th = box[2] - box[0] + 40, 58
    d.rectangle([0, y, tw, y + th], fill=(242, 182, 50, 255))
    d.text((20 - box[0], y + (th - (box[3] - box[1])) / 2 - box[1]), tag, font=small, fill=(28, 26, 16, 255))
    img = img.crop((0, 0, 1100, y + th + 4))
    # A soft shadow under the whole block.
    shadow = Image.new("RGBA", (img.width + 40, img.height + 40), (0, 0, 0, 0))
    shadow.paste((0, 0, 0, 120), (20, 26), img.split()[3])
    shadow = shadow.filter(ImageFilter.GaussianBlur(10))
    shadow.alpha_composite(img, (20, 20))
    shadow.save(path)


def end_png(path):
    """Logo, the DRONE COMMAND line and a short tagline on a transparent canvas."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    logo = Image.open(LOGO).convert("RGBA")
    lw = 900
    logo = logo.resize((lw, int(logo.height * lw / logo.width)), Image.LANCZOS)
    img.alpha_composite(logo, ((W - lw) // 2, 300))
    d = ImageDraw.Draw(img)
    f = ImageFont.truetype(FONT, 54)
    text = "BUILD.  TRAIN.  RAID."
    box = d.textbbox((0, 0), text, font=f)
    d.text(((W - (box[2] - box[0])) / 2 - box[0], 300 + logo.height + 60), text, font=f, fill=(236, 230, 212, 255))
    img.save(path)


def main():
    os.makedirs(WORK, exist_ok=True)
    parts = []
    t = 0.0
    for i, (clip, start, bars, words, tag, flash) in enumerate(SHOTS):
        dur = bars * BAR
        cap = f"{WORK}/cap{i}.png"
        caption_png(words, tag, cap)
        seg = f"{WORK}/seg{i}.mp4"
        slide = "if(lt(t,0.15),-1200,if(lt(t,0.5),70-1270*pow(1-(t-0.15)/0.35,3),70))"
        # Shots with the HUD keep the caption below the badge in the top-left corner.
        cy = 70 if clip in ("f_follow", "f_fang") else 290
        vf = (f"[0:v]scale={W}:{H},setsar=1" + (",fade=t=in:st=0:d=0.18:color=white" if flash else "") +
              f"[v];[1:v]format=rgba[c];[v][c]overlay=x='{slide}':y={cy}:eval=frame:enable='lt(t,{dur - 0.12:.3f})',format=yuv420p[o]")
        run(["-ss", f"{start:.3f}", "-i", f"{RAW}/{clip}/f.avi", "-loop", "1", "-i", cap, "-t", f"{dur:.4f}",
             "-filter_complex", vf, "-map", "[o]", "-map", "0:a", "-r", "30", "-c:v", "libx264", "-crf", "17",
             "-preset", "medium", "-c:a", "aac", "-ar", "48000", "-ac", "2", seg])
        parts.append(seg)
        t += dur
    # End card: the last Iron Fang frames, darkened and blurred, under the logo.
    endp = f"{WORK}/end.png"
    end_png(endp)
    dur = END_BARS * BAR
    seg = f"{WORK}/seg_end.mp4"
    run(["-ss", "11.0", "-i", f"{RAW}/f_fang/f.avi", "-loop", "1", "-i", endp, "-t", f"{dur:.4f}", "-filter_complex",
         f"[0:v]scale={W}:{H},boxblur=12:2,eq=brightness=-0.22:saturation=0.8,fade=t=in:st=0:d=0.2:color=white[v];"
         f"[1:v]format=rgba,fade=t=in:st=0.1:d=0.5:alpha=1[l];[v][l]overlay=0:0,format=yuv420p[o]",
         "-map", "[o]", "-map", "0:a", "-r", "30", "-c:v", "libx264", "-crf", "17", "-preset", "medium",
         "-c:a", "aac", "-ar", "48000", "-ac", "2", seg])
    parts.append(seg)
    with open(f"{WORK}/list.txt", "w") as f:
        for p in parts:
            f.write(f"file '{os.path.abspath(p)}'\n")
    run(["-f", "concat", "-safe", "0", "-i", f"{WORK}/list.txt", "-c", "copy", f"{WORK}/joined.mp4"])
    # Music on top, the game's own sounds under it.
    run(["-i", f"{WORK}/joined.mp4", "-i", MUSIC, "-filter_complex",
         "[0:a]volume=0.35[g];[1:a]volume=1.0[m];[g][m]amix=inputs=2:duration=longest:normalize=0,alimiter=limit=0.95[a]",
         "-map", "0:v", "-map", "[a]", "-t", "30", "-c:v", "libx264", "-crf", "19", "-maxrate", "14M", "-bufsize", "28M", "-preset", "slow", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", OUT])
    print("wrote", OUT)


if __name__ == "__main__":
    main()
