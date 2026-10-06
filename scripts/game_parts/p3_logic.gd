
# ─────────────────────────── ورودی ───────────────────────────
func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed:
		if e.keycode == KEY_LEFT or e.keycode == KEY_A:
			steer_left = true
		elif e.keycode == KEY_RIGHT or e.keycode == KEY_D:
			steer_right = true
		elif e.keycode == KEY_DOWN or e.keycode == KEY_S:
			brake_held = true
		elif e.keycode == KEY_SPACE or e.keycode == KEY_X or e.keycode == KEY_UP:
			nitro_held = true
	if e is InputEventKey and not e.pressed:
		if e.keycode == KEY_LEFT or e.keycode == KEY_A:
			steer_left = false
		elif e.keycode == KEY_RIGHT or e.keycode == KEY_D:
			steer_right = false
		elif e.keycode == KEY_DOWN or e.keycode == KEY_S:
			brake_held = false
		elif e.keycode == KEY_SPACE or e.keycode == KEY_X or e.keycode == KEY_UP:
			nitro_held = false

func _toggle_pause() -> void:
	if ended and not racing_over:
		return
	var t := get_tree()
	t.paused = not t.paused
	if pause_overlay != null:
		pause_overlay.visible = t.paused
	AudioMgr.set_engine(not t.paused, 0.3)
	AudioMgr.set_skid(false)

