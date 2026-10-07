
# ─────────────────────────── ساخت ماشین ───────────────────────────
func _car_tex_path(id: String) -> String:
	var top := "res://assets/sprites/" + id + "_top.png"
	if ResourceLoader.exists(top):
		return top
	return "res://assets/sprites/" + id + "_side.png"

func _make_car_node(id: String, with_fx: bool, light_alpha: float) -> Dictionary:
	var n := Node2D.new()
	var light := Polygon2D.new()
	light.polygon = PackedVector2Array([
		Vector2(34, -24), Vector2(34, 24), Vector2(430, 130), Vector2(430, -130),
	])
	light.color = Color(1.0, 0.93, 0.62, light_alpha)
	var lmat := CanvasItemMaterial.new()
	lmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	light.material = lmat
	light.z_index = -1
	n.add_child(light)
	var sh := Sprite2D.new()
	sh.texture = _make_shadow_tex()
	sh.scale = Vector2(1.05, 1.5)
	sh.modulate = Color(1, 1, 1, 0.55)
	sh.z_index = -1
	n.add_child(sh)
	var spr := Sprite2D.new()
	spr.texture = load(_car_tex_path(id))
	n.add_child(spr)
	if with_fx:
		var fl := CPUParticles2D.new()
		fl.position = Vector2(-66, 0)
		fl.emitting = false
		fl.amount = 26
		fl.lifetime = 0.3
		fl.direction = Vector2(-1, 0)
		fl.spread = 12.0
		fl.initial_velocity_min = 240.0
		fl.initial_velocity_max = 420.0
		fl.scale_amount_min = 3.0
		fl.scale_amount_max = 6.5
		var fg := Gradient.new()
		fg.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		fg.colors = PackedColorArray([Color(1.0, 0.95, 0.55), Color(1.0, 0.45, 0.1), Color(0.6, 0.1, 0.05, 0.0)])
		fl.color_ramp = fg
		n.add_child(fl)
		var sm := CPUParticles2D.new()
		sm.position = Vector2(-52, 22)
		sm.emitting = false
		sm.amount = 20
		sm.lifetime = 0.8
		sm.direction = Vector2(0, 0)
		sm.spread = 180.0
		sm.initial_velocity_min = 30.0
		sm.initial_velocity_max = 90.0
		sm.scale_amount_min = 4.0
		sm.scale_amount_max = 9.0
		var sg := Gradient.new()
		sg.offsets = PackedFloat32Array([0.0, 1.0])
		sg.colors = PackedColorArray([Color(0.75, 0.75, 0.78, 0.5), Color(0.6, 0.6, 0.65, 0.0)])
		sm.color_ramp = sg
		n.add_child(sm)
	world.add_child(n)
	return {"node": n, "spr": spr, "flame": fl if with_fx else null, "smoke": sm if with_fx else null}

func _build_car(stats: Dictionary) -> void:
	car = Node2D.new()
	car.z_index = 5
	var fx := _make_car_node(str(Globals.CARS[Globals.selected_car]["id"]), true, 0.10)
	# نود افکت‌ها باید داخل نود ماشین باشند تا با چرخش بچرخند
	car.add_child(fx["node"])
	car_sprite = fx["spr"]
	flame = fx["flame"]
	smoke = fx["smoke"]
	car_pos = _path_pos(0.0)
	heading = _path_dir(0.0).angle()
	car.position = car_pos
	car.rotation = heading
	cam = Camera2D.new()
	cam.zoom = Vector2(1.05, 1.05)
	add_child(cam)
	cam.make_current()

func _spawn_rivals() -> void:
	var pool := RIVAL_POOL.duplicate()
	pool.shuffle()
	var starts := [-150.0, -80.0, 100.0]
	var lanes := [-55.0, 55.0, 0.0]
	for i in 3:
		var id: String = pool[i]
		var fx := _make_car_node(id, false, 0.055)
		fx["node"].z_index = 4
		fx["spr"].scale = Vector2(0.94, 0.94)
		rivals.append({
			"node": fx["node"], "spr": fx["spr"],
			"s": float(starts[i]), "spd": 0.0,
			"pace": randf_range(0.965, 1.045),
			"lane": float(lanes[i]), "lane_cur": float(lanes[i]),
			"ang": 0.0, "corner": false,
		})

func _spawn_traffic(s_abs: float) -> void:
	var ids := ["traf_white", "traf_gray", "traf_taxi", "traf_van"]
	var id: String = ids[randi_range(0, ids.size() - 1)]
	var fx := _make_car_node(id, false, 0.0)
	fx["node"].z_index = 3
	fx["spr"].scale = Vector2(0.9, 0.9)
	var dir := 1.0
	if randf() < 0.22:
		dir = -1.0
	var lane := 58.0 * dir
	traffic.append({
		"node": fx["node"], "spr": fx["spr"],
		"s": s_abs, "dir": dir, "spd": randf_range(150.0, 250.0), "lane": lane,
	})

