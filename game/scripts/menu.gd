extends Control
## منوی اصلی — نسل حرفه‌ای: شیشه آسفالت تیره + طلایی + قرمز آتشین
## بزرگ‌ترها هم دوستش دارند، بچه‌ها هم بازی می‌کنند

var font: FontFile
var font_bold: FontFile
var font_display: FontFile
var panel_home: PanelContainer
var panel_levels: PanelContainer
var coin_label: Label
var plate_edit: LineEdit
var brain: CarBrain
var boghi_car: TextureRect
var pride_car: TextureRect

const COL_GOLD := Color(0.96, 0.76, 0.25)
const COL_GOLD_DIM := Color(0.72, 0.55, 0.2)
const COL_RED := Color(0.78, 0.15, 0.12)
const COL_RED_DARK := Color(0.45, 0.08, 0.06)
const COL_GLASS := Color(0.10, 0.11, 0.13, 0.90)
const COL_CREAM := Color(0.95, 0.93, 0.88)

func _ready() -> void:
        font = load("res://assets/fonts/Vazirmatn-Regular.ttf")
        font_bold = load("res://assets/fonts/Vazirmatn-Bold.ttf")
        font_display = load("res://assets/fonts/Lalezar-Regular.ttf")
        _build_ui()
        _refresh()
        # مغز بوقی: ماشین‌های پارک‌شده زنده‌اند و حرف می‌زنند
        brain = CarBrain.new()
        add_child(brain)
        if boghi_car != null:
                CarBrain.add_breathing(boghi_car, 4.0, 1.25)
        if pride_car != null:
                CarBrain.add_breathing(pride_car, 3.0, 1.5)
        brain.start_idle_chatter(
                func(cid: String) -> Control:
                        return boghi_car if cid == "boghi" else pride_car,
                func() -> Array: return ["boghi", "pride"], 8.0, 15.0)
        if OS.get_cmdline_user_args().has("--garage"):
                get_tree().change_scene_to_file("res://scenes/garage.tscn")
        if OS.get_cmdline_user_args().has("--levels"):
                _show(panel_levels)
        if OS.get_cmdline_user_args().has("--autotest"):
                if brain != null and boghi_car != null:
                        brain.say(boghi_car, "boghi", "select")
                await get_tree().create_timer(1.5).timeout
                get_viewport().get_texture().get_image().save_png("/home/z/my-project/scripts/shot_menu.png")
                get_tree().quit()

func _mk_label(txt: String, size: int, bold := false, display := false, col := COL_CREAM) -> Label:
        var l := Label.new()
        l.text = txt
        l.add_theme_font_override("font", font_display if display else (font_bold if bold else font))
        l.add_theme_font_size_override("font_size", size)
        l.add_theme_color_override("font_color", col)
        l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
                sb.shadow_color = Color(0, 0, 0, 0.45)
                sb.shadow_size = 10
        return sb

## سبک دکمه: «red» = دکمه اصلی آتشین، «dark» = فرعی شیشه‌ای، «tile» = کاشی مأموریت
func _style_btn(b: Button, kind := "red") -> void:
        var normal: StyleBoxFlat
        var hover: StyleBoxFlat
        var pressed: StyleBoxFlat
        var disabled: StyleBoxFlat
        var fg := COL_CREAM
        if kind == "red":
                normal = _sb(COL_RED, COL_RED_DARK, 16, 3)
                hover = _sb(COL_RED.lightened(0.10), COL_RED_DARK, 16, 3)
                pressed = _sb(COL_RED_DARK, COL_RED_DARK, 16, 3)
                disabled = _sb(Color(0.35, 0.2, 0.18), Color(0.3, 0.16, 0.14), 16, 3)
                fg = Color(1, 0.96, 0.9)
        elif kind == "dark":
                normal = _sb(Color(0.16, 0.175, 0.20, 0.97), COL_GOLD_DIM, 16, 2)
                hover = _sb(Color(0.22, 0.235, 0.26, 0.97), COL_GOLD, 16, 2)
                pressed = _sb(Color(0.10, 0.11, 0.13, 0.97), COL_GOLD_DIM, 16, 2)
                disabled = _sb(Color(0.14, 0.145, 0.16), Color(0.2, 0.2, 0.22), 16, 2)
                fg = Color(0.98, 0.92, 0.72)
        else:
                normal = _sb(Color(0.20, 0.22, 0.25, 0.97), Color(0.36, 0.39, 0.43), 12, 2, false)
                hover = _sb(Color(0.27, 0.30, 0.34, 0.97), COL_GOLD_DIM, 12, 2, false)
                pressed = _sb(Color(0.13, 0.14, 0.16, 0.97), Color(0.3, 0.32, 0.35), 12, 2, false)
                disabled = _sb(Color(0.145, 0.15, 0.16, 0.9), Color(0.21, 0.215, 0.22), 12, 2, false)
                fg = COL_CREAM
        b.add_theme_stylebox_override("normal", normal)
        b.add_theme_stylebox_override("hover", hover)
        b.add_theme_stylebox_override("pressed", pressed)
        b.add_theme_stylebox_override("disabled", disabled)
        b.add_theme_color_override("font_color", fg)
        b.add_theme_color_override("font_hover_color", fg)
        b.add_theme_color_override("font_focus_color", fg)
        b.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
        b.add_theme_color_override("font_disabled_color", Color(0.52, 0.5, 0.47))

