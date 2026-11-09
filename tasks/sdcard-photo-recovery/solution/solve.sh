#!/bin/bash
set -euo pipefail
python3 - <<'PY'
from io import BytesIO
from pathlib import Path
import shutil

from PIL import Image, ImageFile

ImageFile.LOAD_TRUNCATED_IMAGES = False
CLUSTER = 4096
MAX_PHOTO_CLUSTERS = 14
MIN_PHOTO_BYTES = 28_000
MAX_PHOTO_BYTES = 51_000
DISK = Path("/app/card.img")
OUT = Path("/app/recovered")

raw = DISK.read_bytes()
clusters = [raw[i:i + CLUSTER] for i in range(0, len(raw), CLUSTER)]
heads = [i for i, block in enumerate(clusters) if block.startswith(b"\xff\xd8\xff")]

def footer(block):
    end = block.rfind(b"\xff\xd9")
    if end < 0 or any(block[end + 2:]):
        return None
    return end

footers = {i: pos for i, block in enumerate(clusters) if (pos := footer(block)) is not None}

class NeedMoreData(Exception):
    pass

class InvalidJpeg(Exception):
    pass

def build_huffman(counts, symbols):
    table, code, offset = {}, 0, 0
    for length in range(1, 17):
        for _ in range(counts[length - 1]):
            table[(length, code)] = symbols[offset]
            code += 1
            offset += 1
        code <<= 1
    return table

