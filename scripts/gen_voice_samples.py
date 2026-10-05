#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Boghi City Tour — نمونه صدای کاراکترها (فارسی بومی)
Motor: edge-tts (Microsoft Neural) — fa-IR-DilaraNeural / fa-IR-FaridNeural
Verification: هر نمونه با ASR round-trip تأیید می‌شود
"""
import asyncio, os, subprocess, json, sys
import edge_tts

OUT = "/home/z/my-project/download/samples/voice"
TMP = "/tmp/boghi_tts_verify"
os.makedirs(OUT, exist_ok=True)
os.makedirs(TMP, exist_ok=True)

# ---- کاراکترها: صدا + زیر و بمی + سرعت ----
CHARACTERS = {
    "boghi":    {"voice": "fa-IR-DilaraNeural", "pitch": "+20Hz", "rate": "+8%",  "desc": "بوقی (ماشین زنده، جوون و شیطون)"},
    "nissan":   {"voice": "fa-IR-FaridNeural",  "pitch": "-8Hz",  "rate": "-6%",  "desc": "نیسان آبی / اکبر سیبیلو (خسته و مهربان)"},
    "wife":     {"voice": "fa-IR-DilaraNeural", "pitch": "+14Hz", "rate": "+14%", "desc": "زن اکبر (جدی و پرصدا)"},
    "sisbalu":  {"voice": "fa-IR-FaridNeural",  "pitch": "+12Hz", "rate": "+10%", "desc": "سیسبلو (کمدین محله)"},
    "narrator": {"voice": "fa-IR-FaridNeural",  "pitch": "+0Hz",  "rate": "-4%",  "desc": "راوی"},
}

# ---- دیالوگ‌های واقعی اپیزود ۱ + نمونه‌های شخصیت ----
LINES = [
    # (filename, actor, text)
    ("01_boghi_greeting",   "boghi",    "صبح بخیر محله! بوقی آماده‌ست، بریم تورِ شهرها!"),
    ("02_boghi_tease",      "boghi",    "اکبر جون رو خوابوندی دوباره؟ دیشب تا صبح تو گاراژ چرت زدی!"),
    ("03_boghi_proud",      "boghi",    "من؟! من ماشینِ تور شهرهاَم! من کورنیش رو باهاش جشن می‌گیرم!"),
    ("04_nissan_greeting",  "nissan",   "صبحت بخیر بوقی‌جان… دلم گرفته."),
    ("05_nissan_funny",     "nissan",   "من چرت نزدم، استراحت فنی کردم. اینجور چیزا رو تو یاد نمی‌گیری."),
    ("06_nissan_nostalgia", "nissan",   "یه بار تو جوونی من قابلمه‌ی کامل بردم… چه روزهایی بود."),
    ("07_wife_potato",      "wife",     "اکبر!!! وایستاده‌ای؟! سر راه دو کیلو سیب‌زمینی بخر بیار! دوتا نون سنگک هم بگیر، از پری‌خانم، داغِ داغ!"),
    ("08_wife_angry",       "wife",     "مأموریتِ خفن؟! تو خفنت مال دو ساعت پیشه!"),
    ("09_wife_insist",      "wife",     "دو تا سنگک میگم!!! دووو تااا!!!"),
    ("10_akbar_mission",    "nissan",   "چشمم… الان… دارم میام… یه مأموریتِ خیلی خفن دارم!"),
    ("11_sisbalu_humor",    "sisbalu",  "سلام به روی ماه همه! امروز نیسانِ آبیِ من شاهده؛ هرکی بوقِ قشنگ‌تر بزنه، مهمونِ چاییِ دُم‌کشیده‌ی منه!"),
    ("12_narrator_intro",   "narrator", "بوقی: تورِ شهرها. داستانِ یه ماشینِ کوچولو با دلِ بزرگ، وسطِ کوچه‌پس‌کوچه‌های تهران."),
]

async def gen_one(fname, actor, text):
    c = CHARACTERS[actor]
    mp3 = os.path.join(OUT, fname + ".mp3")
    cm = edge_tts.Communicate(text, c["voice"], rate=c["rate"], pitch=c["pitch"])
    await cm.save(mp3)
    return mp3

async def main():
    # تولید
    for fname, actor, text in LINES:
        try:
            await gen_one(fname, actor, text)
            print(f"GEN  OK  {fname}.mp3  [{actor}]")
        except Exception as e:
            print(f"GEN  FAIL {fname}: {e}", file=sys.stderr)

    # تأیید: mp3 → wav 16k → ASR round-trip
    report = []
    for fname, actor, text in LINES:
        mp3 = os.path.join(OUT, fname + ".mp3")
        if not os.path.exists(mp3):
            report.append({"file": fname, "ok": False, "err": "missing"})
            continue
        wav = os.path.join(TMP, fname + ".wav")
        subprocess.run(["ffmpeg", "-y", "-v", "quiet", "-i", mp3, "-ar", "16000", "-ac", "1", wav], check=True)
        r = subprocess.run(["z-ai", "asr", "-f", wav, "-o", os.path.join(TMP, fname + ".json")],
                           capture_output=True, text=True, timeout=120)
        asr_text = ""
        try:
            with open(os.path.join(TMP, fname + ".json"), encoding="utf-8") as f:
                asr_text = json.load(f).get("text", "")
        except Exception:
            pass
        # ساده‌سازی برای مقایسه
        def norm(s):
            for ch in ".,!?…،؛:«»()؟":
                s = s.replace(ch, " ")
            return " ".join(s.split()).replace("ی", "ی").replace("ک", "ک").replace("ا", "ا")
        words_src = set(norm(text).split())
        words_asr = set(norm(asr_text).split())
        overlap = len(words_src & words_asr) / max(1, len(words_src))
        report.append({
            "file": fname, "actor": actor, "ok": overlap >= 0.5,
            "match": f"{overlap:.0%}", "asr": asr_text[:160],
            "size": os.path.getsize(mp3),
        })
        print(f"ASR  {fname}: match={overlap:.0%}")

    with open(os.path.join(OUT, "verify_report.json"), "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=1)
    print("REPORT saved:", os.path.join(OUT, "verify_report.json"))

asyncio.run(main())
