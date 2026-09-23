extends Control
## منوی اصلی — نسل حرفه‌ای: شیشه آسفالت تیره + طلایی + قرمز آتشین
## معماری ضربه‌گیر: اول منوی ضروری (دکمه‌ها و پنل‌ها) ساخته می‌شود و بعد
## تزئینات زنده در فراخوان‌های جداگانه deferred اضافه می‌شوند؛ اگر هر تزئین
## روی هر دستگاهی خطا بدهد، منوی کامل و قابل‌بازی سر جایش می‌ماند.

var font: FontFile
var font_bold: FontFile
var font_display: FontFile
var panel_home: PanelContainer
var panel_levels: PanelContainer
var levels_center: CenterContainer
var play_btn: Button
var coin_label: Label
var plate_edit: LineEdit
var brain = null
var deco_cars: Array = []
var back_btn: Button
# بارگذاری مستقیم مغز — بدون وابستگی به class cache
const BRAIN_SCRIPT := preload("res://scripts/car_brain.gd")
var boghi_car: TextureRect
var pride_car: TextureRect
var akbar_rect: TextureRect
var akbar_line_label: Label
var title_nodes: Array = []

const COL_GOLD := Color(0.96, 0.76, 0.25)
const COL_GOLD_DIM := Color(0.72, 0.55, 0.2)
const COL_RED := Color(0.78, 0.15, 0.12)
const COL_RED_DARK := Color(0.45, 0.08, 0.06)
const COL_GLASS := Color(0.10, 0.11, 0.13, 0.90)
const COL_CREAM := Color(0.95, 0.93, 0.88)

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
        # جهت چیدمان را LTR قفل می‌کنیم تا presetهای anchor در لوکیشن فارسی آینه نشوند
        # (متن فارسی دست‌نخورده می‌ماند — فقط هندسه deterministic می‌شود)
        set("layout_direction", 0)
        font = _safe_font("res://assets/fonts/Vazirmatn-Regular.ttf")
        font_bold = _safe_font("res://assets/fonts/Vazirmatn-Bold.ttf")
        font_display = _safe_font("res://assets/fonts/Lalezar-Regular.ttf")
        _build_background()
        _build_ui()
        _refresh()
        # آهنگ از همان اول منو پخش می‌شود
        if has_node("/root/AudioMgr"):
                get_node("/root/AudioMgr").play_music()
        # تزئینات زنده — هر کدام در فراخوان جداگانه deferred تا خرابیِ
        # هر بخش فقط خودش را از کار بیندازد، نه کل منو را
        call_deferred("_deco_gradients")
        call_deferred("_deco_cars")
        call_deferred("_deco_logo")
        call_deferred("_deco_brain")
        call_deferred("_deco_version")
        call_deferred("_layout_watchdog")
        var uargs := OS.get_cmdline_user_args()
        if uargs.has("--garage"):
                get_tree().change_scene_to_file("res://scenes/garage.tscn")
        if uargs.has("--levels"):
                _show(panel_levels)
        if uargs.has("--autotest"):
                _autotest()

