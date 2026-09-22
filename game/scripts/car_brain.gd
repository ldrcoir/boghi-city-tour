class_name CarBrain
extends Node
## مغز بوقی — موتور شخصیت محلی ماشین‌ها (کاملاً آفلاین، داخل خود بازی)
## هر ماشین شخصیت و صدای مخصوص خودش را دارد؛ صداها همان لحظه ساخته می‌شوند
## و حبابِ گفتار روی سر ماشین باز می‌شود. بوقی شیطونِ محله است و سیستم
## همیشه طرف او را می‌گیرد (بوست مخفی!).

const COL_BG := Color(0.99, 0.965, 0.88, 0.97)
const COL_LINE := Color(0.29, 0.216, 0.157)
const COL_TXT := Color(0.22, 0.14, 0.07)

# صدای هر ماشین: pitch=زیر و بمی، tone=جیغی/بمی بودن رگه صدا، rate=سرعت هجا
# صداها لاله‌زبانِ ماشین‌هاست — مثل انیمیشن‌های معروف ماشین‌ها هر کدام لهجه خودشان را دارند
const PERSONAS := {
        "boghi": {
                "nick": "بوقیِ شیطون",
                "voice": {"pitch": 330.0, "tone": 0.75, "rate": 11.0, "jit": 0.18},
                "lines": {
                        "idle": ["منو انتخاب کن! قول می‌دم بترکونیم!", "هی! یه مسابقه‌ی کوچولو داریم؟", "بوق بزن تا همه بدونن کی خوشگله‌!", "چهارچرخمو دیدی؟ براقه، نه؟"],
                        "select": ["آره! بالاخره فهمیدی من بهترینم!", "بوقی تو راهه، جا خالی کن!"],
                        "buy": [],
                        "poor": ["پول صرفه‌جویی کن، بعد بگو بوقی!"],
                        "upgrade": ["اوه! خفن‌تر از قبل شدم!"],
                        "go": ["برق پیش! بوقی تو راهه!"],
                        "nitro": ["بوووووق! آتیشه آتیشه!"],
                        "hit": ["اوخ! مواظب باش دیگه!", "ای! دوبومو زدی!"],
                        "win": ["به من می‌گن قهرمان محل!"],
                        "lose": ["اشکال نداره، بوقی که همیشه هست!"],
                        "boost": ["اینم هدیه‌ی بوقی! نیترو پر شد!", "سیستم با منه، نمی‌دونی؟! نیترو بزن!"],
                },
        },
        "boghi_yellow": {
                "nick": "بوقیِ آفتابی",
                "voice": {"pitch": 355.0, "tone": 0.65, "rate": 11.5, "jit": 0.16},
                "lines": {
                        "idle": ["آفتاب که می‌زنه، من راه می‌افتم!", "داداش بوقیم — ولی زردِ آفتاب‌خورده!", "زردم چون سریع‌ترینم!"],
                        "select": ["با آفتابِ محل رفاقت کن!", "یزرد! بریم که دنیا بچرخه!"],
                        "buy": ["خریدی منو؟ بهترین انتخاب عمرت!"],
                        "poor": ["یه ذره سکه جمع کن، می‌ترکونی!"],
                        "upgrade": ["حالا شدم خورشیدِ جاده!"],
                        "go": ["طلوع کردیم! بریم!"],
                        "nitro": ["آفتابِ داغ! کنار بکش!"],
                        "hit": ["اوخ! آفتابه رو خراشوندی!"],
                        "win": ["درخشیدم، نه؟!"],
                        "lose": ["فردا دوباره می‌تابم!"],
                },
        },
        "tiba": {
                "nick": "تیبای چابک",
                "voice": {"pitch": 440.0, "tone": 0.55, "rate": 13.0, "jit": 0.2},
                "lines": {
                        "idle": ["سبکم مثل پر کبوتر!", "پرش‌های دقیق کار منمه!", "یه دور بزنیم؟ من تمیز می‌پرم!"],
                        "select": ["تووووپ! تکون نمی‌خورم از دستت!"],
                        "buy": ["چسبیدی بهم؟ خوش اومدی!"],
                        "poor": ["آخ، سکه‌هات کمه!"],
                        "upgrade": ["نرم‌تر از قبل شدم!"],
                        "go": ["پرواز کن! نه، ببخشید، بریم!"],
                        "nitro": ["باد رفت رو من!"],
                        "hit": ["هیس! مواظب فرم باش!"],
                        "win": ["دقیق و خوشگل! مثل خودم!"],
                        "lose": ["دفعه بعد نرم‌تر می‌پرم!"],
                },
        },
        "pride": {
                "nick": "پرایدِ جیغ",
                "voice": {"pitch": 400.0, "tone": 0.85, "rate": 12.0, "jit": 0.22},
                "lines": {
                        "idle": ["استریک منو دیدی؟ مسابقه‌ایم من!", "جیغ بزن تا صدا بگیره!", "قرمزم چون آتیشم!"],
                        "select": ["بخیه بزن، الان می‌پروونمت!"],
                        "buy": ["برنده شدی که منو گرفتی!"],
                        "poor": ["من گرونم، ولی می‌ارزه!"],
                        "upgrade": ["الان صدای اگزوزم فرق داره!"],
                        "go": ["جیغوووو! رفتیم!"],
                        "nitro": ["هووووت! آتیشِ قرمز!"],
                        "hit": ["ای بابا! اسپویلرمو!"],
                        "win": ["گفتم که! مسابقه‌ایم!"],
                        "lose": ["جیغم دراومد به خاطر باخت!"],
                },
        },
        "pejo": {
                "nick": "پژوی فرمان‌رو",
                "voice": {"pitch": 330.0, "tone": 0.5, "rate": 10.0, "jit": 0.12},
                "lines": {
                        "idle": ["تعادل، رمز من است.", "نقره‌ایم چون کلاس دارم.", "فرمان دستمه، خیالت راحت."],
                        "select": ["انتخابِ یک حرفه‌ای.", "با من، خیابان مال توئه."],
                        "buy": ["سرمایه‌گذاری خوبی بود."],
                        "poor": ["من می‌ارزم، جمع کن سکه‌هات."],
                        "upgrade": ["حالا حرفه‌ایِ حرفه‌ای‌ها."],
                        "go": ["آرام، مطمئن، اول."],
                        "nitro": ["قدرتِ فرانسوی!"],
                        "hit": ["کلاسم اجازه نمی‌داد، ولی بگذریم."],
                        "win": ["همیشه اول، به جز دومی."],
                        "lose": ["حتی قهرمان‌ها هم می‌بازند."],
                },
        },
        "samand": {
                "nick": "سمندِ پیرِ خردمند",
                "voice": {"pitch": 200.0, "tone": 0.35, "rate": 7.0, "jit": 0.1},
                "lines": {
                        "idle": ["جوان‌مرد، من سال‌هاست این جاده‌ها را می‌بینم...", "محکم مثل کوه، آرام مثل باران.", "پشت من وایسا، هیچی اتفاق نمی‌افته."],
                        "select": ["پشت من وایسا پسرم، امن‌ترین جا دنیاست."],
                        "buy": ["خریدِ عاقلانه‌ای بود، آفرین."],
                        "poor": ["عجله نکن، سکه مثل رود جمع می‌شه."],
                        "upgrade": ["حتی پیرترها هم دوست دارن خفن باشن!"],
                        "go": ["بسم‌الله. آروم و مطمئن."],
                        "nitro": ["در جوانیم یادم رفت سرعت این‌قدر خوبه!"],
                        "hit": ["خس دیدم؟ کوله‌پشتم پاره نشه فقط!"],
                        "win": ["تجربه که باشد، پیروزی هم هست."],
                        "lose": ["جوانمردی این است که بلند شی دوباره."],
                },
        },
        "dena": {
                "nick": "دنای آرام",
                "voice": {"pitch": 255.0, "tone": 0.45, "rate": 9.0, "jit": 0.1},
                "lines": {
                        "idle": ["شکوه، آرامش، دنا.", "جاده‌های بزرگ به سدان بزرگ نیاز دارند.", "سفیدم چون صلح‌آمیزم."],
                        "select": ["تشریف بیارید جلو، سرنشینِ محترم!"],
                        "buy": ["انتخابی باوقار بود."],
                        "poor": ["من لیاقت سکه‌های بیشتری هستم."],
                        "upgrade": ["حالا باوقارتر از همیشه."],
                        "go": ["با اجازه‌ی همه، حرکت."],
                        "nitro": ["شکوهِ سرعت!"],
                        "hit": ["خب... مودبانه بگم: مواظب باشید!"],
                        "win": ["باوقارانه برنده شدم."],
                        "lose": ["منحنیِ زندگی، دوباره برمی‌گردد."],
                },
        },
        "nissan": {
                "nick": "نیسانِ آسفالت‌خور",
                "voice": {"pitch": 150.0, "tone": 0.9, "rate": 6.5, "jit": 0.08},
                "lines": {
                        "idle": ["هوم. من وانت نیسانم. بارِ سنگین؟ بازیچه.", "قرمزم چون آجر قرمز، مثل من سخت.", "سرعتم کمه؟ کل لودری رو زمین دارم."],
                        "select": ["سوار شو. لرزیدی؟ عادیه."],
                        "buy": ["هوم. خرید خوبی بود."],
                        "poor": ["سکه بیار. بعد بیا."],
                        "upgrade": ["هوم. حالا محکم‌ترم."],
                        "go": ["رفتیم. سکوت کن، کار دارم."],
                        "nitro": ["هوووم. غرشِ وانت!"],
                        "hit": ["گلگیرم خراش برد... خیالت راحت."],
                        "win": ["هوم. طبیعتاً."],
                        "lose": ["مانع بود. قضیه همین بود."],
                },
        },
        "pejo_race": {
                "nick": "پژوی پیست",
                "voice": {"pitch": 385.0, "tone": 0.8, "rate": 12.5, "jit": 0.2},
                "lines": {
                        "idle": ["قرمز آتشین با استریک سفید — عاشق پیستم!", "کلاچ و گاز، کل زندگی من!", "پیست خونه‌ی دوممه!"],
                        "select": ["ایول! حالا یه مسابقه واقعیه!"],
                        "buy": ["به تیم مسابقه خوش اومدی!"],
                        "poor": ["پیست منتظر می‌مونه... ولی من نه!"],
                        "upgrade": ["حالا تایپ R شدم!"],
                        "go": ["چراغ سبز! گاز تا ته!"],
                        "nitro": ["فول بوست! هیسسسس!"],
                        "hit": ["رینگم! رینگ مسابقه‌ایم!"],
                        "win": ["جایزه اول، روی سکو!"],
                        "lose": ["پیست یادمه... انتقام می‌گیرم!"],
                },
        },
        "shahin": {
                "nick": "شاهینِ شب",
                "voice": {"pitch": 225.0, "tone": 0.7, "rate": 8.5, "jit": 0.12},
                "lines": {
                        "idle": ["شب که بشه، خیابون مال منه.", "مشکیِ طلایی‌خط — شاهِ شب‌های تهران.", "صدای منو شنیدی؟ اون بود که چراغا رو جا گذاشت."],
                        "select": ["خوبه. شب امشب جالبه."],
                        "buy": ["سلیقه داری. قبول شد."],
                        "poor": ["من طلایی‌خطتم، قیمت هم دارم."],
                        "upgrade": ["حالا شبا ترکش خوردن از من."],
                        "go": ["چراغا خاموش... شروع شد."],
                        "nitro": ["شبِ تندِ بی‌رحم!"],
                        "hit": ["خط طلاییمو دیدی؟ دست نزن بهش."],
                        "win": ["معلوم بود. شاه همیشه می‌بره."],
                        "lose": ["شب هنوز تموم نشده..."],
                },
        },
        "quick": {
                "nick": "کوییکِ جیغ‌جوان",
                "voice": {"pitch": 470.0, "tone": 0.75, "rate": 14.0, "jit": 0.25},
                "lines": {
                        "idle": ["نارنجیم! جیغ‌ترین رنگِ دنیا!", "پرش‌های بلند؟ تخصص منم!", "آخیش! بالاخره گشادمت!"],
                        "select": ["یِیِس! بزن بریم هوووا!"],
                        "buy": ["خریدی منو؟ بهترین کار زندگیت!"],
                        "poor": ["وایسا وایسا، سکه بیار بعد بیا!"],
                        "upgrade": ["حالا از تو خودم سریع‌ترم!"],
                        "go": ["سریع‌ سریع‌ سریع‌! رفتیم!"],
                        "nitro": ["وووووووووووووووو!"],
                        "hit": ["اووخ! لاستیلام!"],
                        "win": ["معلومه که بردم! سریع بودم!"],
                        "lose": ["دفعه بعد، سریع‌ترِ سریع‌تر!"],
                },
        },
        "dena_race": {
                "nick": "دنای قهرمان",
                "voice": {"pitch": 270.0, "tone": 0.65, "rate": 9.5, "jit": 0.14},
                "lines": {
                        "idle": ["سدانِ ملی با لباس استریک — غرورِ پیست!", "قهرمان‌ها آرام حرف می‌زنند، سریع می‌روند.", "سکو؟ خونه‌ی دوممه."],
                        "select": ["با من، فقط جای اول."],
                        "buy": ["به تیم قهرمان‌ها خوش آمدی."],
                        "poor": ["غرور من گرون‌تر از این حرفاست."],
                        "upgrade": ["حالا قهرمانِ قهرمان‌ها."],
                        "go": ["با اجازه‌ی سکو، حرکت!"],
                        "nitro": ["غرورِ ملی، سرعتِ جهانی!"],
                        "hit": ["استریکم! آخ، استریکم!"],
                        "win": ["طلای دیگر به کارنامه‌ام اضافه شد."],
                        "lose": ["قهرمان واقعی از باخت درس می‌گیرد."],
                },
        },
        "ustad": {
                "nick": "استاد فنر",
                "voice": {"pitch": 210.0, "tone": 0.5, "rate": 8.0, "jit": 0.12},
                "lines": {
                        "idle": ["بیا بیا! ماشینت رو به من بسپار!", "آچار شماره‌ی چهارده کو؟!", "کارِ استاد که تمیزه دیگه!", "سیبیلَم رو بوس بزن، کارتم تمومه!"],
                        "upgrade": ["هیس... الان صدای موتور رو ببین!"],
                        "buy": ["انتخابِ خوبی بود جوانمرد!"],
                        "hit": ["دوباره تصادف؟ بیا ببینم..."],
                },
        },
}

