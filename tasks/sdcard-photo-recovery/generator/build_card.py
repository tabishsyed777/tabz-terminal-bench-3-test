# builds environment/card.img + tests/expected.json
# usage (from task root): python3 generator/build_card.py
import io, json, hashlib, random
import numpy as np
from PIL import Image, ImageDraw

SEED = 4172026
CL = 4096
rng = random.Random(SEED)
nrng = np.random.default_rng(SEED)


def scene(w, h):
    y, x = np.mgrid[0:h, 0:w].astype("float32")
    c = [rng.randint(60, 200) for _ in range(3)]
    g = np.stack([c[0] + 50 * (x / w), c[1] + 50 * (y / h), c[2] + 40 * ((x + y) / (w + h))], -1)
    im = Image.fromarray(np.clip(g, 0, 255).astype("uint8"))
    d = ImageDraw.Draw(im)
    for _ in range(rng.randint(5, 9)):
        x0, y0 = rng.randint(0, w - 100), rng.randint(0, h - 100)
        x1, y1 = x0 + rng.randint(60, w // 3), y0 + rng.randint(60, h // 3)
        col = tuple(rng.randint(0, 255) for _ in range(3))
        (d.ellipse if rng.random() < 0.5 else d.rectangle)([x0, y0, x1, y1], fill=col)
    a = np.asarray(im).astype("float32") + nrng.normal(0, 4, (h, w, 3))
    return Image.fromarray(np.clip(a, 0, 255).astype("uint8"))


def make_photo():
    while True:
        w, h = rng.choice([(480, 360), (512, 384), (560, 420), (640, 480)])
        buf = io.BytesIO()
        scene(w, h).save(buf, "JPEG", quality=rng.choice([88, 90, 92]))
        n = -(-len(buf.getvalue()) // CL)
        if 8 <= n <= 14:
            return buf.getvalue()


def filler():
    k = rng.random()
    if k < 0.55:
        return nrng.integers(0, 256, CL, dtype="uint8").tobytes()
    if k < 0.75:
        return b"\x00" * CL
    if k < 0.9:
        line = ("IMG_%04d.JPG  %d bytes  %02d/%02d/2019\n" % (rng.randint(1, 9999), rng.randint(1000, 9000000), rng.randint(1, 12), rng.randint(1, 28))).encode()
        return (line * (CL // len(line) + 1))[:CL]
    # looks like the start of a jpeg but isn't one
    b = bytearray(nrng.integers(0, 256, CL, dtype="uint8").tobytes())
    b[:4] = b"\xff\xd8\xff\xe1"
    return bytes(b)


def chunks(data):
    data = data + b"\x00" * (-len(data) % CL)
    return [data[i:i + CL] for i in range(0, len(data), CL)]


photos = [make_photo() for _ in range(10)]
# 0-3 contiguous, 4-7 two pieces, 8 loses its second piece, 9 loses its header
runs = []
expected = []
for i, p in enumerate(photos):
    cs = chunks(p)
    if i < 4:
        runs.append([i, 0, cs])
    else:
        cut = rng.randint(3, len(cs) - 3)
        runs.append([i, 0, cs[:cut]])
        runs.append([i, 1, cs[cut:]])
    if i < 8:
        expected.append({"sha256": hashlib.sha256(p).hexdigest(), "size": len(p)})

runs = [r for r in runs if not (r[0] == 8 and r[1] == 1) and not (r[0] == 9 and r[1] == 0)]
rng.shuffle(runs)
for pi in range(10):
    ix = [k for k, r in enumerate(runs) if r[0] == pi]
    if len(ix) == 2 and runs[ix[0]][1] > runs[ix[1]][1]:
        runs[ix[0]], runs[ix[1]] = runs[ix[1]], runs[ix[0]]

disk = [filler() for _ in range(rng.randint(2, 6))]
for r in runs:
    disk += r[2]
    disk += [filler() for _ in range(rng.randint(0, 7))]
disk += [filler() for _ in range(3)]

open("environment/card.img", "wb").write(b"".join(disk))
json.dump({"files": expected}, open("tests/expected.json", "w"), indent=1)
print(len(disk), "clusters,", len(expected), "recoverable photos")
