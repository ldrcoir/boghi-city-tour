extends Node2D
## Boghi gameplay: side-view auto-runner with jobs, coins, ramps, turbo

const VIEW_W := 1280.0
const VIEW_H := 720.0
const GROUND_Y := 600.0
const CAR_X := 300.0
const GRAVITY := 2300.0

var lv: Dictionary
var speed_base := 150.0
var world_x := 0.0
var finish_px := 6000.0
var time_left := 60.0
var coins_got := 0
var target_coins := -1
var passengers := 0
var target_passengers := -1
var car_y := 0.0
var vy := 0.0
var on_ground := true
var speed_mult := 1.0
var slow_until := 0.0
var turbo_left := 0.0
var turbo_meter := 1.0
var invuln_until := 0.0
var elapsed := 0.0
var ended := false
var autotest := false
var next_obj_x := 900.0
var passenger_spots: Array = []
var next_passenger_idx := 0
var shake := 0.0
var _auto_timer := 0.0
var _shot_taken := false
var brain = null

# بارگذاری مستقیم مغز — بدون وابستگی به class cache
const BRAIN_SCRIPT := preload("res://scripts/car_brain.gd")
var car_anchor: Control
var _hit_chat_until := 0.0
var _boost_in := 0.0

var world: Node2D
var layers: Array = []  # painterly parallax: {s1, s2, w, f}
var car: Area2D
var car_sprite: Sprite2D
var shadow: Sprite2D
var plate_label: Label
var cam: Camera2D
var hud: CanvasLayer
var coin_label: Label
var time_label: Label
var mission_label: Label
var extra_label: Label
var progress: ProgressBar
var boost_btn: Button
var nitro_bar: ProgressBar
var flame: CPUParticles2D
var dust: CPUParticles2D
var lines: Control
var end_panel: PanelContainer
var end_title: Label
var end_stars: Label
var end_reward: Label

func _ready() -> void:
        autotest = OS.get_cmdline_user_args().has("--autotest")
        var lid: int = Globals.get_meta("start_level", 1)
        lv = Globals.get_level(lid)
        if lv.is_empty():
                lv = {"id": 1, "type": "race", "name": "تست", "speed": 14.0, "distance": 500,
                        "time": 90, "obstacle_rate": 0.4, "coin_rate": 0.8, "ramp_rate": 0.3, "reward": 50}
        var stats: Dictionary = Globals.car_stats()
        speed_base = float(lv["speed"]) * 10.0 * float(stats["accel"])
        finish_px = float(lv["distance"]) * 10.0
        time_left = float(lv["time"])
        if lv["type"] == "collect":
                target_coins = int(lv.get("target_coins", 10))
        if lv["type"] == "taxi":
                target_passengers = int(lv.get("target_passengers", 3))
                for i in target_passengers + 1:
                        passenger_spots.append(finish_px * (0.18 + 0.68 * (float(i) / (target_passengers + 1.0))))
        next_obj_x = 700.0
        _build_world()
        _build_car(stats)
        _build_hud()
        AudioMgr.play_music()
        # مغز بوقی: ماشینِ تو همین اول مسابقه گاز می‌زند!
        brain = BRAIN_SCRIPT.new()
        add_child(brain)
        car_anchor = Control.new()
        car_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
        car_anchor.size = Vector2(0, 0)
        hud.add_child(car_anchor)
        _boost_in = 13.0 + randf() * 6.0
        get_tree().create_timer(0.7).timeout.connect(func():
                if brain != null and not ended and car_anchor != null:
                        brain.say(car_anchor, str(Globals.CARS[Globals.selected_car]["id"]), "go"))
        mission_label.text = Globals.L("mission") + " " + str(int(lv["id"])) + ": " + str(lv["name"]) + " — " + Globals.L("type_" + str(lv["type"]))
        if autotest:
                time_left = 999
                _auto_timer = 0.0

func _build_world() -> void:
        var backdrop := ColorRect.new()
        backdrop.color = Color(0.09, 0.07, 0.11) # پس‌زمینه تیره گرم — نسل ۲
        backdrop.size = Vector2(VIEW_W, VIEW_H)
        backdrop.z_index = -14
        add_child(backdrop)

        # painterly parallax: far city (opaque) -> buildings band -> road
        _add_layer("res://assets/sprites/bg_far.png", -12, GROUND_Y + 50.0, 1.286, 0.18)
        _add_layer("res://assets/sprites/bg_mid.png", -10, GROUND_Y + 30.0, 1.286, 0.45, 0.75)
        _add_layer("res://assets/sprites/road_strip.png", -4, VIEW_H, 1.286, 1.0, 0.54)

        world = Node2D.new()
        world.z_index = 2
        add_child(world)

        cam = Camera2D.new()
        cam.position = Vector2(VIEW_W / 2, VIEW_H / 2)
        add_child(cam)
        cam.make_current()