const MOODS := {
        "idle": "chill", "select": "happy", "buy": "happy", "poor": "grumpy",
        "upgrade": "happy", "go": "happy", "nitro": "happy", "hit": "grumpy",
        "win": "happy", "lose": "chill", "boost": "happy",
}

static var _last_idle := {}
static var _srg := RandomNumberGenerator.new()

var bubble: Control = null
var voice_player: AudioStreamPlayer = null
var _rng := RandomNumberGenerator.new()
var _car_idx := 0

func _ready() -> void:
        _rng.randomize()
        voice_player = AudioStreamPlayer.new()
        voice_player.volume_db = -2.0
        add_child(voice_player)

## خطِ تصادفی برای ماشین و موقعیت — بدون تکرار پشت سر هم تا می‌شود
static func pick_line(car_id: String, ctx: String) -> String:
        if not PERSONAS.has(car_id):
                return ""
        var pool: Array = PERSONAS[car_id]["lines"].get(ctx, [])
        if pool.is_empty():
                return ""
        var key := car_id + ":" + ctx
        var last: int = int(_last_idle.get(key, -1))
        var i := _srg.randi_range(0, pool.size() - 1)
        if pool.size() > 1 and i == last:
                i = (i + 1) % pool.size()
        _last_idle[key] = i
        return str(pool[i])

