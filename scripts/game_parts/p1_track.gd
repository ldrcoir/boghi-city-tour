extends Node2D
## بوقی — مسابقه خیابانی شبانه از بالا (سبک کلاچ/NFS)
## نه بازی کودکانه، نه پرش روی مخروط — فرمان، دریفت، نیترو، ترافیک، رقیب.
## دوربین بالا؛ ماشین با فیزیک واقعی (گریپ لغزنده + دریفت دست‌برقه).

const VIEW_W := 1280.0
const VIEW_H := 720.0
const ROAD_W := 260.0
const LAPS := 2

# فیزیک ماشین
const ACC := 350.0
const BRK := 800.0
const TURN_RATE := 2.55
const GRIP := 9.0
const DRIFT_GRIP := 2.25
const NITRO_MULT := 1.40

# پیست — حلقه‌ی شهری با گوشه‌های پخ (بسته)
const WPS := [
	Vector2(1215, 1215), Vector2(4320, 1215), Vector2(5130, 2025), Vector2(5130, 3645),
	Vector2(4320, 4455), Vector2(2025, 4455), Vector2(1215, 3645), Vector2(1215, 2025),
]
const WORLD_MIN := Vector2(360, 360)
const WORLD_MAX := Vector2(5980, 5300)

const FA_D := "۰۱۲۳۴۵۶۷۸۹"
const RIVAL_POOL := ["pride_blue", "pejo_green", "shahin", "samand", "dena", "quick"]
const NEON_COLS := [
	Color(0.25, 0.85, 1.0), Color(1.0, 0.55, 0.25), Color(1.0, 0.35, 0.55),
	Color(0.55, 1.0, 0.55), Color(1.0, 0.85, 0.3), Color(0.7, 0.5, 1.0),
]

var lv: Dictionary
var elapsed := 0.0
var ended := false
var racing_over := false
var autotest := false
var autotest_full := false

# مسیر
var seg_a: Array = []      # نقطه شروع هر سگمنت
var seg_d: Array = []      # جهت هر سگمنت
var seg_len: Array = []
var cum: Array = []        # طول تجمعی
var track_len := 0.0
var buildings: Array = []  # {pos, rot, size, neon, wins}
var lamps: Array = []      # {pos}

# بازیکن
var car_pos := Vector2.ZERO
var vel := Vector2.ZERO
var heading := 0.0
var path_s := 0.0          # تصویر موقعیت روی پیست
var lap := 0
var max_s := 620.0
var drifting := false
var nitro_on := false
var nitro_meter := 1.0
var nitro_drain := 0.30
var steer_left := false
var steer_right := false
var brake_held := false
var nitro_held := false
var offroad := false
var invuln_until := 0.0
var bump_cd := 0.0
var coins_got := 0
var target_coins := -1
var time_left := 90.0
var shake := 0.0

# رقیب‌ها و ترافیک
var rivals: Array = []     # {node, spr, s, spd, pace, lane, lane_cur, ang, corner}
var traffic: Array = []    # {node, spr, s, dir, spd, lane}
var coins_on_road: Array = []  # {node, pos}
var finish_rank := 1

# نودها
var world: Node2D
var track_node: Node2D
var marks: Node2D
var car: Node2D
var car_sprite: Sprite2D
var cam: Camera2D
var hud: CanvasLayer
var coin_label: Label
var time_label: Label
var mission_label: Label
var pos_label: Label
var lap_label: Label
var kmh_label: Label
var nitro_bar: ProgressBar
var progress: ProgressBar
var gauge: Control
var flame: CPUParticles2D
var smoke: CPUParticles2D
var lines: Control
var intro_label: Label
var pause_btn: Button
var pause_overlay: Control
var end_panel: PanelContainer
var end_retry_btn: Button
var end_menu_btn: Button
var brain = null
var car_anchor: Control
var _intro_stage := -1
var intro := 2.6
var _auto_timer := 0.0
var _at_stage := 0
var _at_heading0 := 0.0
var _spawn_coin_t := 0.0
var _spawn_traf_t := 0.4
var _mark_t := 0.0

const BRAIN_SCRIPT := preload("res://scripts/car_brain.gd")