func _autotest() -> void:
        await get_tree().create_timer(1.2).timeout
        var img := get_viewport().get_texture().get_image()
        if img != null:
                img.save_png("/home/z/my-project/scripts/shot_menu.png")
        # تست تپ واقعی: رویداد از پایپ‌لاین ورودی می‌گذرد (مثل انگشت روی گوشی)
        if play_btn != null and is_instance_valid(play_btn):
                var pos: Vector2 = play_btn.get_global_rect().get_center()
                var ev := InputEventMouseButton.new()
                ev.button_index = MOUSE_BUTTON_LEFT
                ev.pressed = true
                ev.button_mask = MOUSE_BUTTON_MASK_LEFT
                ev.position = pos
                ev.global_position = pos
                Input.parse_input_event(ev)
                await get_tree().create_timer(0.12).timeout
                var ev2 := InputEventMouseButton.new()
                ev2.button_index = MOUSE_BUTTON_LEFT
                ev2.pressed = false
                ev2.position = pos
                ev2.global_position = pos
                Input.parse_input_event(ev2)
                await get_tree().create_timer(0.7).timeout
                var ok := panel_levels != null and panel_levels.visible
                print("[boghi][autotest] TAP-PLAY ", "OK" if ok else "FAIL",
                        " levels=", panel_levels.visible if panel_levels != null else false,
                        " home=", panel_home.visible if panel_home != null else false)
                var img2 := get_viewport().get_texture().get_image()
                if img2 != null:
                        img2.save_png("/home/z/my-project/scripts/shot_levels.png")
                # تست برگشت: تپ واقعی روی دکمه‌ی برگشت
                if back_btn != null and is_instance_valid(back_btn):
                        var pos2: Vector2 = back_btn.get_global_rect().get_center()
                        var ev3 := InputEventMouseButton.new()
                        ev3.button_index = MOUSE_BUTTON_LEFT
                        ev3.pressed = true
                        ev3.button_mask = MOUSE_BUTTON_MASK_LEFT
                        ev3.position = pos2
                        ev3.global_position = pos2
                        Input.parse_input_event(ev3)
                        await get_tree().create_timer(0.12).timeout
                        var ev4 := InputEventMouseButton.new()
                        ev4.button_index = MOUSE_BUTTON_LEFT
                        ev4.pressed = false
                        ev4.position = pos2
                        ev4.global_position = pos2
                        Input.parse_input_event(ev4)
                        await get_tree().create_timer(0.5).timeout
                        var ok2 := panel_home.visible
                        print("[boghi][autotest] TAP-BACK ", "OK" if ok2 else "FAIL",
                                " home=", panel_home.visible, " levels=", panel_levels.visible)
        get_tree().quit()

func _build_background() -> void:
        # اگر پس‌زمینه به هر دلیل لود نشد، گرادیان گرم آسفالت جایش را می‌گیرد
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
        if font_display != null:
                b.add_theme_font_override("font", font_display)
        b.add_theme_font_size_override("font_size", size)
        b.custom_minimum_size = Vector2(320, h)
        _style_btn(b, kind)
        return b

## سایهٔ نرم زیر ماشین‌ها — رادیال خالص موتور، بدون حلقهٔ پیکسلی
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
        # چیدمان anchor-محور (position ثابت روی برخی گوشی‌ها رندر نمی‌شود)
        tr.anchor_left = 0.0
        tr.anchor_right = 1.0
        if top:
                tr.anchor_top = 0.0
                tr.anchor_bottom = 0.236
        else:
                tr.anchor_top = 0.694
                tr.anchor_bottom = 1.0
        add_child(tr)

func _deco_cars() -> void:
        # بوقی قرمز و پراید مسابقه‌ای پارک شده روی جاده خیس — قهرمان‌های محله
        # همه با anchor (نه position ثابت) تا روی هر گوشی/هر RTL رندر شود
        var sh1 := TextureRect.new()
        sh1.texture = _make_shadow_tex()
        sh1.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        sh1.anchor_left = 0.0
        sh1.anchor_right = 0.372
        sh1.anchor_top = 0.908
        sh1.anchor_bottom = 0.975
        sh1.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(sh1)
        var c1 := TextureRect.new()
        c1.texture = _safe_load("res://assets/sprites/boghi_side.png")
        c1.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        c1.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        c1.anchor_left = 0.0375
        c1.anchor_right = 0.3188
        c1.anchor_top = 0.7111
        c1.anchor_bottom = 0.975
        c1.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(c1)
        boghi_car = c1
        # لمسِ بوقی: بوقی با صدای شیطون می‌گوید «منو انتخاب کن!»
        var tap1 := Button.new()
        tap1.flat = true
        tap1.modulate.a = 0.0
        tap1.anchor_left = 0.0375
        tap1.anchor_right = 0.3188
        tap1.anchor_top = 0.7111
        tap1.anchor_bottom = 0.975
        tap1.pressed.connect(func():
                if brain != null and is_instance_valid(boghi_car):
                        brain.say(boghi_car, "boghi", "idle"))
        add_child(tap1)
        deco_cars.append(sh1)
        deco_cars.append(c1)
        deco_cars.append(tap1)
        var sh2 := TextureRect.new()
        sh2.texture = _make_shadow_tex()
        sh2.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        sh2.anchor_left = 0.3219
        sh2.anchor_right = 0.6594
        sh2.anchor_top = 0.9222
        sh2.anchor_bottom = 0.9833
        sh2.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(sh2)
        var c2 := TextureRect.new()
        c2.texture = _safe_load("res://assets/sprites/pride_side.png")
        c2.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        c2.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        c2.anchor_left = 0.3656
        c2.anchor_right = 0.6156
        c2.anchor_top = 0.7472
        c2.anchor_bottom = 0.9722
        c2.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(c2)
        pride_car = c2
        var tap2 := Button.new()
        tap2.flat = true
        tap2.modulate.a = 0.0
        tap2.anchor_left = 0.3656
        tap2.anchor_right = 0.6156
        tap2.anchor_top = 0.7472
        tap2.anchor_bottom = 0.9722
        tap2.pressed.connect(func():
                if brain != null and is_instance_valid(pride_car):
                        brain.say(pride_car, "pride", "idle"))
        add_child(tap2)
        deco_cars.append(sh2)
        deco_cars.append(c2)
        deco_cars.append(tap2)