func _spawn_coins(s_abs: float) -> void:
	var side := 1.0 if randf() < 0.5 else -1.0
	var lane := 60.0 * side
	var dd: Vector2 = _path_dir(s_abs)
	var nn := Vector2(-dd.y, dd.x)
	for i in 5:
		var tex: Texture2D = load("res://assets/sprites/coin.png")
		var n := Node2D.new()
		n.z_index = 2
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.scale = Vector2(0.42, 0.42)
		n.add_child(spr)
		var pos: Vector2 = _path_pos(s_abs + i * 95.0) + nn * lane
		n.position = pos
		world.add_child(n)
		coins_on_road.append({"node": n, "pos": pos, "t": randf() * TAU})

func _make_shadow_tex() -> ImageTexture:
	var sz := Vector2i(150, 90)
	var img := Image.create(sz.x, sz.y, false, Image.FORMAT_RGBA8)
	var cx := sz.x / 2.0
	var cy := sz.y / 2.0
	for y in sz.y:
		for x in sz.x:
			var d := Vector2((x - cx) / (cx - 5.0), (y - cy) / (cy - 5.0)).length()
			var a: float = clamp(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(0.0, 0.0, 0.02, a * a * 0.85))
	return ImageTexture.create_from_image(img)

# ─────────────────────────── HUD مسابقه ───────────────────────────
func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud)
	var font: FontFile = load("res://assets/fonts/Lalezar-Regular.ttf")
	var bold: FontFile = load("res://assets/fonts/Vazirmatn-Bold.ttf")

	# زون‌های فرمان — کل گوشه‌های پایین (زیر دکمه‌ها)؛ همان مسیر انگشت کاربر
	var zone_l := Control.new()
	zone_l.mouse_filter = Control.MOUSE_FILTER_STOP
	_place(zone_l, 0.0, 0.40, 0.42, 1.0, 0, 0, 0, 0)
	zone_l.gui_input.connect(func(e: InputEvent):
		if e is InputEventScreenTouch or e is InputEventMouseButton:
			steer_left = e.pressed)
	hud.add_child(zone_l)
	var zone_r := Control.new()
	zone_r.mouse_filter = Control.MOUSE_FILTER_STOP
	_place(zone_r, 0.58, 0.40, 1.0, 1.0, 0, 0, 0, 0)
	zone_r.gui_input.connect(func(e: InputEvent):
		if e is InputEventScreenTouch or e is InputEventMouseButton:
			steer_right = e.pressed)
	hud.add_child(zone_r)
	# راهنمای بصری گوشه‌ها
	var hint_l := _hud_label(font, 30, Vector2.ZERO, Color(1, 1, 1, 0.4))
	hint_l.text = "چپ"
	_place(hint_l, 0.0, 1.0, 0.0, 1.0, 40, -66, 130, -22)
	var hint_r := _hud_label(font, 30, Vector2.ZERO, Color(1, 1, 1, 0.4))
	hint_r.text = "راست"
	_place(hint_r, 1.0, 1.0, 1.0, 1.0, -130, -66, -40, -22)

	# جایگاه — بالای وسط، بزرگ و طلایی (NFS)
	pos_label = _hud_label(font, 58, Vector2.ZERO, Color(0.98, 0.8, 0.2))
	pos_label.add_theme_constant_override("outline_size", 12)
	_place(pos_label, 0.5, 0.0, 0.5, 0.0, -160, 44, 160, 116)
	pos_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lap_label = _hud_label(font, 30, Vector2.ZERO, Color(0.95, 0.95, 0.98, 0.9))
	_place(lap_label, 0.5, 0.0, 0.5, 0.0, -160, 112, 160, 152)
	lap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# نوار پیشرفت کل مسابقه
	progress = ProgressBar.new()
	progress.min_value = 0
	progress.max_value = 100
	progress.value = 0
	progress.show_percentage = false
	progress.add_theme_stylebox_override("background", _sb(Color(0.08, 0.08, 0.12, 0.8), Color(0.5, 0.45, 0.3, 0.6), 6, 1, false))
	progress.add_theme_stylebox_override("fill", _sb(Color(0.95, 0.62, 0.12), Color(0.7, 0.4, 0.05), 6, 0, false))
	hud.add_child(progress)
	_place(progress, 0.5, 0.0, 0.5, 0.0, -140, 154, 140, 170)

	coin_label = _hud_label(font, 34, Vector2.ZERO, Color(0.95, 0.75, 0.1))
	_place(coin_label, 1.0, 0.0, 1.0, 0.0, -280, 46, -70, 96)
	time_label = _hud_label(font, 32, Vector2.ZERO, Color(0.95, 0.4, 0.3))
	_place(time_label, 1.0, 0.0, 1.0, 0.0, -280, 100, -70, 144)
	mission_label = _hud_label(font, 26, Vector2.ZERO, Color(0.9, 0.9, 0.95, 0.85))
	_place(mission_label, 0.0, 0.0, 1.0, 0.0, 130, 46, -20, 86)
	mission_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# دکمه توقف — بالا چپ
	pause_btn = Button.new()
	pause_btn.text = "II"
	pause_btn.add_theme_font_override("font", font)
	pause_btn.add_theme_font_size_override("font_size", 34)
	_style_btn(pause_btn, false)
	hud.add_child(pause_btn)
	_place(pause_btn, 0.0, 0.0, 0.0, 0.0, 24, 46, 116, 122)
	pause_btn.pressed.connect(_toggle_pause)

	# نیترو — دکمه بزرگ آبی، بالا-وسطِ زون راست (انگشت راست راحت می‌رسد)
	var btn_nitro := Button.new()
	btn_nitro.text = Globals.L("nitro")
	btn_nitro.add_theme_font_override("font", font)
	btn_nitro.add_theme_font_size_override("font_size", 44)
	var nfs := _sb(Color(0.13, 0.35, 0.75), Color(0.35, 0.6, 1.0), 18, 3)
	btn_nitro.add_theme_stylebox_override("normal", nfs)
	btn_nitro.add_theme_stylebox_override("hover", _sb(Color(0.18, 0.42, 0.85), Color(0.45, 0.7, 1.0), 18, 3))
	btn_nitro.add_theme_stylebox_override("pressed", _sb(Color(0.1, 0.25, 0.55), Color(0.35, 0.6, 1.0), 18, 3))
	btn_nitro.add_theme_stylebox_override("disabled", nfs)
	btn_nitro.add_theme_color_override("font_color", Color(0.85, 0.93, 1.0))
	btn_nitro.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	btn_nitro.button_down.connect(func(): nitro_held = true)
	btn_nitro.button_up.connect(func(): nitro_held = false)
	hud.add_child(btn_nitro)
	_place(btn_nitro, 1.0, 1.0, 1.0, 1.0, -500, -190, -260, -50)

	# ترمز — دکمه قرمز تیره بالا-وسطِ زون چپ
	var btn_brake := Button.new()
	btn_brake.text = "ترمز"
	btn_brake.add_theme_font_override("font", font)
	btn_brake.add_theme_font_size_override("font_size", 38)
	btn_brake.add_theme_stylebox_override("normal", _sb(Color(0.45, 0.13, 0.13), Color(0.75, 0.3, 0.25), 18, 3))
	btn_brake.add_theme_stylebox_override("hover", _sb(Color(0.55, 0.18, 0.16), Color(0.8, 0.35, 0.3), 18, 3))
	btn_brake.add_theme_stylebox_override("pressed", _sb(Color(0.32, 0.08, 0.08), Color(0.75, 0.3, 0.25), 18, 3))
	btn_brake.add_theme_stylebox_override("disabled", _sb(Color(0.45, 0.13, 0.13), Color(0.75, 0.3, 0.25), 18, 3))
	btn_brake.add_theme_color_override("font_color", Color(1.0, 0.9, 0.85))
	btn_brake.button_down.connect(func(): brake_held = true)
	btn_brake.button_up.connect(func(): brake_held = false)
	hud.add_child(btn_brake)
	_place(btn_brake, 0.0, 1.0, 0.0, 1.0, 260, -190, 500, -50)

	# گیج نیترو — باریک، بالای گیج سرعت
	nitro_bar = ProgressBar.new()
	nitro_bar.min_value = 0
	nitro_bar.max_value = 100
	nitro_bar.value = 100
	nitro_bar.show_percentage = false
	nitro_bar.add_theme_stylebox_override("background", _sb(Color(0.07, 0.08, 0.14, 0.85), Color(0.3, 0.5, 0.9, 0.7), 6, 1, false))
	nitro_bar.add_theme_stylebox_override("fill", _sb(Color(0.25, 0.65, 1.0), Color(0.15, 0.4, 0.9), 6, 0, false))
	hud.add_child(nitro_bar)
	_place(nitro_bar, 0.5, 1.0, 0.5, 1.0, -130, -252, 130, -228)

	# گیج سرعت — سفارشی (قوس + عقربه) + عدد کیلومتر
	gauge = SpeedGauge.new()
	gauge.game = self
	_place(gauge, 0.5, 1.0, 0.5, 1.0, -150, -205, 150, -25)
	hud.add_child(gauge)
	kmh_label = _hud_label(font, 56, Vector2.ZERO, Color(0.98, 0.98, 1.0))
	kmh_label.add_theme_constant_override("outline_size", 10)
	kmh_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(kmh_label, 0.5, 1.0, 0.5, 1.0, -100, -170, 100, -100)

	# خطوط سرعت نیترو
	lines = SpeedLines.new()
	lines.size = Vector2(VIEW_W, VIEW_H)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.visible = false
	hud.add_child(lines)

	# شمارش معکوس
	intro_label = Label.new()
	intro_label.add_theme_font_override("font", font)
	intro_label.add_theme_font_size_override("font_size", 130)
	intro_label.add_theme_color_override("font_color", Color(0.98, 0.8, 0.2))
	intro_label.add_theme_color_override("font_outline_color", Color(0.12, 0.05, 0.02))
	intro_label.add_theme_constant_override("outline_size", 24)
	intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_label.anchor_left = 0.0
	intro_label.anchor_right = 1.0
	intro_label.anchor_top = 0.26
	intro_label.anchor_bottom = 0.26
	intro_label.offset_top = -90.0
	intro_label.offset_bottom = 100.0
	intro_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_label.z_index = 30
	hud.add_child(intro_label)

	# پرده توقف
	pause_overlay = Control.new()
	pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_overlay.visible = false
	var pv := ColorRect.new()
	pv.color = Color(0, 0, 0, 0.6)
	pv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_overlay.add_child(pv)
	var pl := Label.new()
	pl.text = Globals.L("paused")
	pl.add_theme_font_override("font", bold)
	pl.add_theme_font_size_override("font_size", 46)
	pl.add_theme_color_override("font_color", Color(0.95, 0.93, 0.85))
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pl.anchor_left = 0.0
	pl.anchor_right = 1.0
	pl.anchor_top = 0.45
	pl.anchor_bottom = 0.55
	pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_overlay.add_child(pl)
	hud.add_child(pause_overlay)

