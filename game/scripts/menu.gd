extends Control
## منوی اصلی v1.0 — بازطراحی نوجوان‌پسند
## درس‌های v0.9 که این نسل ساخته شد:
##  ۱) layout_direction باید صریحاً LTR باشد؛ 0 یعنی ارث‌بری و روی گوشی فارسی
##     همه‌چیز آینه می‌شد (پنل راست→چپ، برچسب‌ها جابه‌جا)
##  ۲) هر پنل اندازه‌ی ثابت و وسط‌چین است — آینه هم بشود همان وسط می‌ماند
##     و روی هر عرضی (1280 دسکتاپ تا 1600 گوشی) سالم است
##  ۳) تیتر داخل ناحیه‌ی امن است (زیر استاتوس‌بار بریده نمی‌شود)
##  ۴) بدون لوگوی تصویری — تیتر موتوری همیشه رندر می‌شود (ماشین روی برج ممنوع!)
##  ۵) پلاک بدون عکس بچه — نوجوان‌پسند
##  ۶) autotest واقعی: منو → ماموریت‌ها → مرحله ۱ → ورود به بازی

var font: FontFile
var font_bold: FontFile
var font_display: FontFile
var panel_home: PanelContainer
var panel_levels: PanelContainer
var play_btn: Button
var coin_label: Label
var plate_edit: LineEdit
var brain = null
var deco_cars: Array = []
var back_btn: Button
var first_tile: Button
var akbar_rect: TextureRect
var akbar_line_label: Label
var title_nodes: Array = []
var _expect_scene_change := false

# بارگذاری مستقیم مغز — بدون وابستگی به class cache
const BRAIN_SCRIPT := preload("res://scripts/car_brain.gd")

const COL_GOLD := Color(0.96, 0.76, 0.25)
const COL_GOLD_DIM := Color(0.72, 0.55, 0.2)
const COL_RED := Color(0.78, 0.15, 0.12)
const COL_RED_DARK := Color(0.45, 0.08, 0.06)
const COL_GLASS := Color(0.10, 0.11, 0.13, 0.90)
const COL_CREAM := Color(0.95, 0.93, 0.88)
# ناحیه امن بالا (استاتوس‌بار گوشی) — هیچ UI مهمی بالای این خط
const SAFE_TOP := 46.0

func _safe_load(path: String) -> Resource:
        # بارگذاری امن: منبع نبودن یا خرابی هرگز منو را نمی‌شکند
        if path == null or not ResourceLoader.exists(path):
                return null
        return load(path)

func _safe_font(path: String) -> FontFile:
        var r := _safe_load(path)
        if r is FontFile:
                return r
        return null

func _ready() -> void:
        # ⛔ قفل صریح LTR — مقدار 0 (ارث‌بری) باگ v0.9 بود که روی گوشی فارسی
        # کل چیدمان را آینه می‌کرد
        layout_direction = Control.LAYOUT_DIRECTION_LTR
        font = _safe_font("res://assets/fonts/Vazirmatn-Regular.ttf")
        font_bold = _safe_font("res://assets/fonts/Vazirmatn-Bold.ttf")
        font_display = _safe_font("res://assets/fonts/Lalezar-Regular.ttf")
        _build_background()
        _build_ui()
        _refresh()
        if has_node("/root/AudioMgr"):
                get_node("/root/AudioMgr").play_music()
        # تزئینات زنده — هر کدام فراخوان جداگانه تا خرابیِ هر بخش فقط خودش را بیندازد
        call_deferred("_deco_gradients")
        call_deferred("_deco_cars")
        call_deferred("_deco_brain")
        call_deferred("_deco_version")
        var uargs := OS.get_cmdline_user_args()
        if uargs.has("--garage"):
                get_tree().change_scene_to_file("res://scenes/garage.tscn")
        if uargs.has("--levels"):
                _show(panel_levels)
        if uargs.has("--autotest"):
                _autotest()

