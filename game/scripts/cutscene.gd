extends Control
## StoryStage — استیج کات‌سین پروسیجرال «زندگی محله»
## هیچ ویدیو/فریمی وجود ندارد: خیابان از گرادیان + اسپرایت‌های موجود، حرکت‌ها Tween،
## دیالوگ با DialogueBox. سناریو از JSON اپیزود (پلین‌متکسِ دِو یا BVAULT ریلیز) خوانده می‌شود.

signal finished(episode_id: String)
signal mission_requested(episode: Dictionary)

const DIALOGUE_SCRIPT := preload("res://scripts/dialogue.gd")

const SKY_TOP := Color(0.32, 0.55, 0.78)
const SKY_BOTTOM := Color(0.88, 0.72, 0.52)
const GROUND := Color(0.22, 0.20, 0.19)
const SIDEWALK := Color(0.42, 0.40, 0.37)
const GROUND_Y := 0.78   # خط آسفالت (نسبت ارتفاع)
const CAR_H := 0.20      # ارتفاع ماشین (نسبت ارتفاع)

var episode: Dictionary = {}
var dialogue: Control
var _actors := {}       # id -> Dictionary{node, h, base_y}
var _tweens: Array = []
var _tap_wait := false
var _running := false

func setup(ep: Dictionary) -> void:
        episode = ep

func _ready() -> void:
        set_anchors_preset(Control.PRESET_FULL_RECT)
        layout_direction = Control.LAYOUT_DIRECTION_LTR
        _build_street()
        dialogue = DIALOGUE_SCRIPT.new()
        add_child(dialogue)
        dialogue.next_requested.connect(func(): _tap_wait = false)
        var tap_catcher := Button.new()
        tap_catcher.flat = true
        tap_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
        tap_catcher.modulate.a = 0.0
        tap_catcher.pressed.connect(_on_tap)
        add_child(tap_catcher)
        if not _running:
                _running = true
                _run.call_deferred()

func _build_street() -> void:
        var gt := GradientTexture2D.new()
        var g := Gradient.new()
        g.offsets = PackedFloat32Array([0.0, 1.0])
        g.colors = PackedColorArray([SKY_TOP, SKY_BOTTOM])
        gt.gradient = g
        gt.fill_from = Vector2(0, 0)
        gt.fill_to = Vector2(0, 1)
        var sky := TextureRect.new()
        sky.texture = gt
        sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        sky.set_anchors_preset(Control.PRESET_FULL_RECT)
        sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(sky)
        # دور شهر — همان اسپرایت‌های مسیر (هویت بصری مشترک)
        _layer("res://assets/sprites/bg_far.png", 0.30, 0.20, 0.52)
        _layer("res://assets/sprites/bg_mid.png", 0.52, 0.14, 0.40)
        # پیاده‌رو و آسفالت
        var walk := ColorRect.new()
        walk.color = SIDEWALK
        walk.anchor_left = 0.0
        walk.anchor_right = 1.0
        walk.anchor_top = GROUND_Y - 0.05
        walk.anchor_bottom = GROUND_Y
        walk.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(walk)
        var road := ColorRect.new()
        road.color = GROUND
        road.anchor_left = 0.0
        road.anchor_right = 1.0
        road.anchor_top = GROUND_Y
        road.anchor_bottom = 1.0
        road.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(road)
        var dash := ColorRect.new()
        dash.color = Color(0.85, 0.82, 0.75, 0.7)
        dash.anchor_left = 0.0
        dash.anchor_right = 1.0
        dash.anchor_top = GROUND_Y + 0.075
        dash.anchor_bottom = GROUND_Y + 0.083
        dash.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(dash)

func _layer(path: String, top: float, h: float, alpha: float) -> void:
        if not ResourceLoader.exists(path):
                return
        var tr := TextureRect.new()
        tr.texture = load(path)
        tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        tr.modulate.a = alpha
        tr.anchor_left = 0.0
        tr.anchor_right = 1.0
        tr.anchor_top = top
        tr.anchor_bottom = top + h
        tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(tr)

## اکتر: {"id","sprite","x"(0..1),"flip","scale"} — روی خط آسفالت می‌نشیند
func _actor(id: String) -> Dictionary:
        return _actors.get(id, {})

func _ensure_actor(a: Dictionary) -> Control:
        var id := str(a.get("id", ""))
        if _actors.has(id) and is_instance_valid(_actors[id]["node"]):
                return _actors[id]["node"]
        var tr := TextureRect.new()
        var tex_path := "res://assets/sprites/%s_side.png" % str(a.get("sprite", id))
        if ResourceLoader.exists(tex_path):
                tr.texture = load(tex_path)
        tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        tr.flip_h = bool(a.get("flip", false))
        tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var vw := get_viewport_rect().size
        var h := CAR_H * float(a.get("scale", 1.0)) * vw.y
        var w := h * 2.1 # نسبت تقریبی عرض/ارتفاع اسپرایت‌های side
        # چیدمان مستقیم (بدون انکر) — ضد مشکل RTL و ضدرزولوشن
        tr.anchor_left = 0.0
        tr.anchor_right = 0.0
        tr.anchor_top = 0.0
        tr.anchor_bottom = 0.0
        tr.size = Vector2(w, h)
        tr.position = Vector2(float(a.get("x", 0.5)) * vw.x - w * 0.5, GROUND_Y * vw.y - h + h * 0.10)
        add_child(tr)
        _actors[id] = {"node": tr, "h": h}
        return tr