# ─────────────────────────── حلقه اصلی ───────────────────────────
func _process(delta: float) -> void:
	if get_tree().paused:
		return
	elapsed += delta

	# شمارش معکوس — موتور زنده است، دنیا نفس نگه می‌دارد
	if intro > 0.0 and not racing_over:
		intro -= delta
		var stage := int((2.6 - maxf(intro, 0.0)) / 0.65)
		if stage != _intro_stage and stage <= 4:
			_intro_stage = stage
			if stage < 3:
				intro_label.text = fa(3 - stage)
				AudioMgr.play_sfx("beep")
			else:
				intro_label.text = Globals.L("go")
				AudioMgr.play_sfx("horn")
				intro_label.add_theme_color_override("font_color", Color(0.3, 0.95, 0.5))
				cam.zoom = Vector2(1.18, 1.18)
			intro_label.pivot_offset = Vector2(get_viewport_rect().size.x * 0.5, 95.0)
			intro_label.scale = Vector2(1.6, 1.6)
			intro_label.modulate.a = 1.0
			var itw := create_tween()
			itw.tween_property(intro_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			itw.parallel().tween_property(intro_label, "modulate:a", 0.0, 0.4).set_delay(0.25)
		if intro <= 0.0:
			intro_label.visible = false
		AudioMgr.set_engine(true, clampf(0.85 - intro * 0.3, 0.15, 0.85))
		cam.zoom = cam.zoom.lerp(Vector2(1.05, 1.05), delta * 2.0)
		_update_rivals(delta)
		return

	if autotest:
		_run_autotest(delta)

	_update_player(delta)
	_update_rivals(delta)
	_update_traffic(delta)
	_update_coins(delta)
	_update_hud(delta)
	_update_camera(delta)
	_update_brain_anchor()

	if shake > 0.0:
		shake = maxf(0.0, shake - delta * 26.0)
		cam.offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	else:
		cam.offset = Vector2.ZERO

# ─────────────────────────── فیزیک بازیکن ───────────────────────────
func _update_player(delta: float) -> void:
	if racing_over:
		# بعد خط پایان — ماشین آروم می‌ایستد، دنیا زنده می‌ماند
		vel *= exp(-1.6 * delta)
		car_pos += vel * delta
		car.position = car_pos
		AudioMgr.set_engine(false)
		AudioMgr.set_skid(false)
		return

	var fwd := Vector2.RIGHT.rotated(heading)
	var vf := vel.dot(fwd)
	var vl := vel - fwd * vf

	# فرمان
	var steer := 0.0
	if steer_left:
		steer -= 1.0
	if steer_right:
		steer += 1.0
	var sn := clampf(vf / max_s, -1.0, 1.0)

	# دریفت: ترمز + فرمان در سرعت، یا پیچ تند نزدیک سرعت ماکزیمم
	var want_drift := (brake_held and absf(vf) > 250.0 and absf(steer) > 0.2) \
		or (absf(steer) > 0.85 and absf(vf) > 0.78 * max_s)
	if want_drift != drifting:
		drifting = want_drift
		if drifting:
			AudioMgr.set_skid(true, 0.7)

	# نیترو
	nitro_on = nitro_held and nitro_meter > 0.02 and not brake_held
	if nitro_on:
		nitro_meter = maxf(0.0, nitro_meter - nitro_drain * delta)
		if not lines.visible:
			AudioMgr.play_sfx("nitro")
	else:
		nitro_meter = minf(1.0, nitro_meter + delta * (0.10 if drifting else 0.012))

	# شتاب خودکار (کلاچی: گاز خودشه) — ترمز کاربر برنده است
	var target := max_s * (NITRO_MULT if nitro_on else 1.0)
	if brake_held and not drifting:
		vf = move_toward(vf, 0.0, BRK * delta)
	else:
		var acc := ACC * (2.2 if nitro_on else 1.0)
		vf = move_toward(vf, target, acc * delta)

	# آفساید — چمن/بلوک شهری کند می‌کند
	var nr := _nearest(car_pos)
	offroad = nr["dist"] > ROAD_W * 0.5 - 6.0
	if offroad:
		vf *= exp(-2.4 * delta)
		shake = maxf(shake, 1.6)

	# چرخش — سرعت‌محور؛ در دریفت فرمان بازتر
	var turn := TURN_RATE * sn * (1.35 if drifting else 1.0)
	heading += steer * turn * delta

	# گریپ جانبی — قلب دریفت
	var grip := DRIFT_GRIP if drifting else GRIP
	vl *= exp(-grip * delta)
	vel = fwd * vf + vl
	car_pos += vel * delta

	# برخورد با ساختمان‌ها
	_resolve_buildings()

	# محدوده دنیا
	var clamped := Vector2(
		clampf(car_pos.x, WORLD_MIN.x, WORLD_MAX.x),
		clampf(car_pos.y, WORLD_MIN.y, WORLD_MAX.y))
	if clamped != car_pos:
		car_pos = clamped
		vel *= 0.5

	# برخورد با ترافیک و رقیب‌ها
	_car_contacts(delta)

	# مسافت روی پیست + دور
	var new_s: float = _nearest(car_pos)["s"]
	var prev := path_s
	path_s = new_s
	if prev > track_len * 0.85 and path_s < track_len * 0.15 and vf > 0.0:
		lap += 1
		if lap < LAPS:
			AudioMgr.play_sfx("lap")
		else:
			_cross_finish()
	elif prev < track_len * 0.15 and path_s > track_len * 0.85 and vf < 0.0:
		lap -= 1

	# رد لاستیک + دود دریفت
	if drifting and absf(vf) > 120.0:
		_mark_t -= delta
		if _mark_t <= 0.0:
			_mark_t = 0.024
			var back := car_pos - fwd * 48.0
			var nrm := Vector2(-fwd.y, fwd.x)
			marks.add(back + nrm * 22.0, heading)
			marks.add(back - nrm * 22.0, heading)
	if smoke != null:
		smoke.emitting = drifting and absf(vf) > 140.0
	# جیغ لاستیک متناسب با لغزش
	var slip := (DRIFT_GRIP if drifting else GRIP)
	var skid_amt := clampf(1.0 - (grip / GRIP) + (vl.length() / 240.0), 0.0, 1.0)
	AudioMgr.set_skid(drifting and absf(vf) > 100.0, skid_amt)

	# صدا + افکت
	AudioMgr.set_engine(true, clampf(absf(vf) / max_s, 0.12, 1.0) * (1.12 if nitro_on else 1.0))
	if flame != null:
		flame.emitting = nitro_on
	if lines != null:
		lines.visible = nitro_on

	# اعمال به نود
	car.position = car_pos
	car.rotation = heading
	# لِن ضربه‌ای
	if elapsed < invuln_until:
		car_sprite.modulate = Color(1.0, 0.6, 0.55, 0.9)
	else:
		car_sprite.modulate = Color(1, 1, 1)

func _resolve_buildings() -> void:
	for b in buildings:
		var sz: Vector2 = b["size"]
		var loc := (car_pos - b["pos"]).rotated(-float(b["rot"]))
		var hx := sz.x * 0.5 + 20.0
		var hy := sz.y * 0.5 + 20.0
		if absf(loc.x) < hx and absf(loc.y) < hy:
			var px := hx - absf(loc.x)
			var py := hy - absf(loc.y)
			var push := Vector2.ZERO
			if px < py:
				push = Vector2(signf(loc.x) * px, 0)
			else:
				push = Vector2(0, signf(loc.y) * py)
			car_pos += push.rotated(float(b["rot"]))
			if elapsed > bump_cd:
				bump_cd = elapsed + 0.5
				vel *= 0.42
				shake = 7.0
				AudioMgr.play_sfx("crash")

func _car_contacts(_delta: float) -> void:
	for R in rivals:
		var rp: Vector2 = R["node"].position
		var d := car_pos.distance_to(rp)
		if d < 76.0 and d > 0.01:
			var push := (car_pos - rp).normalized() * (76.0 - d) * 0.6
			car_pos += push
			vel *= 0.985
	for i in traffic.size():
		var T = traffic[i]
		var tp: Vector2 = T["node"].position
		if car_pos.distance_to(tp) < 74.0 and elapsed > invuln_until:
			invuln_until = elapsed + 1.1
			vel *= 0.34
			shake = 10.0
			AudioMgr.play_sfx("crash")
			T["spd"] *= 0.4
			T["lane"] += (30.0 if T["lane"] > 0 else -30.0)

func _cross_finish() -> void:
	if racing_over:
		return
	racing_over = true
	finish_rank = _calc_rank()
	if not ended:
		ended = true
		var stars := clampi(4 - finish_rank, 0, 3)
		var win := finish_rank <= 2
		var reward := 0
		if win:
			var bonus: int = [60, 25, 10, 0][finish_rank - 1]
			reward = int(lv["reward"]) + stars * 25 + bonus
			Globals.add_coins(reward)
			Globals.set_stars(int(lv["id"]), stars)
			AudioMgr.play_sfx("win")
		else:
			AudioMgr.play_sfx("fail")
		_celebrate(win)
		var w := win
		var s := stars
		var r := reward
		get_tree().create_timer(2.6).timeout.connect(func(): _show_end(w, s, r))

func _calc_rank() -> int:
	var my_prog := float(lap) * track_len + path_s
	var rank := 1
	for R in rivals:
		if float(R["s"]) > my_prog:
			rank += 1
	return rank

# ─────────────────────────── رقیب‌ها ───────────────────────────
func _update_rivals(delta: float) -> void:
	var racing := not racing_over and intro <= 0.0
	for R in rivals:
		var s: float = R["s"]
		if racing:
			# سرعت پایه + کش‌وسان: عقب بماند جانی می‌گیرد
			var base := max_s * float(R["pace"])
			var my_prog := float(lap) * track_len + path_s
			var gap := my_prog - s
			if gap > 600.0:
				base *= 1.15
			elif gap < -500.0:
				base *= 0.9
			# پیچ — از قبل کند می‌کند
			var d1 := _path_dir(s + 90.0)
			var d2 := _path_dir(s + 300.0)
			var ang := absf(d1.angle_to(d2))
			var cs := 1.0 - clampf(ang * 0.62, 0.0, 0.44)
			R["corner"] = ang > 0.3
			R["spd"] = lerpf(float(R["spd"]), base * cs, delta * 2.0)
			s += float(R["spd"]) * delta
			R["s"] = s
			# لاین — نرم تغییر می‌کند
			R["lane_cur"] = lerpf(float(R["lane_cur"]), float(R["lane"]), delta * 1.2)
		var dd := _path_dir(s)
		var nn := Vector2(-dd.y, dd.x)
		var pos := _path_pos(s) + nn * float(R["lane_cur"])
		R["node"].position = pos
		var ta := dd.angle()
		R["node"].rotation = lerp_angle(float(R["node"].rotation), ta, delta * 6.0)
		R["ang"] = absf(dd.angle_to(Vector2.RIGHT.rotated(float(R["node"].rotation))))
		# رد لاستیک رقیب در پیچ تند
		if racing and bool(R["corner"]) and float(R["spd"]) > 300.0:
			_mark_t -= delta * 0.5
			if _mark_t <= 0.0:
				var back := pos - dd * 44.0
				marks.add(back + nn * 20.0, ta)
				marks.add(back - nn * 20.0, ta)
	if pos_label != null:
		var rk := _calc_rank() if not racing_over else finish_rank
		pos_label.text = fa(rk) + "/" + fa(rivals.size() + 1)
	if lap_label != null:
		var shown := mini(lap + 1, LAPS)
		lap_label.text = "دور " + fa(shown) + "/" + fa(LAPS)

# ─────────────────────────── ترافیک ───────────────────────────
func _update_traffic(delta: float) -> void:
	var racing := not racing_over and intro <= 0.0
	_spawn_traf_t -= delta
	if racing and _spawn_traf_t <= 0.0 and traffic.size() < 7:
		_spawn_traf_t = randf_range(0.9, 1.6)
		var my_prog := float(lap) * track_len + path_s
		_spawn_traffic(my_prog + randf_range(1100.0, 2400.0))
	for i in range(traffic.size() - 1, -1, -1):
		var T = traffic[i]
		if racing:
			T["s"] += float(T["dir"]) * float(T["spd"]) * delta
		var my_prog2 := float(lap) * track_len + path_s
		if absf(float(T["s"]) - my_prog2) > 2800.0:
			T["node"].queue_free()
			traffic.remove_at(i)
			continue
		var ss: float = fposmod(float(T["s"]), track_len)
		var dd := _path_dir(ss) * float(T["dir"])
		var nn := Vector2(-dd.y, dd.x)
		T["node"].position = _path_pos(ss) + nn * float(T["lane"])
		T["node"].rotation = dd.angle()

func _update_coins(delta: float) -> void:
	var racing := not racing_over and intro <= 0.0
	_spawn_coin_t -= delta
	if racing and _spawn_coin_t <= 0.0 and coins_on_road.size() < 34:
		_spawn_coin_t = randf_range(0.8, 1.4)
		var my_prog := float(lap) * track_len + path_s
		_spawn_coins(my_prog + randf_range(900.0, 2000.0))
	for i in range(coins_on_road.size() - 1, -1, -1):
		var C = coins_on_road[i]
		C["t"] = float(C["t"]) + delta * 5.0
		var spr: Sprite2D = C["node"].get_child(0)
		spr.scale = Vector2(0.42, 0.42) * (1.0 + 0.1 * sin(float(C["t"])))
		var my_prog2 := float(lap) * track_len + path_s
		if float(C["pos"].x) == 0.0 or absf(_nearest(C["pos"])["s"] - my_prog2) > 2400.0:
			C["node"].queue_free()
			coins_on_road.remove_at(i)
			continue
		if racing and car_pos.distance_to(C["pos"]) < 64.0:
			coins_got += 1
			nitro_meter = minf(1.0, nitro_meter + 0.05)
			AudioMgr.play_sfx("coin")
			C["node"].queue_free()
			coins_on_road.remove_at(i)

# ─────────────────────────── HUD و دوربین ───────────────────────────
func _update_hud(delta: float) -> void:
	coin_label.text = "سکه " + fa(coins_got) + ((" / " + fa(target_coins)) if target_coins > 0 else "")
	if time_left < 900.0:
		time_left -= delta
		time_label.text = "زمان " + fa(maxi(0, int(ceil(time_left))))
		if time_left <= 0.0 and not racing_over:
			racing_over = true
			ended = true
			AudioMgr.set_engine(false)
			AudioMgr.play_sfx("fail")
			_celebrate(false)
			get_tree().create_timer(1.4).timeout.connect(func(): _show_end(false, 0, 0))
	else:
		time_label.text = ""
	var total := float(lap) * track_len + path_s
	progress.value = 100.0 * clampf(total / (float(LAPS) * track_len), 0.0, 1.0)
	nitro_bar.value = nitro_meter * 100.0
	var vf := absf(vel.dot(Vector2.RIGHT.rotated(heading)))
	kmh_label.text = fa(int(vf * 0.21))

func _update_camera(delta: float) -> void:
	var look := car_pos + vel * 0.30
	cam.position = cam.position.lerp(look, delta * 5.0)
	if cam.position.distance_to(look) > 400.0:
		cam.position = look
	var zt := 1.05 - clampf(vel.length() / (max_s * 1.5), 0.0, 1.0) * 0.18
	if nitro_on:
		zt -= 0.04
	cam.zoom = cam.zoom.lerp(Vector2(zt, zt), delta * 2.5)

func _update_brain_anchor() -> void:
	if car_anchor != null:
		var sp: Vector2 = car.get_global_transform_with_canvas().origin
		car_anchor.position = sp + Vector2(0.0, -120.0)

# ─────────────────────────── پایان و جشن ───────────────────────────
func _celebrate(win: bool) -> void:
	AudioMgr.set_skid(false)
	for i in 3:
		var c := CPUParticles2D.new()
		c.position = car_pos + Vector2(-200 + i * 200.0, -100.0)
		c.emitting = false
		c.amount = 40
		c.lifetime = 3.0
		c.direction = Vector2(0, 1)
		c.spread = 50.0
		c.gravity = Vector2(0, 260)
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
		world.add_child(c)
		c.emitting = win
	if brain != null and car_anchor != null:
		var my_id := str(Globals.CARS[Globals.selected_car]["id"])
		brain.say(car_anchor, my_id, "win" if win else "lose")

func _show_end(win: bool, stars: int, reward: int) -> void:
	end_panel = PanelContainer.new()
	end_panel.add_theme_stylebox_override("panel", _sb(Color(0.11, 0.12, 0.17), Color(0.85, 0.68, 0.28, 0.6), 24, 3))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	end_panel.add_child(vb)
	end_title = Label.new() if false else Label.new()
	end_title.text = ("قهرمان خیابان!" if finish_rank == 1 else Globals.L("win")) if win else Globals.L("lose")
	end_title.add_theme_font_override("font", load("res://assets/fonts/Vazirmatn-Bold.ttf"))
	end_title.add_theme_color_override("font_color", Color(0.98, 0.85, 0.3))
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
	end_reward.text = Globals.L("reward") + ": " + fa(reward) + " سکه  •  " + Globals.L("pos") + " " + fa(finish_rank) + "/" + fa(rivals.size() + 1)
	end_reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_reward.add_theme_font_size_override("font_size", 26)
	end_reward.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	vb.add_child(end_reward)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 14)
	end_retry_btn = Button.new()
	end_retry_btn.text = Globals.L("retry")
	end_retry_btn.add_theme_font_override("font", load("res://assets/fonts/Vazirmatn-Bold.ttf"))
	end_retry_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game.tscn"))
	_style_btn(end_retry_btn, true)
	hb.add_child(end_retry_btn)
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
	end_menu_btn = b_menu
	vb.add_child(hb)
	hud.add_child(end_panel)
	_place(end_panel, 0.5, 0.5, 0.5, 0.5, -270, -175, 270, 135)
	end_panel.custom_minimum_size = Vector2(540, 310)
	end_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	end_panel.grow_vertical = Control.GROW_DIRECTION_BOTH

