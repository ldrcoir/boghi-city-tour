extends Node
## Audio manager v0.16 — موتور با دور موتور واقعی (گیربکس)، باد سرعت، کلیک UI
## SFX, music loop, engine loop, skid loop, wind loop

var sfx := {}
var music_player: AudioStreamPlayer
var engine_player: AudioStreamPlayer
var skid_player: AudioStreamPlayer
var wind_player: AudioStreamPlayer
var _ui_player: AudioStreamPlayer

func _ready() -> void:
        for n in ["horn", "coin", "jump", "boost", "crash", "win", "fail", "clank", "nitro", "lap", "beep", "shift", "ui", "done"]:
                var path := "res://assets/audio/%s.wav" % n
                if ResourceLoader.exists(path):
                        sfx[n] = load(path)
        music_player = AudioStreamPlayer.new()
        var mpath := "res://assets/audio/music_loop.ogg"
        if ResourceLoader.exists(mpath):
                music_player.stream = load(mpath)
                if music_player.stream is AudioStreamOggVorbis:
                        music_player.stream.loop = true
        music_player.volume_db = -9.0
        music_player.finished.connect(func(): music_player.play())
        add_child(music_player)
        # آهنگ بلافاصله از لحظه‌ی بوت شروع می‌شود — حتی قبل از منو
        if music_player.stream != null:
                music_player.play()
        engine_player = AudioStreamPlayer.new()
        engine_player.stream = load("res://assets/audio/engine.wav")
        # لوپ بی‌درز موتور — اگر یک‌بار مکث شنیده شود حس رباتیک می‌دهد
        var es := engine_player.stream as AudioStreamWAV
        if es != null:
                es.loop_mode = AudioStreamWAV.LOOP_FORWARD
                es.loop_begin = 0
                var bpf := 2 # ۱۶-بیت مونو
                if es.stereo:
                        bpf = 4
                es.loop_end = es.data.size() / bpf
        engine_player.volume_db = -60.0
        engine_player.finished.connect(func(): if engine_player.volume_db > -50.0: engine_player.play())
        add_child(engine_player)
        # لوپ جیغ لاستیک — دریفت واقعی صدای لاستیک می‌خواهد
        skid_player = AudioStreamPlayer.new()
        var spath := "res://assets/audio/skid.wav"
        if ResourceLoader.exists(spath):
                skid_player.stream = load(spath)
                var ss := skid_player.stream as AudioStreamWAV
                if ss != null:
                        ss.loop_mode = AudioStreamWAV.LOOP_FORWARD
                        ss.loop_begin = 0
                        var sbpf := 2
                        if ss.stereo:
                                sbpf = 4
                        ss.loop_end = ss.data.size() / sbpf
                skid_player.volume_db = -60.0
                skid_player.finished.connect(func(): if skid_player.volume_db > -50.0: skid_player.play())
                add_child(skid_player)
        # لوپ باد/غلتش جاده — با سرعت بلندتر می‌شود (فقط بلعیدن فایل اختیاری است)
        wind_player = AudioStreamPlayer.new()
        var wpath := "res://assets/audio/wind.wav"
        if ResourceLoader.exists(wpath):
                wind_player.stream = load(wpath)
                var ws := wind_player.stream as AudioStreamWAV
                if ws != null:
                        ws.loop_mode = AudioStreamWAV.LOOP_FORWARD
                        ws.loop_begin = 0
                        var wbpf := 2
                        if ws.stereo:
                                wbpf = 4
                        ws.loop_end = ws.data.size() / wbpf
                wind_player.volume_db = -60.0
                wind_player.finished.connect(func(): if wind_player.volume_db > -50.0: wind_player.play())
                add_child(wind_player)
        # کانال کلیک UI — همیشه آماده، بدون تاخیر
        _ui_player = AudioStreamPlayer.new()
        add_child(_ui_player)

func play_music() -> void:
        if not music_player.playing:
                music_player.play()

func stop_music() -> void:
        music_player.stop()

func play_sfx(name: String, vol_db: float = -2.0) -> void:
        if sfx.has(name):
                var p := AudioStreamPlayer.new()
                p.stream = sfx[name]
                p.volume_db = vol_db
                add_child(p)
                p.play()
                p.finished.connect(p.queue_free)

## کلیک منو — کوتاه و گرم؛ روی هر دکمه صدا زده می‌شود
func ui_click() -> void:
        if sfx.has("ui"):
                _ui_player.stream = sfx["ui"]
                _ui_player.volume_db = -8.0
                _ui_player.play()

func ui_done() -> void:
        play_sfx("done", -10.0)

## موتور با دور موتور واقعی — گیربکس در game.gd حساب می‌شود
## rpm: 0=درجا، 1=خط قرمز | throttle: 0=بی‌گاز، 1=گاز کامل
func set_engine_ex(active: bool, rpm: float, throttle: float = 1.0, nitro: bool = false) -> void:
        if not active:
                if engine_player.playing:
                        engine_player.stop()
                return
        if not engine_player.playing:
                engine_player.play()
        var r := clampf(rpm, 0.0, 1.0)
        var th := clampf(throttle, 0.0, 1.0)
        # پیتش: درجا بم (~۰٫۶۲) تا خط قرمز (~۱٫۶۲) + نیترو کمی بالاتر
        var pitch := 0.62 + r * 1.0 + (0.1 if nitro else 0.0)
        # لرزش درجا — موتور خامِ سرد
        if r < 0.22:
                pitch += sin(Time.get_ticks_msec() * 0.02) * 0.012
        engine_player.pitch_scale = pitch
        # بلندی: دور موتور غالب است، گاز مکمل
        var vol := clampf(0.18 + r * 0.72 + th * 0.18, 0.0, 1.0)
        engine_player.volume_db = lerp(-30.0, -7.5, vol)

## سازگاری با کدهای قدیمی (منو/توقف) — intensity به عنوان rpm تفسیر می‌شود
func set_engine(active: bool, intensity: float = 0.5) -> void:
        set_engine_ex(active, clampf(intensity, 0.0, 1.0), intensity)

func set_skid(active: bool, intensity: float = 0.6) -> void:
        if skid_player == null or skid_player.stream == null:
                return
        if active:
                if not skid_player.playing:
                        skid_player.play()
                skid_player.volume_db = lerp(-24.0, -6.0, clamp(intensity, 0.0, 1.0))
                skid_player.pitch_scale = 0.92 + 0.16 * clamp(intensity, 0.0, 1.0)
        else:
                skid_player.stop()

## باد و غلتش جاده — با سرعت؛ norm 0..1
func set_wind(norm: float) -> void:
        if wind_player == null or wind_player.stream == null:
                return
        var n := clampf(norm, 0.0, 1.0)
        if n <= 0.02:
                if wind_player.playing:
                        wind_player.stop()
                return
        if not wind_player.playing:
                wind_player.play()
        wind_player.volume_db = lerp(-34.0, -8.0, n * n)
        wind_player.pitch_scale = 0.85 + n * 0.5

func stop_driving_loops() -> void:
        set_engine(false)
        set_skid(false)
        set_wind(0.0)