func _add_layer(path: String, z: int, bottom_y: float, scale: float, factor: float, squash: float = 0.0) -> void:
        var tex: Texture2D = load(path)
        var sc := Vector2(scale, scale if squash <= 0.0 else squash)
        var s1 := Sprite2D.new()
        s1.texture = tex
        s1.centered = false
        s1.z_index = z
        s1.scale = sc
        s1.position = Vector2(0.0, bottom_y - tex.get_height() * sc.y)
        add_child(s1)
        var s2 := s1.duplicate() as Sprite2D
        s2.flip_h = true
        s2.position = s1.position + Vector2(tex.get_width() * scale, 0.0)
        add_child(s2)
        layers.append({"s1": s1, "s2": s2, "w": tex.get_width() * scale, "f": factor})

func _build_car(stats: Dictionary) -> void:
        car = Area2D.new()
        car.position = Vector2(CAR_X, GROUND_Y)
        car.monitoring = true
        var shape := CollisionShape2D.new()
        var rect := RectangleShape2D.new()
        rect.size = Vector2(235, 160)
        shape.shape = rect
        shape.position = Vector2(0, -78)
        car.add_child(shape)
        car.area_entered.connect(_on_hit)
        car_sprite = Sprite2D.new()
        # در مسابقه چهره جدی (بدون چشم، شیشه دودی) — طبق بریف نوجوان‌پسند کاربر
        var cdef: Dictionary = Globals.CARS[Globals.selected_car]
        var race_path: String = "res://assets/sprites/" + str(cdef["id"]) + "_race.png"
        car_sprite.texture = load(race_path) if ResourceLoader.exists(race_path) else load(str(cdef["tex"]))
        var sc := 214.0 / float(car_sprite.texture.get_height()) # ارتفاع ثابت ~۲۱۴px برای هر ابعاد اسپرایت
        car_sprite.scale = Vector2(sc, sc)
        var th := car_sprite.texture.get_height() * sc
        car_sprite.position = Vector2(0, 12.0 - th * 0.5) # چرخ‌ها روی جاده
        shadow = Sprite2D.new()
        shadow.texture = _make_shadow_tex()
        shadow.position = Vector2(CAR_X, GROUND_Y - 6)
        shadow.z_index = -2
        add_child(shadow)
        car.add_child(car_sprite)
        var plate := Panel.new()
        var sb := _sb(Color(0.99, 0.965, 0.9), Color(0.29, 0.216, 0.157), 10, 4)
        plate.add_theme_stylebox_override("panel", sb)
        plate.custom_minimum_size = Vector2(160, 44)
        plate.position = Vector2(-80, -240)
        plate.size = Vector2(160, 44)
        plate_label = Label.new()
        plate_label.text = Globals.plate_name
        plate_label.add_theme_font_override("font", load("res://assets/fonts/Lalezar-Regular.ttf"))
        plate_label.add_theme_font_size_override("font_size", 24)
        plate_label.add_theme_color_override("font_color", Color(0.25, 0.16, 0.09))
        plate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        plate_label.set_anchors_preset(Control.PRESET_FULL_RECT)
        plate.add_child(plate_label)
        car.add_child(plate)
        _attach_car_fx()
        add_child(car)

func _attach_car_fx() -> void:
        # نیترو: شعلهٔ آتشین پشت اگزوز
        flame = CPUParticles2D.new()
        flame.position = Vector2(-125, -32)
        flame.emitting = false
        flame.amount = 80
        flame.lifetime = 0.32
        flame.direction = Vector2(-1, 0)
        flame.spread = 14.0
        flame.gravity = Vector2(-280, -50)
        flame.initial_velocity_min = 380.0
        flame.initial_velocity_max = 660.0
        flame.scale_amount_min = 9.0
        flame.scale_amount_max = 16.0
        var curve := Curve.new()
        curve.add_point(Vector2(0, 1.0))
        curve.add_point(Vector2(1, 0.1))
        flame.scale_amount_curve = curve
        var grad := Gradient.new()
        grad.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
        grad.colors = PackedColorArray([Color(1.0, 0.97, 0.55, 0.95),
                Color(1.0, 0.55, 0.08, 0.85), Color(0.85, 0.12, 0.02, 0.0)])
        flame.color_ramp = grad
        var mat := CanvasItemMaterial.new()
        mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
        flame.material = mat
        flame.z_index = -1
        car.add_child(flame)
        # گردوخاک چرخ‌ها روی جاده
        dust = CPUParticles2D.new()
        dust.position = Vector2(-100, -10)
        dust.emitting = false
        dust.amount = 26
        dust.lifetime = 0.7
        dust.direction = Vector2(-1, 0)
        dust.spread = 30.0
        dust.gravity = Vector2(0, -40)
        dust.initial_velocity_min = 60.0
        dust.initial_velocity_max = 150.0
        dust.scale_amount_min = 4.0
        dust.scale_amount_max = 8.0
        var dg := Gradient.new()
        dg.offsets = PackedFloat32Array([0.0, 1.0])
        dg.colors = PackedColorArray([Color(0.62, 0.5, 0.36, 0.5), Color(0.62, 0.5, 0.36, 0.0)])
        dust.color_ramp = dg
        dust.z_index = -1
        car.add_child(dust)