func _place(node: Control, x01: float) -> void:
        var vw := get_viewport_rect().size
        node.position.x = x01 * vw.x - node.size.x * 0.5

func _tw() -> Tween:
        var t := create_tween()
        _tweens.append(t)
        return t

func _on_tap() -> void:
        if dialogue != null and dialogue.is_active():
                dialogue.tap()
        else:
                _tap_wait = false

func _banner(text: String) -> void:
        var l := Label.new()
        l.text = text
        var f := _font("res://assets/fonts/Lalezar-Regular.ttf")
        if f != null:
                l.add_theme_font_override("font", f)
        l.add_theme_font_size_override("font_size", 40)
        l.add_theme_color_override("font_color", Color(0.96, 0.76, 0.25))
        l.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03))
        l.add_theme_constant_override("outline_size", 10)
        l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        l.set_anchors_preset(Control.PRESET_TOP_WIDE)
        l.offset_top = 24
        l.offset_bottom = 84
        l.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(l)
        l.modulate.a = 0.0
        _tw().tween_property(l, "modulate:a", 1.0, 0.35)
        _tw().tween_interval(1.6)
        _tw().tween_property(l, "modulate:a", 0.0, 0.5)
        _tw().tween_callback(l.queue_free)

func _font(path: String) -> FontFile:
        if ResourceLoader.exists(path):
                var r := load(path)
                if r is FontFile:
                        return r
        return null

# ---------------- پخش بیت‌ها ----------------
func _run() -> void:
        var beats: Array = episode.get("beats", [])
        for b in beats:
                await _do_beat(b)
                while _tap_wait:
                        await get_tree().process_frame
                if not is_inside_tree():
                        return
        finished.emit(str(episode.get("id", "")))

func _do_beat(b: Dictionary) -> void:
        var act := str(b.get("do", ""))
        var vw := get_viewport_rect().size
        match act:
                "banner":
                        _banner(str(b.get("text", "")))
                        await get_tree().create_timer(0.6).timeout
                "enter":
                        var node: Control = _ensure_actor(b)
                        var side := str(b.get("side", "right"))
                        var target := float(b.get("x", 0.5))
                        var start_x := (1.25 if side == "right" else -0.25)
                        _place(node, start_x)
                        _tw().tween_property(node, "position:x", target * vw.x - node.size.x * 0.5, float(b.get("dur", 1.0)))\
                                .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
                        await get_tree().create_timer(float(b.get("dur", 1.0))).timeout
                "move":
                        var n2: Control = _actor(str(b.get("actor", "")))["node"] if _actors.has(str(b.get("actor", ""))) else null
                        if n2 != null:
                                _tw().tween_property(n2, "position:x", float(b.get("x", 0.5)) * vw.x - n2.size.x * 0.5, float(b.get("dur", 0.8)))\
                                        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
                                await get_tree().create_timer(float(b.get("dur", 0.8))).timeout
                "flip":
                        var n3: Control = _actor(str(b.get("actor", "")))["node"] if _actors.has(str(b.get("actor", ""))) else null
                        if n3 != null:
                                n3.flip_h = bool(b.get("flip", true))
                "bounce":
                        var rec4: Dictionary = _actor(str(b.get("actor", "")))
                        if rec4.has("node") and is_instance_valid(rec4["node"]):
                                var n4: Control = rec4["node"]
                                var y0 := n4.position.y
                                var amp := float(b.get("amp", 0.030)) * vw.y
                                var t := _tw()
                                for i in int(b.get("times", 2)):
                                        t.tween_property(n4, "position:y", y0 - amp, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
                                        t.tween_property(n4, "position:y", y0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
                                await t.finished
                "nod":
                        var rec5: Dictionary = _actor(str(b.get("actor", "")))
                        if rec5.has("node") and is_instance_valid(rec5["node"]):
                                var n5: Control = rec5["node"]
                                n5.pivot_offset = Vector2(n5.size.x * 0.5, n5.size.y)
                                var t5 := _tw()
                                for i in 2:
                                        t5.tween_property(n5, "rotation_degrees", 5.0, 0.12)
                                        t5.tween_property(n5, "rotation_degrees", -5.0, 0.12)
                                t5.tween_property(n5, "rotation_degrees", 0.0, 0.1)
                                await t5.finished
                "line":
                        var who := str(b.get("who", ""))
                        var anchor_id := str(b.get("actor", ""))
                        var d: Control = dialogue
                        d.show_line(who, str(b.get("text", "")), bool(b.get("offscreen", false)))
                        _tap_wait = true
                        while _tap_wait:
                                await get_tree().process_frame
                        await get_tree().create_timer(0.12).timeout
                        d.hide_line()
                "wait":
                        await get_tree().create_timer(float(b.get("dur", 0.5))).timeout
                "end":
                        pass
