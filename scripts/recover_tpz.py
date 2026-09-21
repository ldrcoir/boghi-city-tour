#!/usr/bin/env python3
"""بازیابی فایل‌های سالم از zip ناقص (بدون central directory) با پیمایش local headers"""
import struct
import sys
import zlib

SRC = "/home/z/my-project/tools/dl/templates.tpz"
OUT = "/home/z/.local/share/godot/export_templates/4.7.2.stable"
size = 1233924096

with open(SRC, "rb") as f:
    pos = 0
    recovered = []
    while pos < size - 30:
        f.seek(pos)
        sig = f.read(4)
        if sig != b"PK\x03\x04":
            # جستجوی امضای بعدی (فاصله‌های داده نامتشخص)
            f.seek(pos)
            window = f.read(min(1 << 20, size - pos))
            idx = window.find(b"PK\x03\x04")
            if idx == -1:
                break
            pos += idx
            continue
        hdr = f.read(26)
        if len(hdr) < 26:
            break
        (ver, flags, method, t, d, crc, csize, usize, nlen, elen) = struct.unpack("<HHHHHIIIHH", hdr)
        name = f.read(nlen).decode("utf-8", "replace")
        data_start = pos + 30 + nlen + elen
        # اگر اندازه نامشخص است (پرچم 0x08)، از امضای بعدی استفاده می‌کنیم
        if flags & 0x08:
            break  # streaming entries — tpz معمولاً بدون این پرچم است
        if data_start + csize > size:
            print(f"TRUNCATED at entry: {name}")
            break
        f.seek(data_start)
        data = f.read(csize)
        # تأیید CRC
        if method == 0:
            ok = zlib.crc32(data) & 0xFFFFFFFF == crc
        else:
            try:
                data = zlib.decompress(data, -15)
                ok = zlib.crc32(data) & 0xFFFFFFFF == crc
            except Exception:
                ok = False
        if ok:
            import os
            dest = os.path.join(OUT, name.split("/")[-1])
            os.makedirs(OUT, exist_ok=True)
            with open(dest, "wb") as out:
                out.write(data)
            recovered.append((name, len(data)))
        else:
            print(f"CRC FAIL: {name}")
        pos = data_start + csize

for name, n in recovered:
    print(f"OK {n:>12,}  {name}")
print(f"total recovered: {len(recovered)}")