func _build_hud() -> void:
        hud = CanvasLayer.new()
        hud.process_mode = Node.PROCESS_MODE_ALWAYS
        add_child(hud)
        var font: FontFile = load("res://assets/fonts/Lalezar-Regular.ttf") # فانتزی برای HUD

        coin_label = _hud_label(font, 34, Vector2(1040, 16), Color(0.95, 0.75, 0.1))
        time_label = _hud_label(font, 34, Vector2(24, 16), Color(0.95, 0.35, 0.25))
        extra_label = _hud_label(font, 28, Vector2(24, 60), Color(0.98, 0.98, 0.98))
        mission_label = _hud_label(font, 34, Vector2(0, 16), Color(0.98, 0.98, 0.98))
        mission_label.custom_minimum_size = Vector2(VIEW_W, 0)
        mission_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

        # ⛔ HUD لنگر-محور — روی هر عرض صفحه (1280 دسکتاپ تا 1600 گوشی) سر جایش می‌ماند
        # و همه‌چیز زیر خط امن استاتوس‌بار (۴۶px) شروع می‌شود (درس اسکرین‌شات v0.9)
        _place(coin_label, 1.0, 0.0, 1.0, 0.0, -250, 46, -60, 92)
        _place(time_label, 0.0, 0.0, 0.0, 0.0, 24, 46, 300, 92)
        _place(extra_label, 0.0, 0.0, 0.0, 0.0, 24, 98, 760, 138)
        _place(mission_label, 0.0, 0.0, 1.0, 0.0, 0, 46, 0, 94)

        progress = ProgressBar.new()
        progress.min_value = 0
        progress.max_value = 100
        progress.value = 0
        progress.show_percentage = false
        var pbg := _sb(Color(0.99, 0.965, 0.9), Color(0.29, 0.216, 0.157), 10, 3)
        var pfill := _sb(Color(0.957, 0.769, 0.188), Color(0.72, 0.52, 0.1), 8, 0, false)
        progress.add_theme_stylebox_override("background", pbg)
        progress.add_theme_stylebox_override("fill", pfill)
        hud.add_child(progress)
        _place(progress, 0.5, 0.0, 0.5, 0.0, -250, 100, 250, 122)

        var pause_btn := Button.new()
        pause_btn.text = "II"
        _style_btn(pause_btn, false)
        hud.add_child(pause_btn)
        _place(pause_btn, 1.0, 0.0, 1.0, 0.0, -64, 46, -12, 98)

        var jump_btn := Button.new()
        jump_btn.text = Globals.L("jump")
        jump_btn.add_theme_font_override("font", font)
        jump_btn.add_theme_font_size_override("font_size", 34)
        _style_btn(jump_btn, true)
        hud.add_child(jump_btn)
        _place(jump_btn, 1.0, 1.0, 1.0, 1.0, -220, -130, -30, -30)

        boost_btn = Button.new()
        boost_btn.text = Globals.L("nitro")
        boost_btn.add_theme_font_override("font", font)
        boost_btn.add_theme_font_size_override("font_size", 30)
        _style_btn(boost_btn, true)
        hud.add_child(boost_btn)
        _place(boost_btn, 1.0, 1.0, 1.0, 1.0, -420, -130, -230, -30)

        # گیج نیترو بالای دکمه
        nitro_bar = ProgressBar.new()
        nitro_bar.min_value = 0
        nitro_bar.max_value = 100
        nitro_bar.value = 100
        nitro_bar.show_percentage = false
        var nbg := _sb(Color(0.12, 0.1, 0.14), Color(0.29, 0.216, 0.157), 8, 2, false)
        var nfill := _sb(Color(1.0, 0.55, 0.08), Color(0.9, 0.3, 0.05), 8, 0, false)
        nitro_bar.add_theme_stylebox_override("background", nbg)
        nitro_bar.add_theme_stylebox_override("fill", nfill)
        hud.add_child(nitro_bar)
        _place(nitro_bar, 1.0, 1.0, 1.0, 1.0, -420, -154, -230, -138)

        # خطوط سرعت هنگام نیترو
        lines = SpeedLines.new()
        lines.position = Vector2.ZERO
        lines.size = Vector2(VIEW_W, VIEW_H)
        lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
        lines.visible = false
        hud.add_child(lines)