## تیتر متنی — همیشه ساخته می‌شود (پشتیبان مطمئن)
func _build_title() -> void:
        var title := _mk_label("بوقی: تور شهرها", 58, false, true, COL_GOLD)
        title.add_theme_color_override("font_outline_color", Color(0.10, 0.06, 0.03))
        title.add_theme_constant_override("outline_size", 14)
        title.anchor_left = 0.0
        title.anchor_right = 1.0
        title.anchor_top = 0.0
        title.offset_top = 24.0
        title.offset_bottom = 106.0
        title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        add_child(title)
        title_nodes.append(title)
        var bar := Panel.new()
        bar.add_theme_stylebox_override("panel", _sb(COL_RED, Color(0, 0, 0, 0), 3))
        bar.anchor_left = 0.5
        bar.anchor_right = 0.5
        bar.anchor_top = 0.0
        bar.offset_left = -100.0
        bar.offset_right = 100.0
        bar.offset_top = 110.0
        bar.offset_bottom = 117.0
        add_child(bar)
        title_nodes.append(bar)
        var sub := _mk_label("فصل ۱ — تهران  •  ۵۰ مأموریت محله", 21, true, false, Color(1, 1, 1, 0.88))
        sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
        sub.add_theme_constant_override("outline_size", 6)
        sub.anchor_left = 0.0
        sub.anchor_right = 1.0
        sub.anchor_top = 0.0
        sub.offset_top = 124.0
        sub.offset_bottom = 162.0
        sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        add_child(sub)
        title_nodes.append(sub)

## لوگوی رسمی — تزئین جداگانه؛ اگر لود شد تیتر متنی زیرش مخفی می‌شود
func _deco_logo() -> void:
        var logo_tex := _safe_load("res://assets/sprites/logo.png")
        if logo_tex == null:
                return
        for n in title_nodes:
                if is_instance_valid(n):
                        n.visible = false
        var logo := TextureRect.new()
        logo.texture = logo_tex
        logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        logo.anchor_left = 0.406
        logo.anchor_right = 0.844
        logo.anchor_top = 0.011
        logo.anchor_bottom = 0.192
        logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(logo)
        BRAIN_SCRIPT.add_breathing(logo, 2.5, 1.6)

func _build_home_panel() -> void:
        panel_home = PanelContainer.new()
        panel_home.add_theme_stylebox_override("panel", _sb(COL_GLASS, Color(0.85, 0.68, 0.28, 0.45), 22, 2))
        # چیدمان anchor-محور — نسبت به قاب ۱۲۸۰×۷۲۰؛ روی هر گوشی/RTL همان جا می‌ماند
        panel_home.anchor_left = 0.669
        panel_home.anchor_right = 0.972
        panel_home.anchor_top = 0.244
        panel_home.anchor_bottom = 0.892
        panel_home.grow_horizontal = Control.GROW_DIRECTION_BOTH
        panel_home.grow_vertical = Control.GROW_DIRECTION_BOTH
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

        # چیپ سکه — آیکون واقعی سکه؛ ایموجی در فونت‌های باندل‌شده گلیف ندارد
        # و روی گوشی مربع توخالی می‌افتد، پس از texture استفاده می‌کنیم
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
                coin_icon.custom_minimum_size = Vector2(32, 32)
                coin_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
                chip_hb.add_child(coin_icon)
        coin_label = _mk_label(str(Globals.coins), 24, true, false, COL_GOLD)
        coin_label.custom_minimum_size = Vector2(100, 44)
        coin_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
        chip_hb.add_child(coin_label)
        hb.add_child(chip)

        # پلاک اسم کودک
        var plate_box := Control.new()
        plate_box.custom_minimum_size = Vector2(300, 210)
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
        play_btn = b_play
        hb.add_child(b_play)

        var b_garage := _mk_button(Globals.L("workshop"), 25, "dark", 58)
        b_garage.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/garage.tscn"))
        hb.add_child(b_garage)

        # چند نفره آنلاین — نقشه راه؛ اکبر تیکه می‌اندازد که نسخه بعد می‌آید
        var b_online := _mk_button("آنلاین چند نفره — به‌زودی", 20, "dark", 50)
        b_online.pressed.connect(func():
                if brain != null and boghi_car != null and is_instance_valid(boghi_car):
                        brain.say(boghi_car, "akbar", "online"))
        hb.add_child(b_online)