func _mk_button(txt: String, size := 26, kind := "red", h := 74) -> Button:
        var b := Button.new()
        b.text = txt
        b.add_theme_font_override("font", font_display)
        b.add_theme_font_size_override("font_size", size)
        b.custom_minimum_size = Vector2(320, h)
        _style_btn(b, kind)
        return b

func _make_shadow_tex() -> ImageTexture:
        var sz := Vector2i(240, 64)
        var img := Image.create(sz.x, sz.y, false, Image.FORMAT_RGBA8)
        var cx := sz.x / 2.0
        var cy := sz.y / 2.0
        for y in sz.y:
                for x in sz.x:
                        var d := Vector2((x - cx) / (cx - 6.0), (y - cy) / (cy - 4.0)).length()
                        var a: float = clamp(1.0 - d, 0.0, 1.0)
                        img.set_pixel(x, y, Color(0.02, 0.02, 0.03, a * a * 0.8))
        return ImageTexture.create_from_image(img)

func _add_gradient(top: bool) -> void:
        var gt := GradientTexture2D.new()
        var g := Gradient.new()
        if top:
                g.offsets = PackedFloat32Array([0.0, 1.0])
                g.colors = PackedColorArray([Color(0.05, 0.04, 0.06, 0.62), Color(0, 0, 0, 0.0)])
                gt.fill_from = Vector2(0, 0)
                gt.fill_to = Vector2(0, 1)
        else:
                g.offsets = PackedFloat32Array([0.0, 1.0])
                g.colors = PackedColorArray([Color(0, 0, 0, 0.0), Color(0.04, 0.03, 0.05, 0.72)])
                gt.fill_from = Vector2(0, 0)
                gt.fill_to = Vector2(0, 1)
        gt.gradient = g
        var tr := TextureRect.new()
        tr.texture = gt
        tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        tr.stretch_mode = TextureRect.STRETCH_SCALE
        if top:
                tr.position = Vector2(0, 0)
                tr.size = Vector2(1280, 170)
        else:
                tr.position = Vector2(0, 500)
                tr.size = Vector2(1280, 220)
        tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(tr)

func _add_parked_cars() -> void:
        # بوقی قرمز و پراید مسابقه‌ای پارک شده روی جاده خیس — قهرمان‌های محله
        var sh1 := Sprite2D.new()
        sh1.texture = _make_shadow_tex()
        sh1.position = Vector2(230, 678)
        sh1.scale = Vector2(2.05, 0.75)
        add_child(sh1)
        var c1 := TextureRect.new()
        c1.texture = load("res://assets/sprites/boghi_side.png")
        c1.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        c1.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        c1.position = Vector2(48, 512)
        c1.size = Vector2(360, 190)
        c1.pivot_offset = Vector2(180, 190)
        c1.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(c1)
        boghi_car = c1
        # لمسِ بوقی: بوقی با صدای شیطون می‌گوید «منو انتخاب کن!»
        var tap1 := Button.new()
        tap1.flat = true
        tap1.position = Vector2(48, 512)
        tap1.size = Vector2(360, 190)
        tap1.modulate.a = 0.0
        tap1.pressed.connect(func():
                if brain != null and boghi_car != null:
                        brain.say(boghi_car, "boghi", "idle"))
        add_child(tap1)
        var sh2 := Sprite2D.new()
        sh2.texture = _make_shadow_tex()
        sh2.position = Vector2(628, 686)
        sh2.scale = Vector2(1.8, 0.7)
        add_child(sh2)
        var c2 := TextureRect.new()
        c2.texture = load("res://assets/sprites/pride_side.png")
        c2.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        c2.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        c2.position = Vector2(468, 538)
        c2.size = Vector2(320, 162)
        c2.pivot_offset = Vector2(160, 162)
        c2.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(c2)
        pride_car = c2
        var tap2 := Button.new()
        tap2.flat = true
        tap2.position = Vector2(468, 538)
        tap2.size = Vector2(320, 162)
        tap2.modulate.a = 0.0
        tap2.pressed.connect(func():
                if brain != null and pride_car != null:
                        brain.say(pride_car, "pride", "idle"))
        add_child(tap2)