func _ready() -> void:
	autotest = OS.get_cmdline_user_args().has("--autotest")
	autotest_full = OS.get_cmdline_user_args().has("--autotest-full")
	if autotest_full and Globals.has_meta("at_retry"):
		print("[boghi][autotest] TAP-RETRY OK — بازی دوباره لود شد")
	var lid: int = Globals.get_meta("start_level", 1)
	if Globals.has_meta("custom_level"):
		lv = Globals.get_meta("custom_level")
		Globals.remove_meta("custom_level")
	else:
		lv = Globals.get_level(lid)
	if lv.is_empty():
		lv = {"id": 1, "type": "race", "name": "تست", "speed": 14.0, "distance": 500,
			"time": 90, "obstacle_rate": 0.4, "coin_rate": 0.8, "ramp_rate": 0.3, "reward": 50}
	var stats: Dictionary = Globals.car_stats()
	max_s = 620.0 * clampf(float(stats["accel"]), 0.85, 1.45)
	nitro_drain = 0.34 / maxf(0.8, float(stats["turbo"]))
	time_left = maxf(float(lv["time"]) * 1.5, 80.0)
	if lv["type"] == "collect":
		target_coins = int(lv.get("target_coins", 10))
	_build_track()
	_build_world()
	_build_car(stats)
	_build_hud()
	_spawn_rivals()
	AudioMgr.play_music()
	brain = BRAIN_SCRIPT.new()
	add_child(brain)
	car_anchor = Control.new()
	car_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	car_anchor.size = Vector2.ZERO
	hud.add_child(car_anchor)
	mission_label.text = Globals.L("mission") + " " + fa(int(lv["id"])) + ": " + str(lv["name"])
	var mtw := create_tween()
	mtw.tween_interval(5.0)
	mtw.tween_property(mission_label, "modulate:a", 0.0, 0.8)
	if autotest or autotest_full:
		time_left = 9999.0
	if autotest_full:
		_autotest_full()

# ─────────────────────────── ریاضی مسیر ───────────────────────────
func _build_track() -> void:
	var n := WPS.size()
	cum = [0.0]
	for i in n:
		var a: Vector2 = WPS[i]
		var b: Vector2 = WPS[(i + 1) % n]
		var d := (b - a)
		var l := d.length()
		seg_a.append(a)
		seg_d.append(d / l)
		seg_len.append(l)
		cum.append(cum[i] + l)
	track_len = cum[n]

func _path_pos(s: float) -> Vector2:
	var ss := fposmod(s, track_len)
	for i in seg_a.size():
		if ss <= cum[i + 1] + 0.001:
			return seg_a[i] + seg_d[i] * (ss - cum[i])
	return seg_a[0]

func _path_dir(s: float) -> Vector2:
	var ss := fposmod(s, track_len)
	for i in seg_a.size():
		if ss <= cum[i + 1] + 0.001:
			return seg_d[i]
	return seg_d[0]

## نزدیک‌ترین نقطه پیست + فاصله از آن (برای آفساید)
func _nearest(p: Vector2) -> Dictionary:
	var best_s := 0.0
	var best_d := INF
	for i in seg_a.size():
		var rel: Vector2 = p - seg_a[i]
		var t: float = clampf(rel.dot(seg_d[i]), 0.0, seg_len[i])
		var q: Vector2 = seg_a[i] + seg_d[i] * t
		var d := p.distance_to(q)
		if d < best_d:
			best_d = d
			best_s = cum[i] + t
	return {"s": best_s, "dist": best_d}

# ─────────────────────────── ساخت دنیا ───────────────────────────
func _build_world() -> void:
	world = Node2D.new()
	add_child(world)
	var cm := CanvasModulate.new()
	cm.color = Color(0.86, 0.87, 1.0)
	world.add_child(cm)
	track_node = TrackNode.new()
	track_node.game = self
	world.add_child(track_node)
	marks = SkidMarks.new()
	marks.z_index = 1
	world.add_child(marks)
	_gen_city()
	track_node.queue_redraw()

func _gen_city() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261013
	var step := 330.0
	for i in seg_a.size():
		var d: Vector2 = seg_d[i]
		var nrm := Vector2(-d.y, d.x)
		var s := 240.0
		var side := 1.0 if i % 2 == 0 else -1.0
		while s < seg_len[i] - 200.0:
			var s_abs: float = cum[i] + s
			if s_abs > 420.0 and s_abs < track_len - 420.0:
				var off: float = ROAD_W * 0.5 + 95.0 + rng.randf() * 110.0
				var pos: Vector2 = seg_a[i] + d * s + nrm * off * side
				var sz := Vector2(180.0 + rng.randf() * 170.0, 160.0 + rng.randf() * 140.0)
				var rot: float = d.angle() + rng.randf_range(-0.14, 0.14)
				var neon: Color = NEON_COLS[rng.randi_range(0, NEON_COLS.size() - 1)]
				# پنجره‌های نئون از پیش محاسبه می‌شوند (رسم ارزان)
				var wins: Array = []
				var cols := int(sz.x / 44.0)
				var rows := int(sz.y / 40.0)
				for wy in rows:
					for wx in cols:
						if rng.randf() < 0.62:
							var lp := Vector2(-sz.x * 0.5 + 22.0 + wx * 44.0, -sz.y * 0.5 + 20.0 + wy * 40.0)
							wins.append(lp)
				buildings.append({"pos": pos, "rot": rot, "size": sz, "neon": neon, "wins": wins})
			s += step
			side *= -1.0 if rng.randf() < 0.25 else 1.0
	# تیر چراغ خیابان — هاله‌ی گرم لبه‌ی جاده
	var ls := 0.0
	while ls < track_len:
		var dd: Vector2 = _path_dir(ls)
		var nn := Vector2(-dd.y, dd.x)
		var sgn := 1.0 if int(ls / 640.0) % 2 == 0 else -1.0
		lamps.append({"pos": _path_pos(ls) + nn * (ROAD_W * 0.5 + 18.0) * sgn})
		ls += 640.0

