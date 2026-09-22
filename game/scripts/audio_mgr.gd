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
        engine_player = AudioStreamPlayer.new()
        engine_player.stream = load("res://assets/audio/engine.wav")
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
                p.volume_db = -4.0
                add_child(p)
                p.play()
                p.finished.connect(p.queue_free)

func set_engine(active: bool, intensity: float = 0.5) -> void:
        if active:
                if not engine_player.playing:
                        engine_player.play()
                engine_player.volume_db = lerp(-34.0, -16.0, clamp(intensity, 0.0, 1.0))
                engine_player.pitch_scale = 0.85 + 0.55 * clamp(intensity, 0.0, 1.0)
        else:
                engine_player.stop()