func _hud_label(font: FontFile, size: int, pos: Vector2, col: Color) -> Label:
        var l := Label.new()
        l.add_theme_font_override("font", font)
        l.add_theme_font_size_override("font_size", size)
        l.add_theme_color_override("font_color", col)
        l.add_theme_color_override("font_outline_color", Color(0.25, 0.16, 0.09))
        l.add_theme_constant_override("outline_size", 10)
        l.position = pos
        l.text = ""
        hud.add_child(l)
        return l

## لنگرگذاری دقیق یک Control (به‌جای position/size ثابت)
func _place(c: Control, al: float, at: float, ar: float, ab: float, ol: float, ot: float, orr: float, ob: float) -> void:
        c.anchor_left = al
        c.anchor_top = at
        c.anchor_right = ar
        c.anchor_bottom = ab
        c.offset_left = ol
        c.offset_top = ot
        c.offset_right = orr
        c.offset_bottom = ob

func _sb(bg: Color, border: Color, radius: int, bw: int = 0, shadow := true) -> StyleBoxFlat:
        var sb := StyleBoxFlat.new()
        sb.bg_color = bg
        sb.set_corner_radius_all(radius)
        sb.border_color = border
        sb.border_width_left = bw
        sb.border_width_right = bw
        sb.border_width_top = bw
        sb.border_width_bottom = bw + (4 if bw > 0 else 0)
        if shadow:
                sb.shadow_color = Color(0.25, 0.16, 0.09, 0.28)
                sb.shadow_size = 6
        return sb

func _style_btn(b: Button, primary := true) -> void:
        var base := Color(0.165, 0.616, 0.561) if primary else Color(0.965, 0.886, 0.737)
        var dark := Color(0.11, 0.42, 0.385) if primary else Color(0.8, 0.66, 0.42)
        b.add_theme_stylebox_override("normal", _sb(base, dark, 18, 3))
        b.add_theme_stylebox_override("hover", _sb(base.lightened(0.07), dark, 18, 3))
        b.add_theme_stylebox_override("pressed", _sb(dark, dark, 18, 3))
        b.add_theme_stylebox_override("disabled", _sb(Color(0.87, 0.84, 0.78), Color(0.72, 0.66, 0.56), 18, 3))
        var fg := Color(1, 1, 1) if primary else Color(0.29, 0.216, 0.157)
        b.add_theme_color_override("font_color", fg)
        b.add_theme_color_override("font_hover_color", fg)
        b.add_theme_color_override("font_focus_color", fg)
        b.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
        b.add_theme_color_override("font_disabled_color", Color(0.55, 0.51, 0.46))

func _unhandled_input(e: InputEvent) -> void:
        if e is InputEventKey and e.pressed:
                if e.keycode == KEY_SPACE or e.keycode == KEY_UP or e.keycode == KEY_W:
                        do_jump()
                elif e.keycode == KEY_X or e.keycode == KEY_SHIFT:
                        _on_boost()

func do_jump() -> void:
        if ended:
                return
        if on_ground:
                vy = -980.0 * float(Globals.car_stats()["jump"])
                on_ground = false
                AudioMgr.play_sfx("jump")

func _on_boost() -> void:
        if ended or turbo_meter < 0.99:
                return
        turbo_left = float(Globals.car_stats()["turbo"])
        turbo_meter = 0.0
        AudioMgr.play_sfx("boost")
        if brain != null:
                brain.say(car_anchor, str(Globals.CARS[Globals.selected_car]["id"]), "nitro")

func _toggle_pause() -> void:
        var t := get_tree()
        t.paused = not t.paused
        if end_panel == null:
                pass

