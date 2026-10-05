#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Boghi City Tour — پیش‌نمایش انیمیشن + صدا (HTML مستقل)
- صحنه‌ی اپیزود ۱ «سیب‌زمینی و سنگک» با پلیر کات‌سین (همان منطق story.gd)
- گالری حالت‌های انیمیشن: پلک، نگاه به عقب، بونس، جشن
- لیست صدای کاراکترها (۱۲ نمونه)
همه‌ی تصاویر و صداها base64 داخل خود فایل.
"""
import base64, io, json, os
from PIL import Image

ROOT = "/home/z/my-project"
OUT_HTML = os.path.join(ROOT, "download/samples/animation_preview.html")

def img_b64(path, width=420):
    im = Image.open(path).convert("RGBA")
    r = width / im.width
    im = im.resize((width, int(im.height * r)), Image.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, "PNG", optimize=True)
    return base64.b64encode(buf.getvalue()).decode()

def mp3_b64(path):
    with open(path, "rb") as f:
        return base64.b64encode(f.read()).decode()

BOGHI = img_b64(os.path.join(ROOT, "game/assets/sprites/boghi_side.png"), 420)
NISSAN = img_b64(os.path.join(ROOT, "game/assets/sprites/nissan_side.png"), 460)

VOICE_DIR = os.path.join(ROOT, "download/samples/voice")
LINES = [
    # id, actor, who, text, offscreen
    ("01", "boghi",  "بوقی",        "صبح بخیر محله! بوقی آماده‌ست، بریم تورِ شهرها!", False),
    ("02", "boghi",  "بوقی",        "اکبر جون رو خوابوندی دوباره؟ دیشب تا صبح تو گاراژ چرت زدی!", False),
    ("03", "boghi",  "بوقی",        "من؟! من ماشینِ تور شهرهاَم! من کورنیش رو باهاش جشن می‌گیرم!", False),
    ("04", "nissan", "نیسان آبی",   "صبحت بخیر بوقی‌جان… دلم گرفته.", False),
    ("05", "nissan", "نیسان آبی",   "من چرت نزدم، استراحت فنی کردم. اینجور چیزا رو تو یاد نمی‌گیری.", False),
    ("06", "nissan", "نیسان آبی",   "یه بار تو جوونی من قابلمه‌ی کامل بردم… چه روزهایی بود.", False),
    ("07", "wife",   "زن اکبر",     "اکبر!!! وایستاده‌ای؟! سر راه دو کیلو سیب‌زمینی بخر بیار! دوتا نون سنگک هم بگیر، از پری‌خانم، داغِ داغ!", True),
    ("08", "wife",   "زن اکبر",     "مأموریتِ خفن؟! تو خفنت مال دو ساعت پیشه!", True),
    ("09", "wife",   "زن اکبر",     "دو تا سنگک میگم!!! دووو تااا!!!", True),
    ("10", "nissan", "اکبر سیبیلو", "چشمم… الان… دارم میام… یه مأموریتِ خیلی خفن دارم!", False),
    ("11", "sisbalu","سیسبلو",      "سلام به روی ماه همه! امروز نیسانِ آبیِ من شاهده؛ هرکی بوقِ قشنگ‌تر بزنه، مهمونِ چاییِ دُم‌کشیده‌ی منه!", True),
    ("12", "narrator","راوی",       "بوقی: تورِ شهرها. داستانِ یه ماشینِ کوچولو با دلِ بزرگ، وسطِ کوچه‌پس‌کوچه‌های تهران.", False),
]
VOICES = {lid: mp3_b64(os.path.join(VOICE_DIR, f"{lid}_{n}.mp3")) for lid, n, _, _, _ in
          [(l[0], ["boghi_greeting","boghi_tease","boghi_proud","nissan_greeting","nissan_funny","nissan_nostalgia",
                   "wife_potato","wife_angry","wife_insist","akbar_mission","sisbalu_humor","narrator_intro"][i], l[2], l[3], l[4])
           for i, l in enumerate(LINES)]}

VOICES_JSON = json.dumps(VOICES)
LINES_JSON = json.dumps([{"id": l[0], "actor": l[1], "who": l[2], "text": l[3], "off": l[4]} for l in LINES],
                        ensure_ascii=False)

html = """<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>بوقی — پیش‌نمایش انیمیشن و صدا</title>
<style>
  * { margin:0; padding:0; box-sizing:border-box; }
  body { font-family: Tahoma, "Segoe UI", sans-serif; background:#1a1430; color:#fff; }
  .wrap { max-width: 900px; margin: 0 auto; padding: 18px; }
  h1 { font-size: 26px; color:#ffd94a; margin: 10px 0 4px; }
  h2 { font-size: 20px; color:#7ee0ff; margin: 26px 0 10px; border-right: 4px solid #7ee0ff; padding-right: 10px; }
  .sub { color:#b9aee0; font-size: 14px; line-height: 1.9; }
  .panel { background:#241c44; border-radius: 16px; padding: 14px; margin-top: 12px; box-shadow: 0 6px 24px rgba(0,0,0,.35); }

  /* ===== صحنه ===== */
  #stage { position:relative; width:100%; aspect-ratio: 16/9; border-radius:12px; overflow:hidden;
           background: linear-gradient(#7ec8f7 0%, #b8e4fb 55%, #d9c99a 55%, #c9b688 100%); }
  .sun { position:absolute; top:6%; left:8%; width:52px; height:52px; border-radius:50%;
         background:#ffdd55; box-shadow:0 0 40px 12px rgba(255,220,80,.55); }
  .bld { position:absolute; bottom:45%; display:flex; gap:6px; }
  .bld div { width:34px; background:#8f7bb8; border-radius:4px 4px 0 0; position:relative; }
  .bld div::before { content:""; position:absolute; inset:8px 6px; background:rgba(255,255,255,.25); border-radius:2px; }
  .car { position:absolute; bottom:6%; width:26%; transform-origin:50% 90%; transition: all .9s cubic-bezier(.4,.1,.3,1); }
  .car img { width:100%; display:block; filter: drop-shadow(0 10px 6px rgba(0,0,0,.28)); }
  #boghiCar { right:-30%; }
  #nissanCar { left:-34%; }
  #nissanCar img { filter: hue-rotate(200deg) saturate(1.15) drop-shadow(0 10px 6px rgba(0,0,0,.28)); }

  /* پلک — پل متحرک روی ناحیه چشم */
  .lid { position:absolute; background:#f7f3e8; border-radius:40%; transform: scaleY(0); transform-origin: top; z-index:5; }
  .lid::after { content:""; position:absolute; bottom:6%; left:14%; right:14%; height:9%;
                background:#2a2a2a; border-radius:50%; }
  /* اندازه‌گیری‌شده از اسپرایت boghi_side.png (گرید ۱۰٪) */
  .lidL { top:12%; left:43%; width:15%; height:20%; }
  .lidR { top:12%; left:57.5%; width:15%; height:20%; }
  /* اندازه‌گیری‌شده از nissan_side.png */
  #nissanCar .lidL { top:11%; left:41%; width:15%; height:22%; background:#fdf8ee; }
  #nissanCar .lidR { top:11%; left:55.5%; width:15.5%; height:22%; background:#fdf8ee; }

  /* حالت حرف زدن */
  .talking { animation: talk .5s ease-in-out infinite; }
  @keyframes talk { 0%,100%{ transform: translateY(0) rotate(0deg);} 50%{ transform: translateY(-2.5%) rotate(-1deg);} }

  .banner { position:absolute; inset:0; display:flex; align-items:center; justify-content:center;
            background:rgba(15,10,35,.75); color:#ffd94a; font-size: clamp(16px, 3.4vw, 28px); font-weight:bold;
            opacity:0; transition: opacity .5s; z-index:20; text-align:center; padding:20px; }

  /* جعبه دیالوگ */
  #dbox { position:absolute; right:3%; left:3%; bottom:3%; z-index:30; background:rgba(20,14,45,.92);
          border:2px solid #ffd94a; border-radius:14px; padding:10px 14px; min-height:64px; display:none; }
  #dname { color:#7ee0ff; font-weight:bold; font-size:14px; margin-bottom:4px; }
  #dtext { font-size: clamp(13px, 2.4vw, 17px); line-height:1.8; color:#fff; min-height:1.8em; }
  #dtext .caret { display:inline-block; width:8px; background:#ffd94a; animation: blink .8s infinite; }
  @keyframes blink { 50%{ opacity:0; } }

  .controls { display:flex; gap:10px; margin-top:12px; flex-wrap:wrap; }
  button { background:#ffd94a; color:#241c44; border:none; border-radius:10px; padding:10px 20px;
           font-size:15px; font-weight:bold; cursor:pointer; font-family:inherit; }
  button:hover { background:#ffe27a; }
  button.sec { background:#3d3268; color:#d9d0f5; }

  /* ===== گالری حالت‌ها ===== */
  .gallery { display:grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap:12px; }
  .card { background:#241c44; border-radius:14px; padding:12px; text-align:center; }
  .card .view { position:relative; height:120px; display:flex; align-items:flex-end; justify-content:center; overflow:hidden; }
  .card .view img { width:150px; filter: drop-shadow(0 8px 5px rgba(0,0,0,.3)); }
  .card b { display:block; color:#ffd94a; margin-top:8px; font-size:15px; }
  .card span { color:#b9aee0; font-size:12px; line-height:1.7; display:block; }

  .anim-blink .lid { animation: lid 2.6s infinite; }
  @keyframes lid { 0%,90%,100%{ transform:scaleY(0);} 93%,97%{ transform:scaleY(1);} }

  .anim-look img { animation: look 3.2s ease-in-out infinite; }
  @keyframes look { 0%,40%,100%{ transform: translateX(0) rotate(0);} 55%,75% { transform: translateX(-9%) rotate(3deg);} }

  .anim-bounce img { animation: bnc 1.6s ease-in-out infinite; transform-origin:50% 95%; }
  @keyframes bnc { 0%,100%{ transform: scaleY(1) translateY(0);} 12%{ transform: scaleY(.96) translateY(2%);}
                   30%{ transform: scaleY(1.04) translateY(-7%);} 45%{ transform: scaleY(.98) translateY(0);} }

  .anim-party img { animation: party 1.9s ease-in-out infinite; }
  .conf { position:absolute; width:8px; height:12px; top:-10px; border-radius:2px; opacity:.9; }
  .conf:nth-child(odd){ animation: fall 1.5s linear infinite; }
  .conf:nth-child(even){ animation: fall 1.9s .4s linear infinite; }
  @keyframes fall { to { transform: translateY(150px) rotate(340deg); opacity:0; } }

  /* ===== صداها ===== */
  .vrow { display:flex; align-items:center; gap:10px; background:#2c2255; border-radius:10px;
          padding:9px 12px; margin-top:8px; }
  .vrow .who { color:#ffd94a; font-weight:bold; font-size:13px; min-width:78px; }
  .vrow .txt { color:#cfc6ee; font-size:13px; flex:1; line-height:1.7; }
  .play { background:#7ee0ff; color:#122; border-radius:50%; width:36px; height:36px; min-width:36px;
          font-size:15px; padding:0; }
  .note { background:#33285f; border-right:4px solid #ffd94a; border-radius:10px; padding:12px 14px;
          font-size:13.5px; line-height:2.1; color:#d9d0f5; margin-top:10px; }
</style>
</head>
<body>
<div class="wrap">
  <h1>🚗 بوقی: تورِ شهرها — پیش‌نمایش انیمیشن و صدا</h1>
  <p class="sub">این فایل دقیقاً همان چیزی است که در بازی ساخته می‌شود: موتور کات‌سین (banner → enter → line → bounce → move)،
  جعبه‌ی دیالوگ RTL با تایپ‌رایتر، پلک‌زدن، حرف‌زدن، بونس و جشن — به‌همراه صدای واقعی کاراکترها به فارسی بومی (Dilara/Farid Neural).
  دکمه‌ی پخش را بزن!</p>

  <h2>🎬 صحنه‌ی اپیزود ۱ — «سیب‌زمینی و سنگک»</h2>
  <div class="panel">
    <div id="stage">
      <div class="sun"></div>
      <div class="bld" style="right:4%"><div style="height:90px"></div><div style="height:130px"></div><div style="height:70px"></div><div style="height:110px"></div></div>
      <div class="bld" style="left:30%"><div style="height:80px"></div><div style="height:120px"></div><div style="height:60px"></div></div>
      <div id="nissanCar" class="car"><img src="data:image/png;base64,__NISSAN__" alt="نیسان">
        <div class="lid lidL"></div><div class="lid lidR"></div></div>
      <div id="boghiCar" class="car"><img src="data:image/png;base64,__BOGHI__" alt="بوقی">
        <div class="lid lidL"></div><div class="lid lidR"></div></div>
      <div id="banner" class="banner">اپیزود ۱ — سیب‌زمینی و سنگک</div>
      <div id="dbox"><div id="dname"></div><div id="dtext"></div></div>
    </div>
    <div class="controls">
      <button onclick="playScene()">▶ پخش اپیزود</button>
      <button class="sec" onclick="stopScene()">⏹ توقف</button>
      <button class="sec" onclick="testBlink()">پلک بزن!</button>
      <button class="sec" onclick="testParty()">🎉 جشن بوقی</button>
    </div>
  </div>

  <h2>🎞 گالری حالت‌های انیمیشن (لوپ بی‌وقفه)</h2>
  <div class="gallery">
    <div class="card anim-blink"><div class="view">
      <div style="position:relative"><img src="data:image/png;base64,__BOGHI__" alt=""><div class="lid lidL"></div><div class="lid lidR"></div></div>
    </div><b>پلک‌زدن (Blink)</b><span>در مسابقه هر ۲.۶ ثانیه — حس «زنده بودن» ماشین</span></div>
    <div class="card anim-look"><div class="view">
      <img src="data:image/png;base64,__BOGHI__" alt="">
    </div><b>نگاه به عقب (Look-back)</b><span>وقتی حریف نزدیک می‌شود، ماشین نگاهی می‌اندازد</span></div>
    <div class="card anim-bounce"><div class="view">
      <img src="data:image/png;base64,__BOGHI__" alt="">
    </div><b>بونس Idle</b><span>تنفس آرام در صحنه‌های گفتگو</span></div>
    <div class="card anim-party"><div class="view" id="partyView">
      <img src="data:image/png;base64,__BOGHI__" alt="">
    </div><b>جشن پایان مسابقه 🎉</b><span>پرش + کانفتی — چند دقیقه بعد از خط پایان</span></div>
  </div>

  <h2>🔊 نمونه صدای کاراکترها (فارسی بومی)</h2>
  <div class="panel" id="voiceList"></div>

  <div class="note">
    <b>پاسخ سؤال «انیمیشن‌ها کد هستند یا…؟»:</b> ترکیبی است.<br>
    ۱) <b>اسپرایت</b> = عکس ماشین (همین تصاویر). ۲) <b>کد انیمیشن</b> = در گودو با AnimationPlayer و Tween
    این حالت‌ها (پلک، نگاه، بونس، جشن) روی اسپرایت اجرا می‌شود — همین‌هایی که در این صفحه می‌بینی، مستقیماً به گودو منتقل می‌شوند.<br>
    ۳) <b>دیالوگ</b> = فایل سناریو (JSON) + جعبه‌ی تایپ‌رایتر + صدای ضبط‌شده‌ی هر جمله.
    یعنی کاراکترها «حالت انیمیشن» دارند: idle / talk / blink / celebrate — و صدای هر جمله جدا ضبط و داخل BVAULT (کانتینر کدشده) گذاشته می‌شود.
  </div>
</div>

<script>
const BOGHI_IMG = document.getElementById('boghiCar');
const NISSAN_IMG = document.getElementById('nissanCar');
const banner = document.getElementById('banner');
const dbox = document.getElementById('dbox');
const dname = document.getElementById('dname');
const dtext = document.getElementById('dtext');
const VOICES = __VOICES__;
const LINES = __LINES__;
let sceneTimer = null, typeTimer = null, curAudio = null;

function setPos(el, css) { el.style.cssText += ";" + css; }

function playVoice(id) {
  if (curAudio) { curAudio.pause(); }
  curAudio = new Audio("data:audio/mpeg;base64," + VOICES[id]);
  curAudio.play();
  return curAudio;
}

function typeText(text, done) {
  clearInterval(typeTimer);
  dtext.innerHTML = "";
  let i = 0;
  typeTimer = setInterval(() => {
    i += 1;
    dtext.innerHTML = text.slice(0, i) + '<span class="caret">&nbsp;</span>';
    if (i >= text.length) { clearInterval(typeTimer); dtext.textContent = text; if (done) done(); }
  }, 34);
}

function setTalking(actor, on) {
  BOGHI_IMG.classList.toggle('talking', on && actor === 'boghi');
  NISSAN_IMG.classList.toggle('talking', on && actor === 'nissan');
}

async function playScene() {
  stopScene();
  // ورود ماشین‌ها
  BOGHI_IMG.style.right = '8%';
  NISSAN_IMG.style.left = '46%';
  await wait(1200);
  for (const L of LINES) {
    banner.style.opacity = 0;
    dbox.style.display = 'block';
    dname.textContent = L.who + (L.off ? ' (از بیرون صحنه)' : '');
    setTalking(L.actor, true);
    playVoice(L.id);
    await new Promise(res => typeText(L.text, res));
    // صبر تا پایان صدا یا حداکثر 4s اضافه
    const dur = curAudio ? Math.max(0, (curAudio.duration || 0) - 3) : 0;
    await wait(Math.min(4000, 600 + dur * 1000));
    setTalking(L.actor, false);
  }
  dbox.style.display = 'none';
  testParty();
}

function stopScene() {
  clearTimeout(sceneTimer); clearInterval(typeTimer);
  if (curAudio) { curAudio.pause(); curAudio = null; }
  dbox.style.display = 'none'; banner.style.opacity = 0;
  setTalking('boghi', false); setTalking('nissan', false);
  BOGHI_IMG.style.right = '-30%'; NISSAN_IMG.style.left = '-34%';
  if (curAudio) curAudio.pause();
}

function testBlink() {
  [BOGHI_IMG, NISSAN_IMG].forEach(c => {
    c.querySelectorAll('.lid').forEach(l => { l.style.animation = 'none'; l.style.transform = 'scaleY(1)';
      setTimeout(() => { l.style.transform = 'scaleY(0)'; l.style.animation = ''; }, 260); });
  });
}

function testParty() {
  const v = document.getElementById('partyView');
  spawnConfetti(v); spawnConfetti(document.getElementById('stage'));
  const img = BOGHI_IMG.querySelector('img');
  img.style.animation = 'party 1.9s ease-in-out 3';
}

function spawnConfetti(parent) {
  const colors = ['#ff5470','#ffd94a','#7ee0ff','#7dff8e','#c792ff'];
  for (let i = 0; i < 26; i++) {
    const c = document.createElement('div');
    c.className = 'conf';
    c.style.left = (3 + Math.random() * 94) + '%';
    c.style.background = colors[i % colors.length];
    c.style.animationDelay = (Math.random() * .9) + 's';
    parent.appendChild(c);
    setTimeout(() => c.remove(), 3600);
  }
}

function wait(ms) { return new Promise(r => sceneTimer = setTimeout(r, ms)); }

// لیست صداها
const vl = document.getElementById('voiceList');
LINES.forEach(L => {
  const row = document.createElement('div');
  row.className = 'vrow';
  row.innerHTML = `<button class="play" onclick="playVoice('${L.id}')">▶</button>
    <div class="who">${L.who}</div><div class="txt">${L.text}</div>`;
  vl.appendChild(row);
});
</script>
</body>
</html>"""

html = html.replace("__BOGHI__", BOGHI).replace("__NISSAN__", NISSAN)
html = html.replace("__VOICES__", VOICES_JSON).replace("__LINES__", LINES_JSON)

os.makedirs(os.path.dirname(OUT_HTML), exist_ok=True)
with open(OUT_HTML, "w", encoding="utf-8") as f:
    f.write(html)
print("HTML:", OUT_HTML, f"{os.path.getsize(OUT_HTML)/1024:.0f} KB")