func _exit_tree() -> void:
	AudioMgr.set_engine(false)
	AudioMgr.set_skid(false)

# ─────────────────────────── تست خودکار ───────────────────────────
func _run_autotest(delta: float) -> void:
	_auto_timer += delta
	match _at_stage:
		0:
			if _auto_timer > 0.6:
				_at_stage = 1
				_at_heading0 = heading
				_press_at(Vector2(VIEW_W * 0.85, VIEW_H * 0.72)) # زون فرمان راست — نگه‌داشته
		1:
			if _auto_timer > 1.5:
				_at_stage = 2
				_release_at(Vector2(VIEW_W * 0.85, VIEW_H * 0.72))
				var turned := absf(angle_difference(_at_heading0, heading))
				print("[boghi][autotest] STEER-RIGHT ", "OK" if turned > 0.12 else "FAIL turned=" + str(turned))
				if turned <= 0.12:
					get_tree().quit(1)
		2:
			if _auto_timer > 1.7:
				_at_stage = 3
				_press_at(Vector2(VIEW_W - 380.0, VIEW_H - 120.0)) # دکمه نیترو
		3:
			if _auto_timer > 2.6:
				_at_stage = 4
				_release_at(Vector2(VIEW_W - 380.0, VIEW_H - 120.0))
				print("[boghi][autotest] NITRO ", "OK" if nitro_meter < 0.98 else "FAIL")
				if nitro_meter >= 0.98:
					get_tree().quit(1)
		4:
			if _auto_timer > 3.6 and _at_stage == 4:
				_at_stage = 5
				var img := get_viewport().get_texture().get_image()
				if img != null:
					img.save_png("/home/z/my-project/scripts/shot_game.png")
		5:
			if _auto_timer > 5.2:
				var nr: Dictionary = _nearest(car_pos)
				print("AUTOTEST OK lap=", lap, " pos=", car_pos.round(), " spd=", int(vel.length()), " off=", nr["dist"] < ROAD_W * 0.5, " rank=", _calc_rank(), " rivals=", rivals.size(), " traf=", traffic.size())
				get_tree().quit()