func _process(delta: float) -> void:
        if ended or get_tree().paused:
                return
        elapsed += delta
        if autotest:
                _auto_timer += delta
                if _auto_timer > 1.1:
                        _auto_timer = 0.0
                        do_jump()
                if elapsed > 3.2 and not _shot_taken:
                        _shot_taken = true
                        var img := get_viewport().get_texture().get_image()
                        img.save_png("/home/z/my-project/scripts/shot_game.png")
                if elapsed > 6.0:
                        print("AUTOTEST OK world_x=", int(world_x), " coins=", coins_got, " objs=", world.get_child_count())
                        get_tree().quit()
        var boosting := turbo_left > 0.0
        if boosting:
                turbo_left -= delta
        turbo_meter = min(1.0, turbo_meter + delta * 0.22)
        var target_mult := 1.0
        if boosting:
                target_mult = 1.85
        if elapsed < slow_until:
                target_mult = 0.38
        speed_mult = lerp(speed_mult, target_mult, delta * 4.0)
        var spd := speed_base * speed_mult

        world_x += spd * delta
        time_left -= delta
        if time_left <= 0.0:
                _finish(false)
                return

        # scroll painterly parallax layers (mirror-tiled)
        for L in layers:
                var off := fmod(world_x * float(L["f"]), float(L["w"]))
                (L["s1"] as Sprite2D).position.x = -off
                (L["s2"] as Sprite2D).position.x = float(L["w"]) - off

        # spawn
        while world_x + VIEW_W > next_obj_x:
                _spawn(next_obj_x)
                next_obj_x += randf_range(260.0, 460.0) * (1.0 + float(lv["speed"]) / 70.0)

        # car physics
        vy += GRAVITY * delta
        car_y += vy * delta
        if car_y >= 0.0:
                car_y = 0.0
                vy = 0.0
                if not on_ground:
                        on_ground = true
        car.position = Vector2(CAR_X, GROUND_Y + car_y)
        car_sprite.rotation = clamp(vy * 0.00045, -0.3, 0.35)
        var h: float = clamp(-car_y / 420.0, 0.0, 1.0)
        shadow.position = Vector2(CAR_X, GROUND_Y - 6)
        shadow.scale = Vector2(1.0 - 0.4 * h, 1.0 - 0.25 * h)
        shadow.modulate = Color(1, 1, 1, 0.5 - 0.32 * h)

        # لنگرِ حباب گفتار — بالای سر ماشین (مختصات صفحه)
        if car_anchor != null:
                var sp: Vector2 = car_sprite.get_global_transform_with_canvas().origin
                car_anchor.position = sp + Vector2(0.0, -140.0)

        # بوست مخفی بوقی — سیستم طرف بوقی است! هر چند ثانیه نیترویش را پر می‌کند
        if brain != null and Globals.selected_car == 0 and not autotest:
                _boost_in -= delta
                if _boost_in <= 0.0 and turbo_meter < 0.62:
                        _boost_in = 13.0 + randf() * 7.0
                        turbo_meter = 1.0
                        nitro_bar.modulate = Color(1.6, 1.4, 0.7)
                        var tw := create_tween()
                        tw.tween_property(nitro_bar, "modulate", Color(1, 1, 1), 0.8)
                        brain.say(car_anchor, "boghi", "boost")

        # move world objects
        for obj in world.get_children():
                obj.position.x -= spd * delta
                if obj.position.x < -260:
                        obj.queue_free()

        # hud
        coin_label.text = "سکه " + str(coins_got) + (" / " + str(target_coins) if target_coins > 0 else "")
        time_label.text = "زمان " + str(int(ceil(time_left)))
        progress.value = 100.0 * world_x / finish_px
        if target_passengers > 0:
                extra_label.text = "مسافر " + str(passengers) + " / " + str(target_passengers)
        # جلوه‌های نیترو و زندگی صحنه
        flame.emitting = boosting
        dust.emitting = on_ground and spd > 70.0
        lines.visible = boosting
        nitro_bar.value = turbo_meter * 100.0
        var zoom_target := Vector2(0.92, 0.92) if boosting else Vector2.ONE
        cam.zoom = cam.zoom.lerp(zoom_target, delta * 3.0)
        if on_ground:
                car_sprite.position.y = 12.0 - car_sprite.texture.get_height() * car_sprite.scale.y * 0.5 + sin(elapsed * 28.0) * 1.6

        boost_btn.modulate = Color(1, 1, 1) if turbo_meter >= 0.99 else Color(0.6, 0.6, 0.6)
        AudioMgr.set_engine(true, clamp((spd / 300.0) * speed_mult, 0.0, 1.0))

        # win conditions
        var win := false
        if lv["type"] == "collect" and target_coins > 0 and coins_got >= target_coins:
                win = true
        if lv["type"] == "taxi" and target_passengers > 0 and passengers >= target_passengers:
                win = true
        if world_x >= finish_px:
                win = true
        if win:
                _finish(true)

        # shake decay
        if shake > 0.0:
                shake = max(0.0, shake - delta * 30.0)
                cam.offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
        else:
                cam.offset = Vector2.ZERO

