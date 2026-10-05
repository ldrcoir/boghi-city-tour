extends Node
## Audio manager: SFX, music loop, engine loop

var sfx := {}
var music_player: AudioStreamPlayer
var engine_player: AudioStreamPlayer

func _ready() -> void:
        for n in ["horn", "coin", "jump", "boost", "crash", "win", "fail", "clank"]:
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
        # (اثر انگشت شنیداری v0.7: اگر این آهنگ شنیده شد یعنی بیلد درست نصب است)
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

func play_music() -> void:
        if not music_player.playing:
                music_player.play()

func stop_music() -> void:
        music_player.stop()

func play_sfx(name: String) -> void:
        if sfx.has(name):
                var p := AudioStreamPlayer.new()
                p.stream = sfx[name]
                p.volume_db = -2.0
                add_child(p)
                p.play()
                p.finished.connect(p.queue_free)

func set_engine(active: bool, intensity: float = 0.5) -> void:
        if active:
                if not engine_player.playing:
                        engine_player.play()
                engine_player.volume_db = lerp(-26.0, -10.0, clamp(intensity, 0.0, 1.0))
                engine_player.pitch_scale = 0.85 + 0.55 * clamp(intensity, 0.0, 1.0)
        else:
                engine_player.stop()