## سکوت همیشگی نیست — ماشین‌ها هر از چندی خودشان حرف می‌زنند
func start_idle_chatter(anchor_getter: Callable, car_ids_getter: Callable, min_wait := 7.0, max_wait := 13.0) -> void:
        var t := Timer.new()
        t.wait_time = _rng.randf_range(min_wait, max_wait)
        t.one_shot = false
        t.timeout.connect(func():
                var ids: Array = car_ids_getter.call()
                if ids.is_empty():
                        return
                var cid: String = ids[_rng.randi_range(0, ids.size() - 1)]
                var anchor: Control = anchor_getter.call(cid)
                if anchor != null and anchor.is_visible_in_tree():
                        say(anchor, cid, "idle")
                t.wait_time = _rng.randf_range(min_wait, max_wait))
        add_child(t)
        t.start()

## حبابِ گفتار باز می‌شود + صدای لاله‌زبانِ همان ماشین پخش می‌شود
func say(anchor: Control, car_id: String, ctx: String) -> void:
        if not PERSONAS.has(car_id):
                return
        var line := pick_line(car_id, ctx)
        if line.is_empty():
                return
        for i in Globals.CARS.size():
                if str(Globals.CARS[i]["id"]) == car_id:
                        _car_idx = i
                        break
        _show_bubble(anchor, line)
        _speak(line, car_id, str(MOODS.get(ctx, "chill")))
        CarBrain.wobble(anchor)

