# Makes the cut "mx" logo (logo-large.png) from banner.png:
#   python3 make-logo.py banner.png logo-large.png
import sys
import numpy as np
from PIL import Image, ImageFilter

src = Image.open(sys.argv[1]).convert("RGB")
a = np.asarray(src).astype(np.float32)
# Purple-ness: the glyph is (111,47,147) on black; use the red+blue channels.
alpha = np.clip((a[..., 0] + a[..., 2]) / (111 + 147), 0, 1)
ys, xs = np.where(alpha > 0.1)
pad = 6
crop = alpha[ys.min() - pad:ys.max() + pad, xs.min() - pad:xs.max() + pad]

# Upscale and re-threshold for smooth, crisp edges.
S = 10
img = Image.fromarray((crop * 255).astype(np.uint8))
big = img.resize((img.width * S, img.height * S), Image.BICUBIC).filter(ImageFilter.GaussianBlur(S * 0.9))
m = np.asarray(big).astype(np.float32) / 255
edge = 0.06
m = np.clip((m - 0.5) / edge + 0.5, 0, 1)
h, w = m.shape

# Cut along a slight upward diagonal through the middle; slide the top piece
# along the cut and leave a thin gap.
angle = np.deg2rad(-8)            # line rises to the right
cx, cy = w * 0.5, h * 0.52
yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
# signed distance from the cut line (positive = below)
nx, ny = -np.sin(angle), np.cos(angle)
d = (xx - cx) * nx + (yy - cy) * ny
gap = h * 0.035
aa = 1.5
below = np.clip((d - gap / 2) / aa + 0.5, 0, 1)
above = np.clip((-d - gap / 2) / aa + 0.5, 0, 1)
lower = m * below
upper = m * above

shift = w * 0.06
dx, dy = shift * np.cos(angle), shift * np.sin(angle)
P = int(shift * 1.5) + 4
canvas_w, canvas_h = w + 2 * P, h + 2 * P
out = np.zeros((canvas_h, canvas_w), np.float32)
out[P:P + h, P:P + w] = np.maximum(out[P:P + h, P:P + w], lower)
up = Image.fromarray((upper * 255).astype(np.uint8))
# move the top piece by (dx, dy) with sub-pixel accuracy
up = up.transform(up.size, Image.AFFINE, (1, 0, -dx, 0, 1, -dy), resample=Image.BICUBIC)
upa = np.asarray(up).astype(np.float32) / 255
out[P:P + h, P:P + w] = np.maximum(out[P:P + h, P:P + w], upa)

ys, xs = np.where(out > 0.02)
out = out[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
logo = Image.new("RGBA", (out.shape[1], out.shape[0]), (111, 47, 147, 0))
logo.putalpha(Image.fromarray((out * 255).astype(np.uint8)))
logo.save(sys.argv[2])
print(logo.size)