func _press_at(pos: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	ev.position = pos
	ev.global_position = pos
	Input.parse_input_event(ev)

func _release_at(pos: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	ev.position = pos
	ev.global_position = pos
	Input.parse_input_event(ev)

func _tap(btn: Button) -> void:
	_press_at(btn.get_global_rect().get_center())
	_release_at(btn.get_global_rect().get_center())

func _tap_at(pos: Vector2) -> void:
	_press_at(pos)
	_release_at(pos)

## تست چرخه کامل: توقف → ادامه → خط پایان سریع → پنل → دوباره → منو
func _autotest_full() -> void:
	await get_tree().create_timer(2.8).timeout # بعد از ۳-۲-۱-برو
	_tap(pause_btn)
	await get_tree().create_timer(0.3).timeout
	var p1: bool = get_tree().paused
	_tap(pause_btn)
	await get_tree().create_timer(0.3).timeout
	var p2: bool = get_tree().paused
	print("[boghi][autotest] TAP-PAUSE ", "OK" if (p1 and not p2) else "FAIL")
	if not (p1 and not p2):
		get_tree().quit(1)
		return
	# پرش به انتهای دور آخر
	lap = LAPS - 1
	path_s = track_len * 0.96
	car_pos = _path_pos(path_s)
	vel = _path_dir(path_s) * max_s
	await get_tree().create_timer(5.4).timeout
	if end_panel == null or end_retry_btn == null or end_menu_btn == null:
		print("[boghi][autotest] END-PANEL FAIL")
		get_tree().quit(1)
		return
	print("[boghi][autotest] END-PANEL OK")
	var img := get_viewport().get_texture().get_image()
	if img != null:
		img.save_png("/home/z/my-project/scripts/shot_end_panel.png")
	if not Globals.has_meta("at_retry"):
		Globals.set_meta("at_retry", 1)
		_tap(end_retry_btn)
		return # صحنه دوباره لود می‌شود؛ نسخه جدید ادامه می‌دهد
	Globals.set_meta("at_menu_return", true)
	_tap(end_menu_btn)
	await get_tree().create_timer(3.0).timeout
	print("[boghi][autotest] TAP-ENDMENU FAIL (منو لود نشد)")
	get_tree().quit(1)

# ─────────────────────────── ابزار ───────────────────────────
func fa(n: int) -> String:
	var s := str(n)
	var out := ""
	for ch in s:
		if ch >= "0" and ch <= "9":
			out += FA_D[int(ch)]
		else:
			out += ch
	return out
