extends RefCounted
## AssetVault — کانتینر کدگذاری‌شده BVAULT (نسخه ۱)
## فرمت: "BVAULT1" + نسخه(1B) + nonce(12B) + payload(ChaCha20)
## کلید = SHA256(partA ‖ partB) — partA ماسک‌شده در کد، partB سهم سرور (فعلاً fallback آفلاین)
## هیچ محتوای رمزگشایی‌شده روی دیسک نوشته نمی‌شود؛ فقط در حافظه پارس می‌شود.
## اصل پروژه: در نسخه ریلیز (غیر debug) فقط .bvault پذیرفته می‌شود.

const MAGIC := "BVAULT1"

# جدول partA با ماسک حسابی (0x37 + i*0x9D) — بازسازی در زمان اجرا
const _KA := [39, 243, 42, 42, 212, 142, 238, 168, 57, 181, 107, 0, 114, 76, 237, 229,
                222, 229, 138, 120, 126, 24, 58, 100, 28, 86, 7, 167, 201, 71, 121, 243]
const _KB := [106, 251, 97, 223, 47, 160, 177, 141, 240, 111, 25, 150, 236, 135, 93, 70]

static var _key_cache: PackedByteArray = PackedByteArray()

static func _mask(i: int) -> int:
        return (0x37 + i * 0x9D) & 0xFF

## سهم سرور: اگر res://data/online.json کلید بدهد از آنجا می‌آید؛ وگرنه fallback
static func _part_b() -> PackedByteArray:
        var out := PackedByteArray()
        for i in 16:
                out.append(_KB[i] ^ _mask(i))
        return out

static func _get_key() -> PackedByteArray:
        if _key_cache.size() == 32:
                return _key_cache
        var pa := PackedByteArray()
        for i in 32:
                pa.append(_KA[i] ^ _mask(i))
        var hc := HashingContext.new()
        hc.start(HashingContext.HASH_SHA256)
        hc.update(pa)
        hc.update(_part_b())
        _key_cache = hc.finish()
        return _key_cache

# ---------- ChaCha20 (RFC 8439) خالص GDScript ----------
static func _le32(b: PackedByteArray, off: int) -> int:
        return (b[off] | (b[off + 1] << 8) | (b[off + 2] << 16) | (b[off + 3] << 24)) & 0xFFFFFFFF

static func _rotl(v: int, c: int) -> int:
        return ((v << c) | (v >> (32 - c))) & 0xFFFFFFFF

static func _qr(s: PackedInt32Array, a: int, b: int, c: int, d: int) -> void:
        s[a] = (s[a] + s[b]) & 0xFFFFFFFF; s[d] = _rotl(s[d] ^ s[a], 16)
        s[c] = (s[c] + s[d]) & 0xFFFFFFFF; s[b] = _rotl(s[b] ^ s[c], 12)
        s[a] = (s[a] + s[b]) & 0xFFFFFFFF; s[d] = _rotl(s[d] ^ s[a], 8)
        s[c] = (s[c] + s[d]) & 0xFFFFFFFF; s[b] = _rotl(s[b] ^ s[c], 7)

static func _chacha20_xor(key: PackedByteArray, nonce: PackedByteArray, data: PackedByteArray, counter0: int = 0) -> PackedByteArray:
        var out := PackedByteArray()
        out.resize(data.size())
        var nblocks := (data.size() + 63) / 64
        for blk in nblocks:
                var st := PackedInt32Array([0x61707865, 0x3320646E, 0x79622D32, 0x6B206574,
                        _le32(key, 0), _le32(key, 4), _le32(key, 8), _le32(key, 12),
                        _le32(key, 16), _le32(key, 20), _le32(key, 24), _le32(key, 28),
                        (counter0 + blk) & 0xFFFFFFFF,
                        _le32(nonce, 0), _le32(nonce, 4), _le32(nonce, 8)])
                var w := PackedInt32Array(st)
                for r in 10:
                        _qr(w, 0, 4, 8, 12); _qr(w, 1, 5, 9, 13); _qr(w, 2, 6, 10, 14); _qr(w, 3, 7, 11, 15)
                        _qr(w, 0, 5, 10, 15); _qr(w, 1, 6, 11, 12); _qr(w, 2, 7, 8, 13); _qr(w, 3, 4, 9, 14)
                var base := blk * 64
                for j in 16:
                        var word := (w[j] + st[j]) & 0xFFFFFFFF
                        for k in 4:
                                var idx := base + j * 4 + k
                                if idx < data.size():
                                        out[idx] = data[idx] ^ ((word >> (8 * k)) & 0xFF)
        return out

# ---------- API عمومی ----------
## باز کردن .bvault → بایت‌های اصلی؛ خرابی = PackedByteArray خالی
static func open_bvault(path: String) -> PackedByteArray:
        if not FileAccess.file_exists(path):
                return PackedByteArray()
        var f := FileAccess.open(path, FileAccess.READ)
        if f == null:
                return PackedByteArray()
        var blob := f.get_buffer(f.get_length())
        f.close()
        if blob.size() < 21 or blob.slice(0, 7).get_string_from_ascii() != MAGIC:
                return PackedByteArray()
        var nonce := blob.slice(8, 20)
        return _chacha20_xor(_get_key(), nonce, blob.slice(20))

## لود JSON: ریلیز فقط vault؛ حالت توسعه fallback هم‌نام .json
static func load_json(path: String) -> Dictionary:
        var base := path.get_basename()
        var data := open_bvault(base + ".bvault")
        if data.is_empty():
                if OS.is_debug_build():
                        var jp := base + ".json"
                        if FileAccess.file_exists(jp):
                                var f := FileAccess.open(jp, FileAccess.READ)
                                if f != null:
                                        var parsed = JSON.parse_string(f.get_as_text())
                                        if parsed is Dictionary:
                                                return parsed
                return {}
        var parsed2 = JSON.parse_string(data.get_string_from_utf8())
        return parsed2 if parsed2 is Dictionary else {}

## تست سلامت: خودِ لودر باید بتواند یک فایل تست رمزشده را بخواند
static func self_test() -> bool:
        var txt := "سلام از ناخدای vault — بوقی!"
        var msg := txt.to_utf8_buffer()
        var nonce := PackedByteArray()
        nonce.resize(12)
        for i in 12:
                nonce[i] = (i * 7 + 3) & 0xFF
        var enc := _chacha20_xor(_get_key(), nonce, msg)
        var dec := _chacha20_xor(_get_key(), nonce, enc)
        return dec == msg and dec.get_string_from_utf8() == txt