func _autotest() -> void:
        await get_tree().create_timer(1.2).timeout
        _shot("/home/z/my-project/scripts/shot_menu.png")
        if play_btn == null or not is_instance_valid(play_btn):
                print("[boghi][autotest] TAP-PLAY FAIL (no button)")
                get_tree().quit(1)
                return
        # ۱) تپ واقعی روی «ماموریت‌ها»
        _tap(play_btn)
        await get_tree().create_timer(0.7).timeout
        var ok := panel_levels != null and panel_levels.visible
        print("[boghi][autotest] TAP-PLAY ", "OK" if ok else "FAIL")
        _shot("/home/z/my-project/scripts/shot_levels.png")
        if not ok:
                get_tree().quit(1)
                return
        # ۲) برگشت به خانه
        if back_btn != null and is_instance_valid(back_btn):
                _tap(back_btn)
                await get_tree().create_timer(0.5).timeout
                print("[boghi][autotest] TAP-BACK ", "OK" if panel_home.visible else "FAIL")
        # ۳) ورود به مرحله ۱ — تپ روی کاشی اول؛ انتظار: تعویض صحنه به Game
        if first_tile == null or not is_instance_valid(first_tile):
                print("[boghi][autotest] TAP-LEVEL FAIL (no tile)")
                get_tree().quit(1)
                return
        _tap(play_btn) # برگرد به لیست
        await get_tree().create_timer(0.5).timeout
        _tap(first_tile)
        _expect_scene_change = true
        # اگر تا ۲ ثانیه دیگر صحنه عوض نشده باشد، منو هنوز زنده است = شکست
        await get_tree().create_timer(2.0).timeout
        print("[boghi][autotest] TAP-LEVEL FAIL (scene did not change — باگ ورود به بازی!)")
        get_tree().quit(1)

## وقتی صحنه عوض می‌شود منو free می‌شود — همین‌جا موفقیت تپِ مرحله را اعلام می‌کنیم
func _exit_tree() -> void:
        if _expect_scene_change:
                print("[boghi][autotest] TAP-LEVEL OK — scene changed to ", "(Game)")

func _shot(path: String) -> void:
        var img := get_viewport().get_texture().get_image()
        if img != null:
                img.save_png(path)

func _tap(btn: Button) -> void:
        var pos: Vector2 = btn.get_global_rect().get_center()
        for pressed in [true, false]:
                var ev := InputEventMouseButton.new()
                ev.button_index = MOUSE_BUTTON_LEFT
                ev.pressed = pressed
                if pressed:
                        ev.button_mask = MOUSE_BUTTON_MASK_LEFT
                ev.position = pos
                ev.global_position = pos
                Input.parse_input_event(ev)

func _build_background() -> void:
        var tex := _safe_load("res://assets/sprites/menu_bg.webp")
        if tex != null:
                var bg := TextureRect.new()
                bg.texture = tex
                bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
                bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
                bg.set_anchors_preset(Control.PRESET_FULL_RECT)
                bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
                add_child(bg)
        else:
                var gt := GradientTexture2D.new()
                var g := Gradient.new()
                g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
                g.colors = PackedColorArray([Color(0.30, 0.16, 0.10), Color(0.14, 0.09, 0.07), Color(0.06, 0.04, 0.04)])
                gt.gradient = g
                gt.fill_from = Vector2(0.3, 0.0)
                gt.fill_to = Vector2(0.7, 1.0)
                var bg := TextureRect.new()
                bg.texture = gt
                bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
                bg.set_anchors_preset(Control.PRESET_FULL_RECT)
                bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
                add_child(bg)

func _mk_label(txt: String, size: int, bold := false, display := false, col := COL_CREAM) -> Label:
        var l := Label.new()
        l.text = txt
        var f := font_display if display else (font_bold if bold else font)
        if f != null:
                l.add_theme_font_override("font", f)
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

## سبک دکمه: «red» = اصلی آتشین، «dark» = فرعی شیشه‌ای، «tile» = کاشی ماموریت
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
        if font_display != null:
                b.add_theme_font_override("font", font_display)
        b.add_theme_font_size_override("font_size", size)
        b.custom_minimum_size = Vector2(320, h)
        _style_btn(b, kind)
        return b

## سایهٔ نرم زیر ماشین‌ها
func _make_shadow_tex() -> Texture2D:
        var gt := GradientTexture2D.new()
        gt.fill = GradientTexture2D.FILL_RADIAL
        gt.width = 240
        gt.height = 64
        gt.fill_from = Vector2(0.5, 0.5)
        gt.fill_to = Vector2(0.5, 0.0)
        var g := Gradient.new()
        g.offsets = PackedFloat32Array([0.0, 0.65, 1.0])
        g.colors = PackedColorArray([Color(0.02, 0.02, 0.03, 0.8), Color(0.02, 0.02, 0.03, 0.22), Color(0, 0, 0, 0)])
        gt.gradient = g
        return gt

