import hashlib, json, os, sys

OUT = "/app/recovered"
want = {f["sha256"] for f in json.load(open("/tests/expected.json"))["files"]}


def fail(msg):
    print("FAIL:", msg)
    sys.exit(1)


if not os.path.isdir(OUT):
    fail("/app/recovered is missing")
got = {}
for n in sorted(os.listdir(OUT)):
    p = os.path.join(OUT, n)
    if not n.lower().endswith(".jpg") or not os.path.isfile(p):
        fail("unexpected entry in recovered/: " + n)
    got.setdefault(hashlib.sha256(open(p, "rb").read()).hexdigest(), []).append(n)

bad = [v for h, v in got.items() if h not in want]
if bad:
    fail("not exact originals: %s" % bad)
if any(len(v) > 1 for v in got.values()):
    fail("same photo written twice")
if len(got) != len(want):
    fail("recovered %d of %d photos" % (len(got), len(want)))
if hashlib.sha256(open("/app/card.img", "rb").read()).hexdigest() != open("/tests/card.sha256").read().strip():
    fail("card.img was modified")
print("PASS")