## نود رسم پیست و شهر — استاتیک، یک‌بار رسم
class TrackNode extends Node2D:
	var game: Node2D

	func _draw() -> void:
		var g := game
		# زمین شب
		draw_rect(Rect2(Vector2(200, 200), Vector2(6200, 5500)), Color(0.055, 0.06, 0.10))
		# آسفالت — هر سگمنت یک خط ضخیم (سرهای گرد گوشه‌ها را می‌بندد)
		for i in g.seg_a.size():
			draw_line(g.seg_a[i], g.seg_a[i] + g.seg_d[i] * g.seg_len[i], Color(0.125, 0.125, 0.155), g.ROAD_W, true)
		# لبه‌های زرد کم‌رنگ
		for i in g.seg_a.size():
			var d: Vector2 = g.seg_d[i]
			var nn := Vector2(-d.y, d.x) * (g.ROAD_W * 0.5 - 8.0)
			draw_line(g.seg_a[i] + nn, g.seg_a[i] + g.seg_d[i] * g.seg_len[i] + nn, Color(0.85, 0.72, 0.22, 0.42), 5.0, true)
			draw_line(g.seg_a[i] - nn, g.seg_a[i] + g.seg_d[i] * g.seg_len[i] - nn, Color(0.85, 0.72, 0.22, 0.42), 5.0, true)
		# خط‌چین وسط
		var ss := 0.0
		while ss < g.track_len:
			var a := g._path_pos(ss)
			var dd := g._path_dir(ss)
			draw_line(a, a + dd * 62.0, Color(0.92, 0.92, 0.95, 0.26), 4.0, true)
			ss += 128.0
		# خط شروع/پایان — شطرنجی
		var st := g._path_pos(0.0)
		var sd := g._path_dir(0.0)
		var sn := Vector2(-sd.y, sd.x)
		for row in 2:
			for c in 8:
				var cell := 30.0
				var p := st + sn * (-g.ROAD_W * 0.5 + c * 32.5 + 4.0) + sd * (row * cell)
				var col := Color(0.92, 0.92, 0.92, 0.85) if (row + c) % 2 == 0 else Color(0.08, 0.08, 0.1, 0.85)
				var poly := PackedVector2Array([
					p, p + sn * 30.0, p + sn * 30.0 + sd * cell, p + sd * cell,
				])
				draw_colored_polygon(poly, col)
		# هاله‌ی چراغ‌های خیابان
		for L in g.lamps:
			var lp: Vector2 = L["pos"]
			draw_circle(lp, 52.0, Color(1.0, 0.85, 0.55, 0.07))
			draw_circle(lp, 26.0, Color(1.0, 0.88, 0.6, 0.10))
			draw_circle(lp, 5.0, Color(1.0, 0.93, 0.7, 0.85))
		# ساختمان‌های شبانه با پنجره نئون
		for b in g.buildings:
			var sz: Vector2 = b["size"]
			draw_set_transform_matrix(Transform2D(b["rot"], b["pos"]))
			draw_rect(Rect2(-sz * 0.5 - Vector2(6, 6), sz + Vector2(12, 12)), Color(0.02, 0.02, 0.05, 0.55))
			draw_rect(Rect2(-sz * 0.5, sz), Color(0.085, 0.085, 0.125))
			draw_rect(Rect2(-sz * 0.5, sz), Color(0.35, 0.38, 0.5, 0.5), false, 2.0)
			var nc: Color = b["neon"]
			for lp in b["wins"]:
				var wc := nc
				wc.a = 0.34
				draw_rect(Rect2(lp - Vector2(9, 7), Vector2(18, 14)), wc)
			draw_set_transform_matrix(Transform2D())

## رد لاستیک — دریفت واقعی روی آسفالت می‌ماند
class SkidMarks extends Node2D:
	var segs: Array = []  # {pos, ang}
	var MAX := 520

	func add(p: Vector2, ang: float) -> void:
		segs.append({"pos": p, "ang": ang})
		if segs.size() > MAX:
			segs.pop_front()
		queue_redraw()

	func _draw() -> void:
		for s in segs:
			draw_set_transform_matrix(Transform2D(s["ang"], s["pos"]))
			draw_rect(Rect2(-11, -3, 22, 6), Color(0.03, 0.03, 0.05, 0.5))
		draw_set_transform_matrix(Transform2D())