def parse_jpeg(data):
    if data[:2] != b"\xff\xd8":
        return None
    i, dc, ac, components, width, height = 2, {}, {}, [], 0, 0
    while i + 4 <= len(data):
        if data[i] != 0xFF:
            return None
        marker = data[i + 1]
        length = int.from_bytes(data[i + 2:i + 4], "big")
        if length < 2 or i + 2 + length > len(data):
            return None
        segment = data[i + 4:i + 2 + length]
        if marker in (0xC1, 0xC2, 0xC3):
            return None
        if marker == 0xC0:
            if len(segment) < 6:
                return None
            height, width = int.from_bytes(segment[1:3], "big"), int.from_bytes(segment[3:5], "big")
            components = [
                (segment[6 + 3 * k], segment[7 + 3 * k] >> 4, segment[7 + 3 * k] & 15)
                for k in range(segment[5])
            ]
        elif marker == 0xC4:
            j = 0
            while j < len(segment):
                if j + 17 > len(segment):
                    return None
                table_class, table_id = segment[j] >> 4, segment[j] & 15
                counts = list(segment[j + 1:j + 17])
                count = sum(counts)
                symbols = segment[j + 17:j + 17 + count]
                if len(symbols) != count:
                    return None
                (ac if table_class else dc)[table_id] = build_huffman(counts, symbols)
                j += 17 + count
        elif marker == 0xDA:
            if not components or not dc or width == 0 or len(segment) < 1:
                return None
            selectors = {
                segment[1 + 2 * k]: (segment[2 + 2 * k] >> 4, segment[2 + 2 * k] & 15)
                for k in range(segment[0])
            }
            hmax = max(component[1] for component in components)
            vmax = max(component[2] for component in components)
            total = ((width + 8 * hmax - 1) // (8 * hmax)) * ((height + 8 * vmax - 1) // (8 * vmax))
            blocks = []
            for component_index, (component_id, h_sampling, v_sampling) in enumerate(components):
                if component_id not in selectors:
                    return None
                dc_id, ac_id = selectors[component_id]
                if dc_id not in dc or ac_id not in ac:
                    return None
                blocks.extend([(component_index, dc[dc_id], ac[ac_id])] * (h_sampling * v_sampling))
            return {"start": i + 2 + length, "total": total, "blocks": blocks, "ncomp": len(components)}
        i += 2 + length
    return None

def decode_complete_scan(header, entropy):
    mcu, predictors, bit_offset = 0, [0] * header["ncomp"], 0
    body = entropy
    if b"\xff" in body.replace(b"\xff\x00", b""):
        return False
    bits = body.replace(b"\xff\x00", b"\xff")
    bit_count = len(bits) * 8
    position = bit_offset

    def read_bit():
        nonlocal position
        if position >= bit_count:
            raise NeedMoreData()
        value = (bits[position >> 3] >> (7 - (position & 7))) & 1
        position += 1
        return value

    def read_symbol(table):
        code = 0
        for length in range(1, 17):
            code = (code << 1) | read_bit()
            if (length, code) in table:
                return table[(length, code)]
        raise InvalidJpeg()

    def receive(count):
        value = 0
        for _ in range(count):
            value = (value << 1) | read_bit()
        return value

    try:
        while mcu < header["total"]:
            for component_index, dc_table, ac_table in header["blocks"]:
                category = read_symbol(dc_table)
                if category > 11:
                    return False
                value = receive(category)
                predictors[component_index] += value if category == 0 or value >> (category - 1) else value - (1 << category) + 1
                k = 1
                while k < 64:
                    run_size = read_symbol(ac_table)
                    run, size = run_size >> 4, run_size & 15
                    if size == 0:
                        if run == 15:
                            k += 16
                            continue
                        break
                    k += run
                    if k > 63:
                        return False
                    receive(size)
                    k += 1
            mcu += 1
    except NeedMoreData:
        return False
    except InvalidJpeg:
        return False

    left = bit_count - position
    if left >= 8:
        return False
    if left and (bits[-1] & ((1 << left) - 1)) != (1 << left) - 1:
        return False
    return True

def strict_jpeg(data):
    header = parse_jpeg(data)
    if not header or len(data) < header["start"] + 2:
        return False
    return decode_complete_scan(header, data[header["start"]:-2])

def complete_jpeg(data):
    """Accept only a decodable JPEG whose EOI is the sole EOI and final bytes."""
    if not MIN_PHOTO_BYTES <= len(data) <= MAX_PHOTO_BYTES:
        return False
    if not data.startswith(b"\xff\xd8") or not data.endswith(b"\xff\xd9"):
        return False
    if data.count(b"\xff\xd9") != 1:
        return False
    try:
        with Image.open(BytesIO(data)) as image:
            if image.format != "JPEG":
                return False
            image.verify()
        with Image.open(BytesIO(data)) as image:
            image.load()
        return strict_jpeg(data)
    except (OSError, ValueError, SyntaxError):
        return False

def exact_candidate(first, second, eoi):
    tail_end = second.rfind(b"\xff\xd9")
    if tail_end != eoi or any(second[tail_end + 2:]):
        return None
    data = first + second[:tail_end + 2]
    if complete_jpeg(data):
        return data
    return None

# A candidate records the clusters it consumes. Gaps between a photo's two
# pieces remain available for other files, as required by the task.
candidates = {}
for head in heads:
    for end, eoi in footers.items():
        if end < head:
            continue

        contiguous_len = end - head + 1
        if contiguous_len <= MAX_PHOTO_CLUSTERS:
            blob = b"".join(clusters[head:end + 1])
            eoi_offset = len(blob) - len(clusters[end]) + eoi
            data = exact_candidate(b"", blob, eoi_offset)
            if data is not None:
                key = (head, end)
                candidate = (head, end, frozenset(range(head, end + 1)), data)
                old = candidates.get(key)
                if old is None or (len(data), len(candidate[2])) < (len(old[3]), len(old[2])):
                    candidates[key] = candidate

        for first_len in range(1, MAX_PHOTO_CLUSTERS):
            split = head + first_len
            first = b"".join(clusters[head:split])
            max_second = MAX_PHOTO_CLUSTERS - first_len
            for second_len in range(1, max_second + 1):
                second_start = end - second_len + 1
                if second_start < split:
                    continue
                second = b"".join(clusters[second_start:end + 1])
                eoi_offset = len(second) - len(clusters[end]) + eoi
                data = exact_candidate(first, second, eoi_offset)
                if data is None:
                    continue
                key = (head, end)
                span = frozenset(range(head, split)) | frozenset(range(second_start, end + 1))
                old = candidates.get(key)
                if old is None or (len(data), len(span)) < (len(old[3]), len(old[2])):
                    candidates[key] = (head, end, span, data)

# Different candidate boundaries can produce the same valid image. Select a
# largest non-overlapping set, preferring the shortest byte-exact outputs.
items = sorted(candidates.values(), key=lambda item: (len(item[3]), item[0], item[1]))
best = []
best_bytes = float("inf")

def choose(index, selected, used, used_heads, used_ends, byte_count):
    global best, best_bytes
    if len(selected) > len(best) or (len(selected) == len(best) and byte_count < best_bytes):
        best = list(selected)
        best_bytes = byte_count
    if index == len(items) or len(selected) + len(items) - index < len(best):
        return

    head, end, span, data = items[index]
    if head not in used_heads and end not in used_ends and not (span & used):
        selected.append(items[index])
        choose(index + 1, selected, used | span, used_heads | {head}, used_ends | {end}, byte_count + len(data))
        selected.pop()
    choose(index + 1, selected, used, used_heads, used_ends, byte_count)

choose(0, [], frozenset(), frozenset(), frozenset(), 0)

shutil.rmtree(OUT, ignore_errors=True)
OUT.mkdir(parents=True, exist_ok=True)
for number, (_, _, _, data) in enumerate(best, 1):
    (OUT / f"photo_{number:02d}.jpg").write_bytes(data)
print("recovered", len(best))
PY