func _build_title() -> void:
        # لوگوی رسمی بازی — اگر نبود، تیتر متنی می‌ماند
        var logo_path := "res://assets/sprites/logo.png"
        if ResourceLoader.exists(logo_path):
                var logo := TextureRect.new()
                logo.texture = load(logo_path)
                logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
                logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
                logo.position = Vector2(520, 8)
                logo.size = Vector2(560, 130)
                logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
                add_child(logo)
                CarBrain.add_breathing(logo, 2.5, 1.6)
                return
        var title := _mk_label("بوقی: تور شهرها", 58, false, true, COL_GOLD)
        title.add_theme_color_override("font_outline_color", Color(0.10, 0.06, 0.03))
        title.add_theme_constant_override("outline_size", 14)
        title.position = Vector2(540, 24)
        title.custom_minimum_size = Vector2(716, 0)
        add_child(title)
        var bar := Panel.new()
        bar.add_theme_stylebox_override("panel", _sb(COL_RED, Color(0, 0, 0, 0), 3))
        bar.position = Vector2(798, 110)
        bar.size = Vector2(200, 7)
        add_child(bar)
        var sub := _mk_label("فصل ۱ — تهران  •  ۵۰ مأموریت محله", 21, true, false, Color(1, 1, 1, 0.88))
        sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
        sub.add_theme_constant_override("outline_size", 6)
        sub.position = Vector2(540, 124)
        sub.custom_minimum_size = Vector2(716, 0)
        add_child(sub)

func _build_home_panel() -> void:
        panel_home = PanelContainer.new()
        panel_home.add_theme_stylebox_override("panel", _sb(COL_GLASS, Color(0.85, 0.68, 0.28, 0.45), 22, 2))
        panel_home.position = Vector2(856, 176)
        panel_home.size = Vector2(388, 466)
        add_child(panel_home)

        var mv := MarginContainer.new()
        mv.add_theme_constant_override("margin_left", 22)
        mv.add_theme_constant_override("margin_right", 22)
        mv.add_theme_constant_override("margin_top", 18)
        mv.add_theme_constant_override("margin_bottom", 18)
        panel_home.add_child(mv)

        var hb := VBoxContainer.new()
        hb.add_theme_constant_override("separation", 10)
        hb.alignment = BoxContainer.ALIGNMENT_CENTER
        mv.add_child(hb)

        # چیپ سکه
        var chip := PanelContainer.new()
        chip.add_theme_stylebox_override("panel", _sb(Color(0.16, 0.17, 0.20, 0.97), COL_GOLD_DIM, 22, 1, false))
        chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        coin_label = _mk_label("🪙 " + str(Globals.coins), 24, true, false, COL_GOLD)
        coin_label.custom_minimum_size = Vector2(150, 44)
        coin_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        chip.add_child(coin_label)
        hb.add_child(chip)

        # پلاک اسم کودک
        var plate_box := Control.new()
        plate_box.custom_minimum_size = Vector2(300, 210)
        var board := TextureRect.new()
        board.texture = load("res://assets/sprites/plate_empty.png")
        board.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        board.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        board.set_anchors_preset(Control.PRESET_FULL_RECT)
        plate_box.add_child(board)
        plate_edit = LineEdit.new()
        plate_edit.text = Globals.plate_name
        plate_edit.max_length = 12
        plate_edit.add_theme_font_override("font", font_bold)
        plate_edit.add_theme_font_size_override("font_size", 30)
        plate_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
        plate_edit.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
        plate_edit.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
        plate_edit.add_theme_color_override("font_color", Color(0.29, 0.216, 0.157))
        plate_edit.add_theme_color_override("caret_color", Color(0.29, 0.216, 0.157))
        plate_edit.add_theme_color_override("font_placeholder_color", Color(0.62, 0.5, 0.38))
        plate_edit.placeholder_text = "..."
        plate_edit.anchor_left = 0.22
        plate_edit.anchor_right = 0.78
        plate_edit.anchor_top = 0.50
        plate_edit.anchor_bottom = 0.80
        plate_edit.text_changed.connect(func(_t): _on_plate_changed())
        plate_box.add_child(plate_edit)
        hb.add_child(plate_box)

        var b_play := _mk_button(Globals.L("levels"), 30, "red", 72)
        b_play.pressed.connect(func(): _show(panel_levels))
        hb.add_child(b_play)

        var b_garage := _mk_button(Globals.L("workshop"), 25, "dark", 58)
        b_garage.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/garage.tscn"))
        hb.add_child(b_garage)