func _build_levels_panel() -> void:
        panel_levels = PanelContainer.new()
        panel_levels.add_theme_stylebox_override("panel", _sb(Color(0.115, 0.125, 0.145, 0.97), Color(0.85, 0.68, 0.28, 0.55), 24, 3))
        var lv := VBoxContainer.new()
        lv.add_theme_constant_override("separation", 10)
        panel_levels.add_child(lv)
        # اکبر سیبیلو — معرفی‌کننده مأموریت‌ها؛ هر بار یک تیکه تازه
        var hdr := HBoxContainer.new()
        hdr.add_theme_constant_override("separation", 14)
        akbar_rect = TextureRect.new()
        akbar_rect.texture = _safe_load("res://assets/sprites/akbar.png")
        if akbar_rect.texture != null:
                akbar_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
                akbar_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
                akbar_rect.custom_minimum_size = Vector2(96, 116)
                hdr.add_child(akbar_rect)
        var ak := VBoxContainer.new()
        ak.add_theme_constant_override("separation", 2)
        var ak_name := _mk_label("اکبر سیبیلو — رئیس مأموریت‌ها", 26, false, true, COL_GOLD)
        ak_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
        ak.add_child(ak_name)
        akbar_line_label = _mk_label("", 21, true, false, COL_CREAM)
        akbar_line_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
        akbar_line_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
        akbar_line_label.add_theme_constant_override("outline_size", 5)
        ak.add_child(akbar_line_label)
        hdr.add_child(ak)
        lv.add_child(hdr)
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
                        txt += "٭" if s < st else "·"
                b.text = txt
                b.custom_minimum_size = Vector2(112, 74)
                if font_display != null:
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
        back_btn = b_back1
        lv.add_child(b_back1)
        var center := CenterContainer.new()
        center.set_anchors_preset(Control.PRESET_FULL_RECT)
        # ⛔ حیاتی: کانتینر تمام‌صفحه نباید ورودی بخرد وگرنه همه‌ی دکمه‌های
        # زیرش روی گوشی مرده می‌شوند (باگ «دکمه‌ها کار نمی‌کنند» v0.8)
        center.mouse_filter = Control.MOUSE_FILTER_IGNORE
        center.add_child(panel_levels)
        add_child(center)
        levels_center = center

func _build_version() -> void:
        var v := _mk_label("نسخه ۱٫۰ — فرمولی‌ها رسیدن", 15, true, false, Color(1, 1, 1, 0.6))
        v.anchor_left = 0.0
        v.anchor_right = 1.0
        v.anchor_top = 1.0
        v.anchor_bottom = 1.0
        v.offset_left = 16.0
        v.offset_right = -280.0
        v.offset_top = -34.0
        v.offset_bottom = -10.0
        v.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
        add_child(v)

func _build_ui() -> void:
        _build_title()
        _build_home_panel()
        _build_levels_panel()
        _build_version()
        _show(panel_home)

## مغز بوقی — آخرین و ضربه‌گیرترین تزئین
func _deco_brain() -> void:
        brain = BRAIN_SCRIPT.new()
        add_child(brain)
        if boghi_car != null and is_instance_valid(boghi_car):
                BRAIN_SCRIPT.add_breathing(boghi_car, 4.0, 1.25)
        if pride_car != null and is_instance_valid(pride_car):
                BRAIN_SCRIPT.add_breathing(pride_car, 3.0, 1.5)
        brain.start_idle_chatter(
                func(cid: String) -> Control:
                        return boghi_car if cid == "boghi" else pride_car,
                func() -> Array: return ["boghi", "pride"], 8.0, 15.0)