func _show_bubble(anchor: Control, text: String) -> void:
        if bubble != null:
                bubble.queue_free()
                bubble = null
        var b := Bubble.new()
        b.brain = self
        b.set_text(text)
        var bfont: Resource = load("res://assets/fonts/Lalezar-Regular.ttf")
        if bfont is FontFile:
                b.add_theme_font_override("font", bfont)
        var top := anchor.global_position
        var w := maxf(190.0, minf(400.0, text.length() * 13.0 + 70.0))
        b.size = Vector2(w, 0)
        var px := top.x + anchor.size.x * 0.5 - w * 0.5
        px = clampf(px, 12.0, 1280.0 - w - 12.0)
        var py := top.y - 86.0
        if py < 8.0:
                py = top.y + anchor.size.y + 10.0
        b.position = Vector2(px, py)
        b.z_index = 60
        var parent_node := anchor.get_parent()
        if parent_node == null:
                parent_node = self
        parent_node.add_child(b)
        bubble = b

## صدای لاله‌زبان — یک جمله‌ی بی‌کلامِ آهنگین که شخصیتِ ماشین را می‌سازد
func _speak(text: String, car_id: String, mood: String) -> void:
        var v: Dictionary = PERSONAS[car_id]["voice"] if PERSONAS.has(car_id) else {"pitch": 300.0, "tone": 0.5, "rate": 10.0, "jit": 0.15}
        var pitch := float(v["pitch"])
        var tone := float(v["tone"])
        var rate := float(v["rate"])
        var jit := float(v["jit"])
        var syl_dur := 1.0 / rate
        var dur := clampf(0.25 + text.length() * 0.045, 0.45, 2.4)
        var syls := int(ceil(dur / syl_dur))
        var sr := 22050
        var n := int(dur * sr)
        var data := PackedByteArray()
        data.resize(n * 2)
        var phase := 0.0
        for k in syls:
                var syl_pitch := pitch * (1.0 + _rng.randf_range(-jit, jit))
                if mood == "happy":
                        syl_pitch *= 1.0 + 0.06 * float(k) / float(syls) # آهنگین رو به بالا
                elif mood == "grumpy":
                        syl_pitch *= 1.0 - 0.05 * float(k) / float(syls)
                var step := 2.0 * PI * syl_pitch / float(sr)
                var s0 := int(float(k) * syl_dur * sr)
                var s1: int = min(n, int(float(k + 1) * syl_dur * sr) - int(sr * 0.02))
                for i in range(s0, s1):
                        var tt := float(i - s0) / float(sr)
                        var in_syl := float(i - s0) / float(syl_dur * sr)
                        var env := pow(maxf(0.0, sin(PI * clampf(in_syl, 0.0, 1.0))), 0.65)
                        if tt < 0.01 or tt > syl_dur - 0.03:
                                env = 0.0
                        var s := sin(phase)
                        var sq := signf(s)
                        var wob := 1.0 + 0.02 * sin(2.0 * PI * 6.0 * tt)
                        var amp := env * 0.34 * wob
                        var val := (1.0 - tone) * s + tone * sq
                        var iv := int(clampf(val * amp, -1.0, 1.0) * 32767.0)
                        data.encode_s16(i * 2, iv)
                        phase += step
        var wav := AudioStreamWAV.new()
        wav.format = AudioStreamWAV.FORMAT_16_BITS
        wav.mix_rate = sr
        wav.stereo = false
        wav.data = data
        voice_player.stream = wav
        voice_player.pitch_scale = 1.0
        voice_player.play()