func _build_levels_panel() -> void:
        panel_levels = PanelContainer.new()
        panel_levels.add_theme_stylebox_override("panel", _sb(Color(0.115, 0.125, 0.145, 0.97), Color(0.85, 0.68, 0.28, 0.55), 24, 3))
        var lv := VBoxContainer.new()
        lv.add_theme_constant_override("separation", 10)
        panel_levels.add_child(lv)
        lv.add_child(_mk_label(Globals.L("levels") + " — " + "تهران", 38, false, true, COL_GOLD))
        var scroll := ScrollContainer.new()
        scroll.custom_minimum_size = Vector2(980, 460)
        var grid := GridContainer.new()
        grid.columns = 8
        grid.add_theme_constant_override("h_separation", 10)
        grid.add_theme_constant_override("v_separation", 10)
        for id in range(1, 51):
                var st: int = Globals.level_stars.get(id, 0)
                var b := Button.new()
                var txt := str(id)
                for s in 3:
                        txt += "★" if s < st else "·"
                b.text = txt
                b.custom_minimum_size = Vector2(112, 74)
                b.add_theme_font_override("font", font_display)
                b.add_theme_font_size_override("font_size", 21)
                b.disabled = not Globals.level_unlocked(id)
                _style_btn(b, "tile")
                b.pressed.connect(_start_level.bind(id))
                grid.add_child(b)
        scroll.add_child(grid)
        lv.add_child(scroll)
        var b_back1 := _mk_button(Globals.L("back"), 24, "dark", 58)
        b_back1.pressed.connect(func(): _show(panel_home))
        lv.add_child(b_back1)
        var center := CenterContainer.new()
        center.set_anchors_preset(Control.PRESET_FULL_RECT)
        center.add_child(panel_levels)
        add_child(center)

func _build_version() -> void:
        var v := _mk_label("نسخه ۰٫۳ — ماشین‌های زبان‌باز", 15, true, false, Color(1, 1, 1, 0.6))
        v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        v.position = Vector2(1000, 692)
        v.custom_minimum_size = Vector2(256, 0)
        add_child(v)

func _build_ui() -> void:
        var bg := TextureRect.new()
        bg.texture = load("res://assets/sprites/menu_bg.png")
        bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        bg.set_anchors_preset(Control.PRESET_FULL_RECT)
        add_child(bg)
        _add_gradient(true)
        _add_gradient(false)
        _add_parked_cars()
        _build_title()
        _build_home_panel()
        _build_levels_panel()
        _build_version()
        _show(panel_home)

func _show(p: PanelContainer) -> void:
        panel_home.visible = p == panel_home
        panel_levels.visible = p == panel_levels
        _refresh()

func _on_plate_changed() -> void:
        Globals.plate_name = plate_edit.text.strip_edges()
        if Globals.plate_name.is_empty():
                Globals.plate_name = "بوقی"
        Globals.save_game()

func _refresh() -> void:
        if coin_label:
                coin_label.text = "🪙 " + str(Globals.coins)
        if plate_edit:
                plate_edit.text = Globals.plate_name

func _start_level(id: int) -> void:
        Globals.set_meta("start_level", id)
        get_tree().change_scene_to_file("res://scenes/game.tscn")