func _deco_gradients() -> void:
        _add_gradient(true)
        _add_gradient(false)

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
        tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
        tr.anchor_left = 0.0
        tr.anchor_right = 1.0
        if top:
                tr.anchor_top = 0.0
                tr.anchor_bottom = 0.24
        else:
                tr.anchor_top = 0.70
                tr.anchor_bottom = 1.0
        add_child(tr)

## ماشین‌های قهرمان محله — پایین-چپ؛ پشت پنل‌ها (z کمتر) تا زیرشان نروند جلوی چشم
func _deco_cars() -> void:
        var sh1 := TextureRect.new()
        sh1.texture = _make_shadow_tex()
        sh1.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        sh1.anchor_left = 0.014
        sh1.anchor_right = 0.246
        sh1.anchor_top = 0.928
        sh1.anchor_bottom = 0.985
        sh1.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(sh1)
        deco_cars.append(sh1)
        var c1 := TextureRect.new()
        c1.texture = _safe_load("res://assets/sprites/boghi_side.png")
        c1.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        c1.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        c1.anchor_left = 0.025
        c1.anchor_right = 0.235
        c1.anchor_top = 0.748
        c1.anchor_bottom = 0.975
        c1.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(c1)
        deco_cars.append(c1)
        var tap1 := Button.new()
        tap1.flat = true
        tap1.modulate.a = 0.0
        tap1.anchor_left = 0.025
        tap1.anchor_right = 0.235
        tap1.anchor_top = 0.748
        tap1.anchor_bottom = 0.975
        tap1.pressed.connect(func():
                if brain != null and is_instance_valid(c1):
                        brain.say(c1, "boghi", "idle"))
        add_child(tap1)
        deco_cars.append(tap1)
        if brain != null and is_instance_valid(c1):
                BRAIN_SCRIPT.add_breathing(c1, 4.0, 1.25)
        var sh2 := TextureRect.new()
        sh2.texture = _make_shadow_tex()
        sh2.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        sh2.anchor_left = 0.252
        sh2.anchor_right = 0.475
        sh2.anchor_top = 0.935
        sh2.anchor_bottom = 0.985
        sh2.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(sh2)
        deco_cars.append(sh2)
        var c2 := TextureRect.new()
        c2.texture = _safe_load("res://assets/sprites/pride_side.png")
        c2.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        c2.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        c2.anchor_left = 0.258
        c2.anchor_right = 0.458
        c2.anchor_top = 0.772
        c2.anchor_bottom = 0.972
        c2.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(c2)
        deco_cars.append(c2)
        var tap2 := Button.new()
        tap2.flat = true
        tap2.modulate.a = 0.0
        tap2.anchor_left = 0.258
        tap2.anchor_right = 0.458
        tap2.anchor_top = 0.772
        tap2.anchor_bottom = 0.972
        tap2.pressed.connect(func():
                if brain != null and is_instance_valid(c2):
                        brain.say(c2, "pride", "idle"))
        add_child(tap2)
        deco_cars.append(tap2)
        if brain != null and is_instance_valid(c2):
                BRAIN_SCRIPT.add_breathing(c2, 3.0, 1.5)
        # ماشین‌ها باید پشت پنل‌ها باشند (بعد از پنل‌ها add می‌شوند — ببرش عقب)
        for i in deco_cars.size():
                if is_instance_valid(deco_cars[i]):
                        move_child(deco_cars[i], 1)