func _deco_version() -> void:
        # برچسب نسخه — تمام‌عرض پایین با تراز راست؛ در RTL آینه هم نمی‌شود (full-wide متقارن است)
        var l := Label.new()
        l.text = "بوقی v1.0 (build 11)"
        l.add_theme_font_size_override("font_size", 14)
        if font != null:
                l.add_theme_font_override("font", font)
        l.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
        l.anchor_left = 0.0
        l.anchor_right = 1.0
        l.anchor_top = 1.0
        l.anchor_bottom = 1.0
        l.offset_left = 16.0
        l.offset_right = -16.0
        l.offset_top = -30.0
        l.offset_bottom = -8.0
        l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        l.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(l)

func _layout_watchdog() -> void:
        # نگهبان چیدمان: اگر پنل منو روی دید نیست، هندسه‌ی واقعی را روی صفحه نشان بده
        # تا کاربر عکس بگیرد و ما مقادیر واقعی گوشی را ببینیم
        await get_tree().create_timer(1.6).timeout
        if not is_instance_valid(panel_home):
                return
        # اگر کاربر به پنل دیگری رفته، نظارت فقط مال صفحه‌ی خانه است
        if not panel_home.visible:
                return
        var vp := get_viewport_rect().size
        var gr: Rect2 = panel_home.get_global_rect()
        var on_screen: bool = panel_home.visible and gr.size.x > 60.0 and gr.size.y > 60.0 \
                and gr.position.x < vp.x - 60.0 and gr.position.y < vp.y - 60.0 \
                and gr.end.x > 60.0 and gr.end.y > 60.0
        if on_screen:
                print("[boghi][watchdog] panel OK rect=", gr, " viewport=", vp)
                return
        var msg := "خطای چیدمان — لطفاً از این صفحه عکس بگیر و بفرست\n"
        msg += "viewport=%s window=%s\n" % [vp, get_window().size]
        msg += "root=%s\npanel_global=%s visible=%s\n" % [Rect2(Vector2.ZERO, size), gr, panel_home.visible]
        msg += "locale=%s scale=%s\n" % [OS.get_locale(), get_viewport().content_scale_factor]
        print("[boghi][watchdog] ", msg.replace("\n", " | "))
        var box := PanelContainer.new()
        var sbf := StyleBoxFlat.new()
        sbf.bg_color = Color(0.25, 0.05, 0.05, 0.94)
        sbf.set_corner_radius_all(12)
        box.add_theme_stylebox_override("panel", sbf)
        box.set_anchors_preset(Control.PRESET_FULL_RECT)
        box.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var lbl := _mk_label(msg, 22, true, false, Color(1, 0.9, 0.85))
        lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        box.add_child(lbl)
        add_child(box)

func _show(p: PanelContainer) -> void:
        if panel_home == null or panel_levels == null:
                return
        panel_home.visible = p == panel_home
        panel_levels.visible = p == panel_levels
        # هر باز شدن مأموریت‌ها: تیکه تازه‌ی اکبر + صدای لاله‌زبانش
        if p == panel_levels and akbar_line_label != null:
                var line := CarBrain.pick_line("akbar", "idle")
                if line.is_empty():
                        line = "امروز جاده مال ماست!"
                akbar_line_label.text = line
                if brain != null and akbar_rect != null and is_instance_valid(akbar_rect) and akbar_rect.texture != null:
                        brain.say(akbar_rect, "akbar", "idle")
        # کانتینر مأموریت‌ها هم وقتی پنل مخفی است باید مخفی شود
        # (دو لایه محافظت: mouse_filter=IGNORE + مخفی‌سازی کامل)
        # ماشین‌های تزئینی و دکمه‌های تپ فقط مال صفحه‌ی خانه‌اند؛
        # وگرنه روی پنل مأموریت‌ها می‌افتند و تپِ دکمه‌ها را می‌دزدند
        for n in deco_cars:
                if is_instance_valid(n):
                        n.visible = p == panel_home
        if levels_center != null:
                levels_center.visible = p == panel_levels
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
