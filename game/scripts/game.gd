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

var world: Node2D
var layers: Array = []  # painterly parallax: {s1, s2, w, f}
var car: Area2D
var car_sprite: Sprite2D
var plate_label: Label
var cam: Camera2D
var hud: CanvasLayer
var coin_label: Label
var time_label: Label
var mission_label: Label
var extra_label: Label
var progress: ProgressBar
var boost_btn: Button
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
        mission_label.text = Globals.L("mission") + " " + str(lv["id"]) + ": " + str(lv["name"]) + " — " + Globals.L("type_" + str(lv["type"]))
        if autotest:
                time_left = 999
                _auto_timer = 0.0

func _build_world() -> void:
        var backdrop := ColorRect.new()
        backdrop.color = Color(0.99, 0.9, 0.78)
        backdrop.size = Vector2(VIEW_W, VIEW_H)
        backdrop.z_index = -14
        add_child(backdrop)

        # painterly parallax: far city (opaque) -> hills -> road
        _add_layer("res://assets/sprites/bg_far.png", -12, GROUND_Y + 50.0, 1.286, 0.18)
        _add_layer("res://assets/sprites/bg_mid.png", -10, GROUND_Y + 30.0, 1.286, 0.45, 0.7)
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
        rect.size = Vector2(215, 145)
        shape.shape = rect
        shape.position = Vector2(0, -70)
        car.add_child(shape)
        car.area_entered.connect(_on_hit)
        car_sprite = Sprite2D.new()
        car_sprite.texture = load(Globals.CARS[Globals.selected_car]["tex"])
        var sc := 0.58 # ماشین بزرگ‌تر و جوندار در محیط (درخواست کاربر)
        car_sprite.scale = Vector2(sc, sc)
        var th := car_sprite.texture.get_height() * sc
        car_sprite.position = Vector2(0, 12.0 - th * 0.5) # چرخ‌ها روی جاده
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
        add_child(car)

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

        progress = ProgressBar.new()
        progress.min_value = 0
        progress.max_value = 100
        progress.value = 0
        progress.show_percentage = false
        progress.position = Vector2(390, 64)
        progress.size = Vector2(500, 22)
        var pbg := _sb(Color(0.99, 0.965, 0.9), Color(0.29, 0.216, 0.157), 10, 3)
        var pfill := _sb(Color(0.957, 0.769, 0.188), Color(0.72, 0.52, 0.1), 8, 0, false)
        progress.add_theme_stylebox_override("background", pbg)
        progress.add_theme_stylebox_override("fill", pfill)
        hud.add_child(progress)

        var pause_btn := Button.new()
        pause_btn.text = "II"
        pause_btn.position = Vector2(1216, 12)
        pause_btn.size = Vector2(52, 52)
        pause_btn.pressed.connect(_toggle_pause)
        _style_btn(pause_btn, false)
        hud.add_child(pause_btn)

        var jump_btn := Button.new()
        jump_btn.text = Globals.L("jump")
        jump_btn.add_theme_font_override("font", font)
        jump_btn.add_theme_font_size_override("font_size", 34)
        jump_btn.position = Vector2(1060, VIEW_H - 130)
        jump_btn.size = Vector2(190, 100)
        jump_btn.pressed.connect(do_jump)
        _style_btn(jump_btn, true)
        hud.add_child(jump_btn)

        boost_btn = Button.new()
        boost_btn.text = Globals.L("boost")
        boost_btn.add_theme_font_override("font", font)
        boost_btn.add_theme_font_size_override("font_size", 30)
        boost_btn.position = Vector2(850, VIEW_H - 130)
        boost_btn.size = Vector2(190, 100)
        boost_btn.pressed.connect(_on_boost)
        _style_btn(boost_btn, true)
        hud.add_child(boost_btn)

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
                if elapsed > 2.5 and not _shot_taken:
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
                target_mult = 1.6
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

        # move world objects
        for obj in world.get_children():
                obj.position.x -= spd * delta
                if obj.position.x < -260:
                        obj.queue_free()

        # hud
        coin_label.text = "🪙 " + str(coins_got) + (" / " + str(target_coins) if target_coins > 0 else "")
        time_label.text = "⏱ " + str(int(ceil(time_left)))
        progress.value = 100.0 * world_x / finish_px
        if target_passengers > 0:
                extra_label.text = "🚕 " + str(passengers) + " / " + str(target_passengers)
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
        _show_end(win, stars, reward)

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
        end_stars.text = "★★★".substr(0, stars) + "···".substr(0, 3 - stars) if stars > 0 else "---"
        end_stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        end_stars.add_theme_font_size_override("font_size", 44)
        end_stars.add_theme_color_override("font_color", Color(0.72, 0.52, 0.1))
        vb.add_child(end_stars)
        end_reward = Label.new()
        end_reward.text = Globals.L("reward") + ": " + str(reward) + " 🪙"
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
        end_panel.position = Vector2(VIEW_W / 2 - 260, VIEW_H / 2 - 160)
        end_panel.custom_minimum_size = Vector2(520, 300)
        hud.add_child(end_panel)

func _exit_tree() -> void:
        AudioMgr.set_engine(false)
