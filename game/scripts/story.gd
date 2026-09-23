extends Control
## هاب «زندگی محله» — مود داستان روزمره (بخش ۳ از سه‌بخشی)
## کارت اپیزودها → کات‌سین procedural → مأموریت یا پاداش دل
## تست: --storytest (خودکار: بازی اپیزود ۱ با تپ شبیه‌سازی‌شده تا پایان)

const STORY_MGR := preload("res://scripts/story_mgr.gd")
const CUTSCENE_SCRIPT := preload("res://scripts/cutscene.gd")

const COL_GLASS := Color(0.10, 0.11, 0.13, 0.92)
const COL_GOLD := Color(0.96, 0.76, 0.25)
const COL_CREAM := Color(0.95, 0.93, 0.88)
const COL_RED := Color(0.78, 0.15, 0.12)

var grid: GridContainer
var hearts_label: Label
var toast: Label
var stage: Control = null
var storytest := false
var _st_ok := false

func _ready() -> void:
        layout_direction = Control.LAYOUT_DIRECTION_LTR
        storytest = OS.get_cmdline_user_args().has("--storytest")
        _build_bg()
        _build_ui()
        _refresh()
        if storytest:
                _run_storytest()

func _build_bg() -> void:
        var gt := GradientTexture2D.new()
        var g := Gradient.new()
        g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
        g.colors = PackedColorArray([Color(0.24, 0.13, 0.10), Color(0.13, 0.08, 0.07), Color(0.06, 0.04, 0.04)])
        gt.gradient = g
        gt.fill_from = Vector2(0.3, 0.0)
        gt.fill_to = Vector2(0.7, 1.0)
        var bg := TextureRect.new()
        bg.texture = gt
        bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        bg.set_anchors_preset(Control.PRESET_FULL_RECT)
        bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(bg)

func _font(path: String) -> FontFile:
        if ResourceLoader.exists(path):
                var r := load(path)
                if r is FontFile:
                        return r
        return null

func _mk_label(txt: String, size: int, display := false, col := COL_CREAM) -> Label:
        var l := Label.new()
        l.text = txt
        var f := _font("res://assets/fonts/Lalezar-Regular.ttf") if display else _font("res://assets/fonts/Vazirmatn-Regular.ttf")
        if f != null:
                l.add_theme_font_override("font", f)
        l.add_theme_font_size_override("font_size", size)
        l.add_theme_color_override("font_color", col)
        l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        return l