## تیتر موتوری — همیشه رندر می‌شود؛ داخل ناحیه امن استاتوس‌بار
func _build_title() -> void:
        var title := _mk_label("بوقی: تور شهرها", 54, false, true, COL_GOLD)
        title.add_theme_color_override("font_outline_color", Color(0.10, 0.06, 0.03))
        title.add_theme_constant_override("outline_size", 14)
        title.anchor_left = 0.0
        title.anchor_right = 1.0
        title.offset_top = SAFE_TOP
        title.offset_bottom = SAFE_TOP + 66
        title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        add_child(title)
        title_nodes.append(title)
        var bar := Panel.new()
        bar.add_theme_stylebox_override("panel", _sb(COL_RED, Color(0, 0, 0, 0), 3))
        bar.anchor_left = 0.5
        bar.anchor_right = 0.5
        bar.offset_left = -100.0
        bar.offset_right = 100.0
        bar.offset_top = SAFE_TOP + 72
        bar.offset_bottom = SAFE_TOP + 79
        add_child(bar)
        title_nodes.append(bar)
        var sub := _mk_label("فصل ۱ — تهران  •  ۵۰ مأموریت محله", 20, true, false, Color(1, 1, 1, 0.88))
        sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
        sub.add_theme_constant_override("outline_size", 6)
        sub.anchor_left = 0.0
        sub.anchor_right = 1.0
        sub.offset_top = SAFE_TOP + 84
        sub.offset_bottom = SAFE_TOP + 114
        sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        add_child(sub)
        title_nodes.append(sub)

func _build_home_panel() -> void:
        panel_home = PanelContainer.new()
        panel_home.add_theme_stylebox_override("panel", _sb(COL_GLASS, Color(0.85, 0.68, 0.28, 0.45), 22, 2))
        # اندازه ثابت + وسط‌چین مطلق — ضدآینه و ضدعرض‌های مختلف
        panel_home.custom_minimum_size = Vector2(360, 434)
        panel_home.set_anchors_preset(Control.PRESET_CENTER)
        panel_home.offset_top = 20.0 # کمی پایین‌تر از مرکز — دور از تیتر (زیرتیتر تا y=160)
        panel_home.grow_horizontal = Control.GROW_DIRECTION_BOTH
        panel_home.grow_vertical = Control.GROW_DIRECTION_BOTH
        add_child(panel_home)

        var mv := MarginContainer.new()
        mv.add_theme_constant_override("margin_left", 18)
        mv.add_theme_constant_override("margin_right", 18)
        mv.add_theme_constant_override("margin_top", 14)
        mv.add_theme_constant_override("margin_bottom", 14)
        panel_home.add_child(mv)

        var hb := VBoxContainer.new()
        hb.add_theme_constant_override("separation", 10)
        hb.alignment = BoxContainer.ALIGNMENT_CENTER
        mv.add_child(hb)

        # چیپ سکه — آیکون واقعی (ایموجی در فونت گوشی گلیف ندارد)
        var chip := PanelContainer.new()
        chip.add_theme_stylebox_override("panel", _sb(Color(0.16, 0.17, 0.20, 0.97), COL_GOLD_DIM, 22, 1, false))
        chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        var chip_hb := HBoxContainer.new()
        chip_hb.add_theme_constant_override("separation", 8)
        chip.add_child(chip_hb)
        var coin_tex := _safe_load("res://assets/sprites/coin.png")
        if coin_tex != null:
                var coin_icon := TextureRect.new()
                coin_icon.texture = coin_tex
                coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
                coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
                coin_icon.custom_minimum_size = Vector2(30, 30)
                coin_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
                chip_hb.add_child(coin_icon)
        coin_label = _mk_label(str(Globals.coins), 24, true, false, COL_GOLD)
        coin_label.custom_minimum_size = Vector2(90, 42)
        coin_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
        chip_hb.add_child(coin_label)
        hb.add_child(chip)

        # پلاک نئونی اسم — نوجوان‌پسند (بدون عکس بچه!)
        var plate_box := Control.new()
        plate_box.custom_minimum_size = Vector2(324, 122)
        var board_tex := _safe_load("res://assets/sprites/plate_empty.png")
        if board_tex != null:
                var board := TextureRect.new()
                board.texture = board_tex
                board.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
                board.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
                board.set_anchors_preset(Control.PRESET_FULL_RECT)
                board.mouse_filter = Control.MOUSE_FILTER_IGNORE
                plate_box.add_child(board)
        plate_edit = LineEdit.new()
        plate_edit.text = Globals.plate_name
        plate_edit.max_length = 12
        if font_bold != null:
                plate_edit.add_theme_font_override("font", font_bold)
        plate_edit.add_theme_font_size_override("font_size", 32)
        plate_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
        plate_edit.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
        plate_edit.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
        plate_edit.add_theme_color_override("font_color", Color(0.99, 0.85, 0.30))
        plate_edit.add_theme_color_override("caret_color", Color(0.99, 0.85, 0.30))
        plate_edit.add_theme_color_override("font_placeholder_color", Color(0.6, 0.5, 0.25))
        plate_edit.placeholder_text = "اسم تو..."
        plate_edit.anchor_left = 0.12
        plate_edit.anchor_right = 0.88
        plate_edit.anchor_top = 0.34
        plate_edit.anchor_bottom = 0.72
        plate_edit.text_changed.connect(func(_t): _on_plate_changed())
        plate_box.add_child(plate_edit)
        hb.add_child(plate_box)

        var b_play := _mk_button(Globals.L("levels"), 30, "red", 64)
        b_play.pressed.connect(func(): _show(panel_levels))
        play_btn = b_play
        hb.add_child(b_play)

        var b_garage := _mk_button(Globals.L("workshop"), 24, "dark", 54)
        b_garage.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/garage.tscn"))
        hb.add_child(b_garage)

        # چند نفره آنلاین — نقشه راه؛ اکبر تیکه می‌اندازد که نسخه بعد می‌آید
        var b_online := _mk_button("آنلاین چند نفره — به‌زودی!", 19, "dark", 46)
        b_online.pressed.connect(func():
                if brain != null and deco_cars.size() > 1 and is_instance_valid(deco_cars[1]):
                        brain.say(deco_cars[1], "akbar", "online"))
        hb.add_child(b_online)

