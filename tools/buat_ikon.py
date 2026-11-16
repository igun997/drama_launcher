#!/usr/bin/env python3
"""Hasilkan semua ikon dan gambar aset dari master di art/.

  art/icon_master.png  lentera di latar rata #1B1230
  art/hero.png         pemandangan malam (kepala beranda)
  art/empty.png        teko dan lentera (keadaan kosong)

Keluaran: mipmap Android (legacy, bulat, adaptif foreground, monokrom), ikon web,
favicon.ico, ikon Play Store, grafis fitur, dan aset Flutter berformat WebP.
"""
import pathlib
from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parent.parent
ART = ROOT / "art"
RES = ROOT / "android/app/src/main/res"
WEB = ROOT / "web"
STORE = ROOT / "store"
IMG = ROOT / "assets/images"
BG = (0x1B, 0x12, 0x30)

for d in (STORE, IMG, WEB / "icons"):
    d.mkdir(parents=True, exist_ok=True)


def subject(path=None):
    """Subjek dengan alfa (latar rata dibuang), dipotong rapat."""
    im = Image.open(path or ART / "icon_master.png").convert("RGB")
    px = im.load()
    w, h = im.size
    bg = px[2, 2]
    out = Image.new("RGBA", im.size)
    op = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            d = max(abs(r - bg[0]), abs(g - bg[1]), abs(b - bg[2]))
            a = max(0, min(255, int((d - 6) * 255 / 30)))
            op[x, y] = (r, g, b, a)
    return out.crop(out.getchannel("A").point(lambda v: 255 if v > 24 else 0).getbbox())


def fit(sub, canvas, frac, bg=None):
    """Taruh subjek di kanvas persegi; tinggi subjek = frac * kanvas."""
    c = Image.new("RGBA", (canvas, canvas), (*bg, 255) if bg else (0, 0, 0, 0))
    s = frac * canvas / sub.height
    if sub.width * s > frac * canvas * 1.0 and sub.width > sub.height:
        s = frac * canvas / sub.width
    r = sub.resize((max(1, round(sub.width * s)), max(1, round(sub.height * s))), Image.LANCZOS)
    c.alpha_composite(r, ((canvas - r.width) // 2, (canvas - r.height) // 2))
    return c


def mono(fg):
    """Siluet putih: lentera tanpa segitiga putar."""
    out = Image.new("RGBA", fg.size, (0, 0, 0, 0))
    sp, op = fg.load(), out.load()
    for y in range(fg.height):
        for x in range(fg.width):
            r, g, b, a = sp[x, y]
            if a and not (r > 225 and g > 215 and b > 165):
                op[x, y] = (255, 255, 255, a)
    return out


def rounded(im, radius_frac):
    m = Image.new("L", im.size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, im.width - 1, im.height - 1), radius=int(im.width * radius_frac), fill=255)
    o = im.copy()
    o.putalpha(m)
    return o


def circle(im):
    m = Image.new("L", im.size, 0)
    ImageDraw.Draw(m).ellipse((0, 0, im.width - 1, im.height - 1), fill=255)
    o = im.copy()
    o.putalpha(m)
    return o


def save(im, path, **kw):
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path, **kw)


sub = subject()
dens = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
for name, k in dens.items():
    d = RES / f"mipmap-{name}"
    # adaptif 108dp, zona aman 66dp: tinggi subjek <= 58dp
    fg = fit(sub, round(108 * k), 58 / 108)
    save(fg, d / "ic_launcher_foreground.png", optimize=True)
    save(mono(fg), d / "ic_launcher_monochrome.png", optimize=True)
    # legacy 48dp (API 24-25)
    legacy = fit(sub, round(48 * k), 0.74, bg=BG)
    save(rounded(legacy, 0.18), d / "ic_launcher.png", optimize=True)
    save(circle(legacy), d / "ic_launcher_round.png", optimize=True)

# Play Store
save(fit(sub, 512, 0.7, bg=BG).convert("RGB"), STORE / "icon-512.png", optimize=True)

# Web
save(fit(sub, 192, 0.78, bg=BG).convert("RGB"), WEB / "icons/Icon-192.png", optimize=True)
save(fit(sub, 512, 0.78, bg=BG).convert("RGB"), WEB / "icons/Icon-512.png", optimize=True)
save(fit(sub, 192, 0.58, bg=BG).convert("RGB"), WEB / "icons/Icon-maskable-192.png", optimize=True)
save(fit(sub, 512, 0.58, bg=BG).convert("RGB"), WEB / "icons/Icon-maskable-512.png", optimize=True)
save(fit(sub, 180, 0.74, bg=BG).convert("RGB"), WEB / "apple-touch-icon.png", optimize=True)
fav = rounded(fit(sub, 256, 0.9, bg=BG), 0.2)
save(fav.resize((32, 32), Image.LANCZOS), WEB / "favicon.png", optimize=True)
save(fav, WEB / "favicon.ico", sizes=[(16, 16), (32, 32), (48, 48)])

# Grafis fitur Play Store 1024x500 dan gambar bagikan (OG) 1200x630
hero = Image.open(ART / "hero.png").convert("RGB")
for (w, h, path) in ((1024, 500, STORE / "feature-graphic.png"), (1200, 630, WEB / "og-image.png")):
    s = max(w / hero.width, h / hero.height)
    r = hero.resize((round(hero.width * s), round(hero.height * s)), Image.LANCZOS)
    c = r.crop((0, 0, w, h)).convert("RGBA")
    lan = fit(sub, round(h * 0.7), 1.0)
    c.alpha_composite(lan, (round(w * 0.12), round(h * 0.15)))
    save(c.convert("RGB"), path, optimize=True)

# Aset Flutter (WebP)
hero.resize((1600, round(1600 * hero.height / hero.width)), Image.LANCZOS).save(IMG / "hero.webp", quality=76, method=6)
def keyed(path, crop, size):
    """Buang latar rata supaya ilustrasi menyatu dengan warna layar (alfa halus)."""
    im = Image.open(path).convert("RGB").crop(crop)
    bg = im.getpixel((2, 2))
    a = Image.new("L", im.size)
    px, ap = im.load(), a.load()
    for y in range(im.height):
        for x in range(im.width):
            d = max(abs(c - b) for c, b in zip(px[x, y], bg))
            ap[x, y] = max(0, min(255, int((d - 6) * 255 / 30)))
    out = im.convert("RGBA")
    out.putalpha(a)
    return out.resize(size, Image.LANCZOS)


keyed(ART / "empty.png", (250, 330, 1000, 930), (600, 480)).save(IMG / "empty.webp", quality=84, method=6)

# Paket tema Drakor
dk_hero = Image.open(ART / "drakor_hero.png").convert("RGB")
dk_hero.resize((1600, round(1600 * dk_hero.height / dk_hero.width)), Image.LANCZOS).save(IMG / "hero_drakor.webp", quality=76, method=6)
dk_empty = subject(ART / "drakor_empty.png")
pad = round(dk_empty.width * 0.08)
canvas = Image.new("RGBA", (dk_empty.width + 2 * pad, dk_empty.height + 2 * pad), (0, 0, 0, 0))
canvas.alpha_composite(dk_empty, (pad, pad))
canvas.resize((600, round(600 * canvas.height / canvas.width)), Image.LANCZOS).save(IMG / "empty_drakor.webp", quality=84, method=6)
fit(subject(ART / "drakor_logo.png"), 256, 1.0).save(IMG / "logo_drakor.webp", quality=90, method=6)
fit(sub, 256, 1.0).save(IMG / "logo.webp", quality=90, method=6)
print("selesai")