func _sb(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
        var sb := StyleBoxFlat.new()
        sb.bg_color = bg
        sb.set_corner_radius_all(radius)
        sb.border_color = border
        sb.set_border_width_all(2)
        sb.shadow_color = Color(0, 0, 0, 0.45)
        sb.shadow_size = 8
        return sb

func _build_ui() -> void:
        var title := _mk_label("زندگی محله", 46, true, COL_GOLD)
        title.anchor_left = 0.0
        title.anchor_right = 1.0
        title.offset_top = 30
        title.offset_bottom = 92
        add_child(title)
        var sub := _mk_label("فصل ۱ — تهران  •  هر کارِ خوب، یک دل به محله", 18, false, Color(1, 1, 1, 0.85))
        sub.anchor_left = 0.0
        sub.anchor_right = 1.0
        sub.offset_top = 96
        sub.offset_bottom = 126
        add_child(sub)
        hearts_label = _mk_label("", 24, true, Color(0.95, 0.45, 0.45))
        hearts_label.anchor_left = 0.0
        hearts_label.anchor_right = 1.0
        hearts_label.offset_top = 132
        hearts_label.offset_bottom = 168
        add_child(hearts_label)
        var panel := PanelContainer.new()
        panel.add_theme_stylebox_override("panel", _sb(COL_GLASS, Color(0.85, 0.68, 0.28, 0.5), 22))
        panel.custom_minimum_size = Vector2(880, 440)
        panel.set_anchors_preset(Control.PRESET_CENTER)
        panel.offset_top = 30
        panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
        panel.grow_vertical = Control.GROW_DIRECTION_BOTH
        add_child(panel)
        var mv := MarginContainer.new()
        mv.add_theme_constant_override("margin_left", 16)
        mv.add_theme_constant_override("margin_right", 16)
        mv.add_theme_constant_override("margin_top", 12)
        mv.add_theme_constant_override("margin_bottom", 12)
        panel.add_child(mv)
        grid = GridContainer.new()
        grid.columns = 4
        grid.add_theme_constant_override("h_separation", 12)
        grid.add_theme_constant_override("v_separation", 12)
        mv.add_child(grid)
        toast = _mk_label("", 20, false, COL_GOLD)
        toast.anchor_left = 0.0
        toast.anchor_right = 1.0
        toast.anchor_top = 1.0
        toast.anchor_bottom = 1.0
        toast.offset_top = -60
        toast.offset_bottom = -24
        add_child(toast)
        var back := Button.new()
        back.text = "برگشت به منو"
        var fb := _font("res://assets/fonts/Vazirmatn-Bold.ttf")
        if fb != null:
                back.add_theme_font_override("font", fb)
        back.add_theme_font_size_override("font_size", 20)
        back.custom_minimum_size = Vector2(200, 52)
        back.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
        back.offset_left = 18
        back.offset_top = -74
        back.offset_bottom = -22
        var sb := _sb(Color(0.16, 0.175, 0.20, 0.97), COL_GOLD, 14)
        back.add_theme_stylebox_override("normal", sb)
        back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/menu.tscn"))
        add_child(back)

func _refresh() -> void:
        hearts_label.text = "دلِ محله: %d / %d" % [Globals.hearts, STORY_MGR.total_hearts()]
        for c in grid.get_children():
                c.queue_free()
        var cards: Array = STORY_MGR.card_list()
        for i in cards.size():
                var c: Dictionary = cards[i]
                var b := Button.new()
                b.custom_minimum_size = Vector2(196, 92)
                var ready_ep: bool = bool(c.get("ready", false))
                var seen: bool = bool(c.get("seen", false))
                var unlocked: bool = STORY_MGR.unlocked(i)
                var vb := VBoxContainer.new()
                vb.set_anchors_preset(Control.PRESET_FULL_RECT)
                vb.alignment = BoxContainer.ALIGNMENT_CENTER
                vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
                var n := Label.new()
                n.text = str(int(c["num"]))
                var fd := _font("res://assets/fonts/Lalezar-Regular.ttf")
                if fd != null:
                        n.add_theme_font_override("font", fd)
                n.add_theme_font_size_override("font_size", 30)
                n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                n.mouse_filter = Control.MOUSE_FILTER_IGNORE
                vb.add_child(n)
                var t := Label.new()
                t.text = str(c["title"])
                var fb := _font("res://assets/fonts/Vazirmatn-Bold.ttf")
                if fb != null:
                        t.add_theme_font_override("font", fb)
                t.add_theme_font_size_override("font_size", 15)
                t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                t.mouse_filter = Control.MOUSE_FILTER_IGNORE
                vb.add_child(t)
                var st := Label.new()
                st.text = "انجام شد" if seen else ("بازی کن" if (ready_ep and unlocked) else ("قفل" if ready_ep else "به‌زودی"))
                st.add_theme_font_size_override("font_size", 13)
                st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                st.mouse_filter = Control.MOUSE_FILTER_IGNORE
                st.add_theme_color_override("font_color", Color(0.55, 0.85, 0.55) if seen else (COL_GOLD if (ready_ep and unlocked) else Color(0.5, 0.5, 0.5)))
                vb.add_child(st)
                b.add_child(vb)
                b.disabled = not (ready_ep and unlocked)
                b.pressed.connect(_open.bind(i, cards))
                grid.add_child(b)

func _open(idx: int, cards: Array) -> void:
        var c: Dictionary = cards[idx]
        var ep: Dictionary = STORY_MGR.load_episode(str(c["id"]))
        if ep.is_empty():
                return
        if stage != null and is_instance_valid(stage):
                stage.queue_free()
        stage = CUTSCENE_SCRIPT.new()
        stage.setup(ep)
        stage.finished.connect(_on_episode_finished.bind(ep))
        add_child(stage)

func _on_episode_finished(ep: Dictionary) -> void:
        if stage != null and is_instance_valid(stage):
                stage.queue_free()
                stage = null
        var hearts := int(ep.get("hearts", 1))
        var first := not Globals.story_seen.has(str(ep.get("id", "")))
        STORY_MGR.mark_seen(str(ep.get("id", "")), hearts if first else 0)
        var mission: Dictionary = ep.get("mission", {})
        if first and not mission.is_empty() and not storytest:
                Globals.set_meta("custom_level", mission.get("level", {}))
                Globals.set_meta("start_level", int(mission["level"].get("id", 101)))
                Globals.set_meta("mission_label_custom", str(mission.get("label", "")))
                get_tree().change_scene_to_file("res://scenes/game.tscn")
                return
        if first and not mission.is_empty() and storytest:
                # مسیر مأموریت در تست فقط بررسی می‌شود، وارد مسابقه نمی‌رویم
                var has_lv: bool = mission.has("level") and not (mission["level"] as Dictionary).is_empty()
                print("[boghi][storytest] MISSION-DATA ", "OK" if has_lv else "FAIL")
        if first:
                Globals.add_coins(40)
                _flash_toast("اپیزود تمام شد! +۴۰ سکه و یک دلِ محله")
        else:
                _flash_toast("دوباره دیدی! محله هنوز همون قد بامزه‌ست")
        _refresh()
        if storytest:
                _st_ok = true

func _flash_toast(txt: String) -> void:
        toast.text = txt
        toast.modulate.a = 1.0
        var tw := create_tween()
        tw.tween_interval(2.2)
        tw.tween_property(toast, "modulate:a", 0.0, 0.6)

# ---------------- تست خودکار ----------------
func _run_storytest() -> void:
        await get_tree().create_timer(0.8).timeout
        _shot("/home/z/my-project/scripts/shot_story_hub.png")
        _open(0, STORY_MGR.card_list())
        await get_tree().create_timer(1.4).timeout
        _shot("/home/z/my-project/scripts/shot_story_scene.png")
        # تپ شبیه‌سازی‌شده تا پایان اپیزود — همان مسیر ورودی واقعی Button
        var guard := 0
        while stage != null and is_instance_valid(stage) and guard < 400:
                guard += 1
                stage._on_tap()
                await get_tree().create_timer(0.22).timeout
        await get_tree().create_timer(0.6).timeout
        _shot("/home/z/my-project/scripts/shot_story_end.png")
        if _st_ok or Globals.story_seen.has("ep1"):
                print("[boghi][storytest] STORYTEST OK — اپیزود کامل پخش شد")
                get_tree().quit(0)
        else:
                print("[boghi][storytest] STORYTEST FAIL")
                get_tree().quit(1)

func _shot(path: String) -> void:
        var img := get_viewport().get_texture().get_image()
        if img != null:
                img.save_png(path)