func _build_levels_panel() -> void:
        panel_levels = PanelContainer.new()
        panel_levels.add_theme_stylebox_override("panel", _sb(Color(0.115, 0.125, 0.145, 0.97), Color(0.85, 0.68, 0.28, 0.55), 24, 3))
        panel_levels.custom_minimum_size = Vector2(1040, 560)
        panel_levels.set_anchors_preset(Control.PRESET_CENTER)
        panel_levels.offset_top = 10.0
        panel_levels.grow_horizontal = Control.GROW_DIRECTION_BOTH
        panel_levels.grow_vertical = Control.GROW_DIRECTION_BOTH
        panel_levels.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var lv := VBoxContainer.new()
        lv.add_theme_constant_override("separation", 8)
        panel_levels.add_child(lv)
        # هدر: اکبر سیبیلو (شخصیت طنز) + تیکه‌ی تصادفی
        var hdr := HBoxContainer.new()
        hdr.add_theme_constant_override("separation", 14)
        akbar_rect = TextureRect.new()
        akbar_rect.texture = _safe_load("res://assets/sprites/akbar.png")
        if akbar_rect.texture != null:
                akbar_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
                akbar_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
                akbar_rect.custom_minimum_size = Vector2(92, 108)
                hdr.add_child(akbar_rect)
        var ak := VBoxContainer.new()
        ak.add_theme_constant_override("separation", 2)
        var ak_name := _mk_label("اکبر سیبیلو — رئیس مأموریت‌ها", 26, false, true, COL_GOLD)
        ak_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
        ak.add_child(ak_name)
        akbar_line_label = _mk_label("", 20, true, false, COL_CREAM)
        akbar_line_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
        akbar_line_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
        akbar_line_label.add_theme_constant_override("outline_size", 5)
        ak.add_child(akbar_line_label)
        hdr.add_child(ak)
        lv.add_child(hdr)
        var scroll := ScrollContainer.new()
        scroll.custom_minimum_size = Vector2(996, 300)
        scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
        var grid := GridContainer.new()
        grid.columns = 8
        grid.add_theme_constant_override("h_separation", 10)
        grid.add_theme_constant_override("v_separation", 10)
        for id in range(1, 51):
                var st: int = Globals.level_stars.get(id, 0)
                var unlocked: bool = Globals.level_unlocked(id)
                var b := Button.new()
                b.custom_minimum_size = Vector2(112, 64)
                _style_btn(b, "tile")
                b.disabled = not unlocked
                # دو خط: عدد (لاله‌زار درشت) + ردیف ستاره (وازیرمتن — گلیف تضمینی)
                var vb := VBoxContainer.new()
                vb.set_anchors_preset(Control.PRESET_FULL_RECT)
                vb.alignment = BoxContainer.ALIGNMENT_CENTER
                vb.add_theme_constant_override("separation", 0)
                vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
                var num := Label.new()
                num.text = str(id)
                if font_display != null:
                        num.add_theme_font_override("font", font_display)
                num.add_theme_font_size_override("font_size", 30)
                num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                num.add_theme_color_override("font_color", COL_CREAM if unlocked else Color(0.55, 0.53, 0.50))
                num.mouse_filter = Control.MOUSE_FILTER_IGNORE
                vb.add_child(num)
                var stars := Label.new()
                var st_txt := ""
                for s in 3:
                        st_txt += "٭" if s < st else "·"
                stars.text = st_txt
                if font_bold != null:
                        stars.add_theme_font_override("font", font_bold)
                stars.add_theme_font_size_override("font_size", 14)
                stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                stars.add_theme_color_override("font_color", COL_GOLD if st > 0 else Color(0.42, 0.44, 0.47))
                stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
                vb.add_child(stars)
                b.add_child(vb)
                b.pressed.connect(_start_level.bind(id))
                grid.add_child(b)
                if id == 1:
                        first_tile = b
        scroll.add_child(grid)
        lv.add_child(scroll)
        var b_back1 := _mk_button(Globals.L("back"), 24, "dark", 52)
        b_back1.pressed.connect(func(): _show(panel_home))
        back_btn = b_back1
        lv.add_child(b_back1)
        # پنل مستقیم (بدون CenterContainer تمام‌صفحه — درس v0.8)
        add_child(panel_levels)
        panel_levels.visible = false