func _spawn(x: float) -> void:
        var rel := x - world_x
        var coin_rate := float(lv["coin_rate"])
        var obst_rate := float(lv["obstacle_rate"])
        if lv["type"] == "collect":
                obst_rate *= 0.5
                coin_rate = min(1.0, coin_rate + 0.2)
        # scheduled passengers for taxi
        if next_passenger_idx < passenger_spots.size() and x >= passenger_spots[next_passenger_idx]:
                next_passenger_idx += 1
                _make_obj("passenger", rel)
                return
        var r := randf()
        if r < obst_rate:
                _make_obj("cone", rel)
        elif r < obst_rate + coin_rate:
                _make_coin_arc(rel)
        elif r < obst_rate + coin_rate + float(lv["ramp_rate"]):
                _make_obj("ramp", rel)

func _make_obj(kind: String, rel_x: float) -> Area2D:
        var a := Area2D.new()
        a.position = Vector2(VIEW_W + rel_x, GROUND_Y)
        a.set_meta("kind", kind)
        a.monitorable = true
        var cs := CollisionShape2D.new()
        var sh := RectangleShape2D.new()
        var spr := Sprite2D.new()
        match kind:
                "cone":
                        sh.size = Vector2(70, 90)
                        cs.position = Vector2(0, -45)
                        spr.texture = load("res://assets/sprites/cone.png")
                        spr.scale = Vector2(0.55, 0.55)
                        spr.position = Vector2(0, -48)
                "passenger":
                        sh.size = Vector2(90, 140)
                        cs.position = Vector2(0, -70)
                        spr.texture = load("res://assets/sprites/passenger.png")
                        spr.scale = Vector2(0.5, 0.5)
                        spr.position = Vector2(0, -85)
                "ramp":
                        sh.size = Vector2(220, 90)
                        cs.position = Vector2(0, -45)
                        spr.texture = load("res://assets/sprites/ramp.png")
                        spr.scale = Vector2(0.75, 0.75)
                        spr.position = Vector2(0, -50)
        a.add_child(cs)
        a.add_child(spr)
        world.add_child(a)
        return a

func _make_coin_arc(rel_x: float) -> void:
        var n := randi_range(4, 6)
        for i in n:
                var a := Area2D.new()
                a.position = Vector2(VIEW_W + rel_x + i * 70.0, GROUND_Y - 70 - sin(float(i) / (n - 1) * PI) * 150.0)
                a.set_meta("kind", "coin")
                a.monitorable = true
                var cs := CollisionShape2D.new()
                var sh := RectangleShape2D.new()
                sh.size = Vector2(80, 80)
                cs.shape = sh
                a.add_child(cs)
                var spr := Sprite2D.new()
                spr.texture = load("res://assets/sprites/coin.png")
                spr.scale = Vector2(0.55, 0.55)
                a.add_child(spr)
                world.add_child(a)

func _on_hit(a: Area2D) -> void:
        if ended:
                return
        var kind := str(a.get_meta("kind", ""))
        match kind:
                "coin":
                        coins_got += 1
                        AudioMgr.play_sfx("coin")
                        a.queue_free()
                "passenger":
                        passengers += 1
                        AudioMgr.play_sfx("horn")
                        a.queue_free()
                "ramp":
                        if on_ground:
                                vy = -1150.0 * float(Globals.car_stats()["jump"])
                                on_ground = false
                                AudioMgr.play_sfx("jump")
                "cone":
                        if elapsed < invuln_until:
                                return
                        invuln_until = elapsed + 1.2
                        slow_until = elapsed + 1.1
                        shake = 9.0
                        AudioMgr.play_sfx("crash")
                        if brain != null and elapsed > _hit_chat_until:
                                _hit_chat_until = elapsed + 5.0
                                brain.say(car_anchor, str(Globals.CARS[Globals.selected_car]["id"]), "hit")