## نفس‌کشیدن دائمی ماشین‌ها — حس زنده بودن مثل انیمیشن‌های معروف
static func add_breathing(ctrl: Control, amp := 3.5, dur := 1.3) -> void:
        var base := ctrl.position.y
        var t := ctrl.create_tween().set_loops()
        t.tween_property(ctrl, "position:y", base - amp, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        t.tween_property(ctrl, "position:y", base + amp * 0.4, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## جست‌وخیزِ لحظه‌ی حرف زدن — با مقیاس و چرخش تا با تنفسِ دائمی تداخل نکند
static func wobble(ctrl: Control) -> void:
        if ctrl == null or not is_instance_valid(ctrl):
                return
        var t := ctrl.create_tween()
        t.tween_property(ctrl, "rotation_degrees", 2.2, 0.09).set_trans(Tween.TRANS_SINE)
        t.parallel().tween_property(ctrl, "scale", ctrl.scale * Vector2(1.03, 1.07), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        t.tween_property(ctrl, "rotation_degrees", -1.6, 0.12).set_trans(Tween.TRANS_SINE)
        t.tween_property(ctrl, "rotation_degrees", 0.0, 0.1)
        t.parallel().tween_property(ctrl, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

## حبابِ گفتار — پنل کرم با دنباله، متن با افکت تایپ
class Bubble extends Control:
        var lbl: Label
        var brain: CarBrain
        var _t := 0.0
        var _total := 0.0
        var _hold := 0.0

        func set_text(text: String) -> void:
                var sb := StyleBoxFlat.new()
                sb.bg_color = Color(0.99, 0.965, 0.88, 0.97)
                sb.set_corner_radius_all(16)
                sb.border_color = Color(0.29, 0.216, 0.157)
                sb.border_width_left = 3
                sb.border_width_right = 3
                sb.border_width_top = 3
                sb.border_width_bottom = 3
                sb.shadow_color = Color(0, 0, 0, 0.3)
                sb.shadow_size = 6
                var panel := PanelContainer.new()
                panel.add_theme_stylebox_override("panel", sb)
                panel.set_anchors_preset(Control.PRESET_FULL_RECT)
                lbl = Label.new()
                lbl.text = text
                lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
                lbl.add_theme_font_size_override("font_size", 24)
                lbl.add_theme_color_override("font_color", Color(0.22, 0.14, 0.07))
                var m := MarginContainer.new()
                m.add_theme_constant_override("margin_left", 16)
                m.add_theme_constant_override("margin_right", 16)
                m.add_theme_constant_override("margin_top", 10)
                m.add_theme_constant_override("margin_bottom", 14)
                m.add_child(lbl)
                panel.add_child(m)
                add_child(panel)
                lbl.visible_characters = 0
                _total = float(text.length())
                _hold = _total * 0.055 + 1.3

        func _ready() -> void:
                mouse_filter = Control.MOUSE_FILTER_IGNORE
                scale = Vector2(0.2, 0.2)
                var t := create_tween()
                t.tween_property(self, "scale", Vector2(1, 1), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

        func _process(delta: float) -> void:
                _t += delta
                if lbl != null and _t < _total * 0.055:
                        lbl.visible_characters = int(_t / 0.055) + 1
                if _t > _hold:
                        modulate.a -= delta * 2.5
                        position.y -= delta * 14.0
                        if modulate.a <= 0.0:
                                queue_free()