func _deco_brain() -> void:
        brain = BRAIN_SCRIPT.new()
        add_child(brain)
        # گپ زدن خودکار ماشین‌ها — روح طنز منو (مثل v0.9)
        if deco_cars.size() >= 5:
                brain.start_idle_chatter(
                        func(cid: String) -> Control:
                                if cid == "boghi" and is_instance_valid(deco_cars[1]):
                                        return deco_cars[1]
                                if cid == "pride" and is_instance_valid(deco_cars[4]):
                                        return deco_cars[4]
                                return null,
                        func() -> Array: return ["boghi", "pride"], 8.0, 15.0)

func _deco_version() -> void:
        # یک برچسب واحد وسط پایین — چیزی که آینه شود جابه‌جا نمی‌شود
        var l := _mk_label("بوقی v1.0 (build 11)  •  از استودیو ایماروید", 14, true, false, Color(1, 1, 1, 0.42))
        l.anchor_left = 0.0
        l.anchor_right = 1.0
        l.anchor_top = 1.0
        l.anchor_bottom = 1.0
        l.offset_left = 16.0
        l.offset_right = -16.0
        l.offset_top = -34.0
        l.offset_bottom = -8.0
        l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        l.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(l)

func _build_ui() -> void:
        _build_title()
        _build_home_panel()
        _build_levels_panel()
        _show(panel_home)

func _show(p: PanelContainer) -> void:
        if panel_home == null or panel_levels == null:
                return
        panel_home.visible = p == panel_home
        panel_levels.visible = p == panel_levels
        # تیتر فقط مال صفحه‌ی خانه است (لیست ماموریت‌ها خودش هدر دارد)
        for n in title_nodes:
                if is_instance_valid(n):
                        n.visible = p == panel_home
        for n in deco_cars:
                if is_instance_valid(n):
                        n.visible = p == panel_home
        # هر باز شدن مأموریت‌ها: تیکه تازه‌ی اکبر
        if p == panel_levels and akbar_line_label != null:
                var line := CarBrain.pick_line("akbar", "idle")
                if line.is_empty():
                        line = "امروز جاده مال ماست!"
                akbar_line_label.text = line
                if brain != null and akbar_rect != null and is_instance_valid(akbar_rect) and akbar_rect.texture != null:
                        brain.say(akbar_rect, "akbar", "idle")
        _refresh()

func _on_plate_changed() -> void:
        Globals.plate_name = plate_edit.text.strip_edges()
        if Globals.plate_name.is_empty():
                Globals.plate_name = "بوقی"
        Globals.save_game()

func _refresh() -> void:
        if coin_label:
                coin_label.text = str(Globals.coins)
        if plate_edit:
                plate_edit.text = Globals.plate_name

func _start_level(id: int) -> void:
        Globals.set_meta("start_level", id)
        get_tree().change_scene_to_file("res://scenes/game.tscn")
