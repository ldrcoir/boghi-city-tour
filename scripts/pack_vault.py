#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
pack_vault.py — پکر و رمزگذار BVAULT برای بوقی (ChaCha20 خالص پایتون، بدون وابستگی)

فرمت خروجی: b"BVAULT1" + b"\\x01" + nonce(12) + chacha20_xor(key, nonce, counter=0, plaintext)
key = sha256(partA || partB) — partA/partB همان جدول‌های ماسک‌شده داخل asset_vault.gd

دستورها:
  encrypt <in> <out.bvault>
  decrypt <in.bvault> <out>
  selftest                       — بردار استاندارد RFC 8439 + راند‌تریپ
"""
import sys, os, hashlib, secrets

# --- کلیدها: باید دقیقاً با asset_vault.gd یکی باشند ---
def _mask(i: int) -> int:
    return (0x37 + i * 0x9D) & 0xFF

_KA = [39, 243, 42, 42, 212, 142, 238, 168, 57, 181, 107, 0, 114, 76, 237, 229,
       222, 229, 138, 120, 126, 24, 58, 100, 28, 86, 7, 167, 201, 71, 121, 243]
_KB = [106, 251, 97, 223, 47, 160, 177, 141, 240, 111, 25, 150, 236, 135, 93, 70]

PART_A = bytes(_KA[i] ^ _mask(i) for i in range(32))
PART_B = bytes(_KB[i] ^ _mask(i) for i in range(16))

def derive_key() -> bytes:
    return hashlib.sha256(PART_A + PART_B).digest()

# --- ChaCha20 (RFC 8439) ---
def _rotl(v: int, c: int) -> int:
    return ((v << c) & 0xFFFFFFFF) | (v >> (32 - c))

def _qr(x, a, b, c, d):
    x[a] = (x[a] + x[b]) & 0xFFFFFFFF; x[d] ^= x[a]; x[d] = _rotl(x[d], 16)
    x[c] = (x[c] + x[d]) & 0xFFFFFFFF; x[b] ^= x[c]; x[b] = _rotl(x[b], 12)
    x[a] = (x[a] + x[b]) & 0xFFFFFFFF; x[d] ^= x[a]; x[d] = _rotl(x[d], 8)
    x[c] = (x[c] + x[d]) & 0xFFFFFFFF; x[b] ^= x[c]; x[b] = _rotl(x[b], 7)

def chacha_block(key: bytes, counter: int, nonce: bytes) -> bytes:
    st = [0x61707865, 0x3320646E, 0x79622D32, 0x6B206574]
    st += [int.from_bytes(key[i*4:(i+1)*4], "little") for i in range(8)]
    st += [counter & 0xFFFFFFFF]
    st += [int.from_bytes(nonce[i*4:(i+1)*4], "little") for i in range(3)]
    w = st[:]
    for _ in range(10):
        _qr(w, 0, 4, 8, 12); _qr(w, 1, 5, 9, 13); _qr(w, 2, 6, 10, 14); _qr(w, 3, 7, 11, 15)
        _qr(w, 0, 5, 10, 15); _qr(w, 1, 6, 11, 12); _qr(w, 2, 7, 8, 13); _qr(w, 3, 4, 9, 14)
    out = b"".join(((w[i] + st[i]) & 0xFFFFFFFF).to_bytes(4, "little") for i in range(16))
    return out

def chacha20_xor(key: bytes, nonce: bytes, data: bytes, counter: int = 0) -> bytes:
    out = bytearray(len(data))
    for bi in range(0, len(data), 64):
        ks = chacha_block(key, counter + bi // 64, nonce)
        chunk = data[bi:bi + 64]
        for j, byte in enumerate(chunk):
            out[bi + j] = byte ^ ks[j]
    return bytes(out)

MAGIC = b"BVAULT1\x01"

def encrypt_bytes(pt: bytes) -> bytes:
    nonce = secrets.token_bytes(12)
    return MAGIC + nonce + chacha20_xor(derive_key(), nonce, pt)

def decrypt_bytes(blob: bytes) -> bytes:
    if blob[:8] != MAGIC:
        raise ValueError("bad magic")
    nonce = blob[8:20]
    return chacha20_xor(derive_key(), nonce, blob[20:])

def _selftest() -> int:
    # بردار RFC 8439 §2.4.2
    key = bytes(range(32))
    nonce = bytes.fromhex("000000000000004a00000000")
    pt = b"Ladies and Gentlemen of the class of '99: If I could offer you only one tip for the future, sunscreen would be it."
    want = bytes.fromhex(
        "6e2e359a2568f98041ba0728dd0d6981e97e7aec1d4360c20a27afccfd9fae0b"
        "f91b65c5524733ab8f593dabcd62b3571639d624e65152ab8f530c359f0861d8"
        "07ca0dbf500d6a6156a38e088a22b65e52bc514d16ccf806818ce91ab7793736"
        "5af90bbf74a35be6b40b8eedf2785e42874d")
    got = chacha20_xor(key, nonce, pt, counter=1)  # بردار RFC با کانتر ۱ است
    assert got == want, "RFC vector FAILED"
    rt = decrypt_bytes(encrypt_bytes("بوقی سالم است — ".encode("utf-8") * 40))
    assert rt == "بوقی سالم است — ".encode("utf-8") * 40, "roundtrip FAILED"
    print("selftest OK — RFC 8439 vector + UTF-8 roundtrip")
    return 0

def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__); return 1
    cmd = sys.argv[1]
    if cmd == "selftest":
        return _selftest()
    if cmd in ("encrypt", "decrypt") and len(sys.argv) == 4:
        src, dst = sys.argv[2], sys.argv[3]
        blob = open(src, "rb").read()
        out = encrypt_bytes(blob) if cmd == "encrypt" else decrypt_bytes(blob)
        open(dst, "wb").write(out)
        print(f"{cmd} OK: {src} -> {dst} ({len(out)} bytes)")
        return 0
    print(__doc__); return 1

if __name__ == "__main__":
    sys.exit(main())