func _hud_label(font: FontFile, size: int, pos: Vector2, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.1))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(l)
	return l

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
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = 6
	return sb

func _style_btn(b: Button, primary := true) -> void:
	var base := Color(0.16, 0.42, 0.60) if primary else Color(0.16, 0.17, 0.24)
	var dark := Color(0.10, 0.28, 0.42) if primary else Color(0.35, 0.38, 0.5)
	b.add_theme_stylebox_override("normal", _sb(base, dark, 16, 2))
	b.add_theme_stylebox_override("hover", _sb(base.lightened(0.08), dark, 16, 2))
	b.add_theme_stylebox_override("pressed", _sb(dark, dark, 16, 2))
	b.add_theme_stylebox_override("disabled", _sb(Color(0.2, 0.2, 0.26), Color(0.4, 0.4, 0.5), 16, 2))
	var fg := Color(0.96, 0.97, 1.0)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_focus_color", fg)
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	b.add_theme_color_override("font_disabled_color", Color(0.55, 0.55, 0.62))

## گیج سرعت — قوس + عقربه، حس داشبورد
class SpeedGauge extends Control:
	var game: Node2D
	var frac := 0.0

	func _process(_delta: float) -> void:
		if game == null:
			return
		var tgt: float = clampf(absf(game.vel.length()) / (game.max_s * 1.45), 0.0, 1.0)
		frac = lerpf(frac, tgt, _delta * 8.0)
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		c.y = size.y * 0.86
		var r := minf(size.x * 0.46, size.y * 0.8)
		var a0 := PI * 0.78
		var a1 := PI * 2.22
		draw_arc(c, r, a0, a1, 40, Color(0.1, 0.1, 0.16, 0.85), 14.0, true)
		var ac := Color(0.25, 0.75, 1.0).lerp(Color(1.0, 0.35, 0.15), frac)
		if frac > 0.02:
			draw_arc(c, r, a0, a0 + (a1 - a0) * frac, 40, ac, 14.0, true)
		var na := a0 + (a1 - a0) * frac
		var tip := c + Vector2(cos(na), sin(na)) * (r - 18.0)
		draw_line(c, tip, Color(0.95, 0.95, 1.0, 0.9), 4.0, true)
		draw_circle(c, 8.0, Color(0.85, 0.85, 0.95, 0.95))

## خطوط سرعت نیترو
class SpeedLines extends Control:
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		if visible:
			queue_redraw()

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(t * 24.0)
		for i in 18:
			var y := rng.randf_range(70.0, 640.0)
			var x := rng.randf_range(-60.0, 1020.0)
			var ln := rng.randf_range(120.0, 320.0)
			var hdir := 1.0 if x < 500.0 else -1.0
			draw_line(Vector2(x, y), Vector2(x + ln * hdir, y), Color(0.7, 0.85, 1.0, 0.13), 3.0)