func _finish(win: bool) -> void:
        if ended:
                return
        ended = true
        AudioMgr.set_engine(false)
        var stars := 0
        var reward := 0
        if win:
                var tf := time_left / float(lv["time"])
                stars = 3 if tf >= 0.25 else (2 if tf >= 0.08 else 1)
                reward = int(lv["reward"]) + stars * 30
                Globals.add_coins(reward)
                Globals.set_stars(int(lv["id"]), stars)
                AudioMgr.play_sfx("win")
        else:
                AudioMgr.play_sfx("fail")
        # جشن بعد خط پایان: ماشین زنده می‌شود، می‌رقصد، رقیب‌ها رد می‌شوند و کری می‌خوانند
        _celebrate(win)
        var stars_c := stars
        var reward_c := reward
        get_tree().create_timer(3.4 if win else 1.4).timeout.connect(func():
                _show_end(win, stars_c, reward_c))

## جشنِ خط پایان — نسخه چشم‌دار زنده می‌شود + کانفتی + رقیب‌ها تیکه می‌اندازند
func _celebrate(win: bool) -> void:
        if car_sprite == null:
                return
        # ۱) تعویض به چهره زنده (چشم + لبخند) — روحِ ماشین برمی‌گردد
        var cute_path: String = str(Globals.CARS[Globals.selected_car]["tex"])
        if ResourceLoader.exists(cute_path):
                car_sprite.texture = load(cute_path)
                var th := car_sprite.texture.get_height() * car_sprite.scale.y
                car_sprite.position.y = 12.0 - th * 0.5
        # ۲) جست‌وخیز — فنری و خوشحال
        var base_y := car_sprite.position.y
        var tw := create_tween().set_loops(6)
        tw.tween_property(car_sprite, "position:y", base_y - 26.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        tw.parallel().tween_property(car_sprite, "scale", car_sprite.scale * Vector2(0.92, 1.12), 0.16)
        tw.tween_property(car_sprite, "position:y", base_y, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
        tw.parallel().tween_property(car_sprite, "scale", car_sprite.scale, 0.2)
        # ۳) کانفتی — باران شادی روی جاده
        for i in 3:
                var c := CPUParticles2D.new()
                c.position = Vector2(240 + i * 300.0, 60.0)
                c.emitting = false
                c.amount = 42
                c.lifetime = 3.2
                c.direction = Vector2(0, 1)
                c.spread = 45.0
                c.gravity = Vector2(0, 240)
                c.initial_velocity_min = 60.0
                c.initial_velocity_max = 160.0
                c.scale_amount_min = 5.0
                c.scale_amount_max = 9.0
                var g := Gradient.new()
                g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
                var cols: Array = [Color(1.0, 0.42, 0.16), Color(1.0, 0.85, 0.2), Color(0.25, 0.75, 0.95)]
                g.colors = PackedColorArray([cols[i], cols[(i + 1) % 3], cols[(i + 2) % 3]])
                c.color_ramp = g
                c.z_index = 8
                add_child(c)
                c.emitting = win
        # ۴) حباب‌ها و کری‌خوانی
        var my_id := str(Globals.CARS[Globals.selected_car]["id"])
        if brain != null and car_anchor != null:
                brain.say(car_anchor, my_id, "win" if win else "lose")
        if win:
                _rival_parade(my_id)

## رقیب‌ها از جاده رد می‌شوند و کری می‌خوانند — «کری‌خوانیِ محله»
func _rival_parade(my_id: String) -> void:
        var ids: Array = []
        for c in Globals.CARS:
                if str(c["id"]) != my_id:
                        ids.append(str(c["id"]))
        if ids.is_empty():
                return
        for i in 2:
                var rid: String = ids[randi_range(0, ids.size() - 1)]
                var tex_path: String = "res://assets/sprites/" + rid + "_side.png"
                if not ResourceLoader.exists(tex_path):
                        continue
                var rv := Sprite2D.new()
                rv.texture = load(tex_path)
                var sc := 214.0 / float(rv.texture.get_height())
                rv.scale = Vector2(sc, sc)
                rv.position = Vector2(1580.0, GROUND_Y - rv.texture.get_height() * sc * 0.5 + 12.0)
                rv.z_index = 3
                add_child(rv)
                var stop_x := 720.0 + i * 240.0
                var tw2 := create_tween()
                tw2.tween_property(rv, "position:x", stop_x, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
                tw2.tween_callback(func():
                        if brain == null or not is_instance_valid(rv):
                                return
                        var anchor := Control.new()
                        anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
                        anchor.size = Vector2(160, 60)
                        var sp: Vector2 = rv.get_global_transform_with_canvas().origin
                        anchor.position = sp + Vector2(-40.0, -150.0)
                        hud.add_child(anchor)
                        brain.say(anchor, rid, "taunt")
                        var tw3 := create_tween()
                        tw3.tween_property(rv, "position:x", -300.0, 1.6).set_delay(1.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
                        tw3.tween_callback(rv.queue_free))

func _show_end(win: bool, stars: int, reward: int) -> void:
        end_panel = PanelContainer.new()
        end_panel.add_theme_stylebox_override("panel", _sb(Color(0.99, 0.965, 0.9), Color(0.29, 0.216, 0.157), 24, 5))
        var vb := VBoxContainer.new()
        vb.add_theme_constant_override("separation", 12)
        end_panel.add_child(vb)
        end_title = Label.new()
        end_title.text = Globals.L("win") if win else Globals.L("lose")
        end_title.add_theme_font_override("font", load("res://assets/fonts/Vazirmatn-Bold.ttf"))
        end_title.add_theme_color_override("font_color", Color(0.29, 0.216, 0.157))
        end_title.add_theme_font_size_override("font_size", 40)
        end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        vb.add_child(end_title)
        end_stars = Label.new()
        end_stars.text = "٭٭٭".substr(0, stars) + "···".substr(0, 3 - stars) if stars > 0 else "---"
        end_stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        end_stars.add_theme_font_size_override("font_size", 44)
        end_stars.add_theme_color_override("font_color", Color(0.72, 0.52, 0.1))
        vb.add_child(end_stars)
        end_reward = Label.new()
        end_reward.text = Globals.L("reward") + ": " + str(reward) + " سکه"
        end_reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        end_reward.add_theme_font_size_override("font_size", 28)
        end_reward.add_theme_color_override("font_color", Color(0.29, 0.216, 0.157))
        vb.add_child(end_reward)
        var hb := HBoxContainer.new()
        hb.alignment = BoxContainer.ALIGNMENT_CENTER
        hb.add_theme_constant_override("separation", 14)
        var b_retry := Button.new()
        b_retry.text = Globals.L("retry")
        b_retry.add_theme_font_override("font", load("res://assets/fonts/Vazirmatn-Bold.ttf"))
        b_retry.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game.tscn"))
        _style_btn(b_retry, true)
        hb.add_child(b_retry)
        if win and int(lv["id"]) < 50:
                var b_next := Button.new()
                b_next.text = Globals.L("next")
                b_next.add_theme_font_override("font", load("res://assets/fonts/Vazirmatn-Bold.ttf"))
                b_next.pressed.connect(func():
                        Globals.set_meta("start_level", int(lv["id"]) + 1)
                        get_tree().change_scene_to_file("res://scenes/game.tscn"))
                _style_btn(b_next, true)
                hb.add_child(b_next)
        var b_menu := Button.new()
        b_menu.text = Globals.L("menu")
        b_menu.add_theme_font_override("font", load("res://assets/fonts/Vazirmatn-Bold.ttf"))
        b_menu.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/menu.tscn"))
        _style_btn(b_menu, false)
        hb.add_child(b_menu)
        vb.add_child(hb)
        hud.add_child(end_panel)
        # وسط‌چین لنگری — روی هر عرضی مرکز صفحه
        _place(end_panel, 0.5, 0.5, 0.5, 0.5, -260, -170, 260, 130)
        end_panel.custom_minimum_size = Vector2(520, 300)
        end_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
        end_panel.grow_vertical = Control.GROW_DIRECTION_BOTH

func _exit_tree() -> void:
        AudioMgr.set_engine(false)


func _make_shadow_tex() -> ImageTexture:
    var sz := Vector2i(180, 56)
    var img := Image.create(sz.x, sz.y, false, Image.FORMAT_RGBA8)
    var cx := sz.x / 2.0
    var cy := sz.y / 2.0
    for y in sz.y:
        for x in sz.x:
            var d := Vector2((x - cx) / (cx - 6.0), (y - cy) / (cy - 4.0)).length()
            var a: float = clamp(1.0 - d, 0.0, 1.0)
            img.set_pixel(x, y, Color(0.03, 0.02, 0.05, a * a * 0.9))
    return ImageTexture.create_from_image(img)


## خطوط سرعتِ هنگام نیترو — رسم سبک هر فریم
class SpeedLines extends Control:
    var t := 0.0

    func _process(delta: float) -> void:
        t += delta
        if visible:
            queue_redraw()

    func _draw() -> void:
        var rng := RandomNumberGenerator.new()
        rng.seed = int(t * 24.0)
        for i in 20:
            var y := rng.randf_range(70.0, 640.0)
            var x := rng.randf_range(-60.0, 1020.0)
            var ln := rng.randf_range(120.0, 320.0)
            draw_line(Vector2(x, y), Vector2(x + ln, y), Color(1.0, 0.95, 0.8, 0.12), 3.0)
