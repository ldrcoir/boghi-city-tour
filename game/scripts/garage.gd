extends Control
## کارگاه استاد فنر — گاراژ و تیونینگ با انیمیشن استاد در حال کار
## چیدمان منظم: عنوان بالا، ویترین ماشین وسط-چپ، استاد کنار ماشین، تب‌ها سمت راست

var font: FontFile
var font_bold: FontFile
var font_display: FontFile

var coin_label: Label
var car_pic: TextureRect
var car_name_label: Label
var ustad: TextureRect
var sparks: CPUParticles2D
var tab_cars_btn: Button
var tab_ups_btn: Button
var cars_grid: GridContainer
var ups_box: VBoxContainer
var toast: Label

var car_buttons: Array = []
var up_buttons := {}      # uid -> Button
var up_dots := {}         # uid -> Label
var _working := false
var _demo_timer: Timer
var brain = null

# بارگذاری مستقیم مغز — بدون وابستگی به class cache
const BRAIN_SCRIPT := preload("res://scripts/car_brain.gd")

func _ready() -> void:
        font = load("res://assets/fonts/Vazirmatn-Regular.ttf")
        font_bold = load("res://assets/fonts/Vazirmatn-Bold.ttf")
        font_display = load("res://assets/fonts/Lalezar-Regular.ttf")
        _build()
        _refresh()
        AudioMgr.play_music()
        # مغز بوقی در کارگاه: ماشین‌ها و استاد فنر حرف می‌زنند
        brain = BRAIN_SCRIPT.new()
        add_child(brain)
        BRAIN_SCRIPT.add_breathing(car_pic, 3.0, 1.4)
        brain.start_idle_chatter(
                func(cid: String) -> Control:
                        return ustad if cid == "ustad" else car_pic,
                func() -> Array:
                        return [str(Globals.CARS[Globals.selected_car]["id"]), "ustad"], 9.0, 16.0)
        if OS.get_cmdline_user_args().has("--autotest"):
                if brain != null:
                        brain.say(car_pic, str(Globals.CARS[Globals.selected_car]["id"]), "select")
                await get_tree().create_timer(1.35).timeout
                get_viewport().get_texture().get_image().save_png("/home/z/my-project/scripts/shot_garage.png")
                await get_tree().create_timer(0.75).timeout
                get_viewport().get_texture().get_image().save_png("/home/z/my-project/scripts/shot_garage2.png")
                get_tree().quit()

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
                sb.shadow_color = Color(0.1, 0.06, 0.04, 0.4)
                sb.shadow_size = 8
        return sb

func _style_btn(b: Button, primary := true) -> void:
        var base := Color(0.165, 0.616, 0.561) if primary else Color(0.965, 0.886, 0.737)
        var dark := Color(0.11, 0.42, 0.385) if primary else Color(0.8, 0.66, 0.42)
        b.add_theme_stylebox_override("normal", _sb(base, dark, 14, 3))
        b.add_theme_stylebox_override("hover", _sb(base.lightened(0.07), dark, 14, 3))
        b.add_theme_stylebox_override("pressed", _sb(dark, dark, 14, 3))
        var fg := Color(1, 1, 1) if primary else Color(0.29, 0.216, 0.157)
        b.add_theme_color_override("font_color", fg)
        b.add_theme_color_override("font_hover_color", fg)
        b.add_theme_color_override("font_focus_color", fg)
        b.add_theme_color_override("font_pressed_color", Color(1, 1, 1))

func _mk_label(txt: String, size: int, bold := false, display := false, col := Color(0.29, 0.216, 0.157)) -> Label:
        var l := Label.new()
        l.text = txt
        l.add_theme_font_override("font", font_display if display else (font_bold if bold else font))
        l.add_theme_font_size_override("font_size", size)
        l.add_theme_color_override("font_color", col)
        return l

func _build() -> void:
        # پس‌زمینه کارگاه گرم و پرنور
        var bg := TextureRect.new()
        bg.texture = load("res://assets/sprites/garage_bg.png")
        bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        bg.set_anchors_preset(Control.PRESET_FULL_RECT)
        add_child(bg)

        # دکمه برگشت (بالا-چپ)
        var b_back := Button.new()
        b_back.text = Globals.L("back")
        b_back.add_theme_font_override("font", font_display)
        b_back.add_theme_font_size_override("font_size", 26)
        b_back.position = Vector2(14, 14)
        b_back.size = Vector2(120, 54)
        _style_btn(b_back, false)
        b_back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/menu.tscn"))
        add_child(b_back)

        # عنوان کارگاه
        var title := _mk_label(Globals.L("workshop"), 46, false, true, Color(0.95, 0.75, 0.14))
        title.add_theme_color_override("font_outline_color", Color(0.22, 0.12, 0.05))
        title.add_theme_constant_override("outline_size", 12)
        title.position = Vector2(120, 14)
        title.custom_minimum_size = Vector2(780, 0)
        title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        add_child(title)

        # سکه‌ها (بالا-چپ، کنار دکمه برگشت)
        # آیکون سکه + عدد — به‌جای ایموجی که در فونت گوشی نیست
        if ResourceLoader.exists("res://assets/sprites/coin.png"):
                var coin_icon := TextureRect.new()
                coin_icon.texture = load("res://assets/sprites/coin.png")
                coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
                coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
                coin_icon.position = Vector2(118, 22)
                coin_icon.size = Vector2(36, 36)
                coin_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
                add_child(coin_icon)
        coin_label = _mk_label(str(Globals.coins), 30, true, false, Color(0.98, 0.85, 0.3))
        coin_label.add_theme_color_override("font_outline_color", Color(0.22, 0.12, 0.05))
        coin_label.add_theme_constant_override("outline_size", 8)
        coin_label.position = Vector2(160, 28)
        add_child(coin_label)

        # سایه و ویترین ماشین (وسط-چپ)
        var shadow := Sprite2D.new()
        shadow.texture = _make_shadow_tex()
        shadow.position = Vector2(360, 558)
        shadow.scale = Vector2(2.4, 1.0)
        add_child(shadow)
        car_pic = TextureRect.new()
        car_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        car_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        car_pic.position = Vector2(50, 285)
        car_pic.size = Vector2(620, 265)
        add_child(car_pic)
        car_name_label = _mk_label("", 30, false, true, Color(0.99, 0.93, 0.78))
        car_name_label.add_theme_color_override("font_outline_color", Color(0.22, 0.12, 0.05))
        car_name_label.add_theme_constant_override("outline_size", 10)
        car_name_label.position = Vector2(50, 566)
        car_name_label.custom_minimum_size = Vector2(620, 0)
        car_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        add_child(car_name_label)

        # جرقه هنگام ارتقا
        sparks = CPUParticles2D.new()
        sparks.position = Vector2(360, 440)
        sparks.emitting = false
        sparks.one_shot = true
        sparks.explosiveness = 1.0
        sparks.amount = 90
        sparks.lifetime = 0.75
        sparks.spread = 180.0
        sparks.initial_velocity_min = 220.0
        sparks.initial_velocity_max = 520.0
        sparks.gravity = Vector2(0, 700)
        sparks.scale_amount_min = 3.0
        sparks.scale_amount_max = 6.0
        var sg := Gradient.new()
        sg.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
        sg.colors = PackedColorArray([Color(1.0, 0.97, 0.6, 1.0), Color(1.0, 0.6, 0.1, 0.9), Color(0.9, 0.2, 0.02, 0.0)])
        sparks.color_ramp = sg
        var mat := CanvasItemMaterial.new()
        mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
        sparks.material = mat
        add_child(sparks)

        # استاد فنر — سیبیلو با انیمیشن نفس‌کشیدن کنار ماشین
        ustad = TextureRect.new()
        ustad.texture = load("res://assets/sprites/ustad.png")
        ustad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        ustad.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        ustad.position = Vector2(660, 350)
        ustad.size = Vector2(250, 330)
        ustad.pivot_offset = Vector2(125, 330)
        add_child(ustad)
        var u_name := _mk_label("استاد فنر", 26, false, true, Color(0.98, 0.9, 0.7))
        u_name.add_theme_color_override("font_outline_color", Color(0.22, 0.12, 0.05))
        u_name.add_theme_constant_override("outline_size", 8)
        u_name.position = Vector2(660, 682)
        u_name.custom_minimum_size = Vector2(250, 0)
        u_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        add_child(u_name)
        var idle := create_tween().set_loops()
        idle.tween_property(ustad, "position:y", 342.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        idle.tween_property(ustad, "position:y", 356.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

        # پنل راست: تب‌ها + محتوا (چیدمان منظم)
        var panel := PanelContainer.new()
        panel.add_theme_stylebox_override("panel", _sb(Color(0.99, 0.96, 0.88, 0.98), Color(0.29, 0.216, 0.157), 22, 5))
        panel.position = Vector2(930, 70)
        panel.size = Vector2(336, 620)
        add_child(panel)

        var pv := VBoxContainer.new()
        pv.add_theme_constant_override("separation", 8)
        panel.add_child(pv)

        var tabs := HBoxContainer.new()
        tabs.add_theme_constant_override("separation", 8)
        pv.add_child(tabs)
        tab_ups_btn = Button.new()
        tab_ups_btn.text = Globals.L("tab_ups")
        tab_ups_btn.add_theme_font_override("font", font_display)
        tab_ups_btn.add_theme_font_size_override("font_size", 24)
        tab_ups_btn.custom_minimum_size = Vector2(150, 52)
        tab_ups_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        tab_ups_btn.pressed.connect(func(): _switch_tab(false))
        tabs.add_child(tab_ups_btn)
        tab_cars_btn = Button.new()
        tab_cars_btn.text = Globals.L("tab_cars")
        tab_cars_btn.add_theme_font_override("font", font_display)
        tab_cars_btn.add_theme_font_size_override("font_size", 24)
        tab_cars_btn.custom_minimum_size = Vector2(150, 52)
        tab_cars_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        tab_cars_btn.pressed.connect(func(): _switch_tab(true))
        tabs.add_child(tab_cars_btn)

        var scroll := ScrollContainer.new()
        scroll.custom_minimum_size = Vector2(306, 520)
        scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
        pv.add_child(scroll)

        var content := VBoxContainer.new()
        content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        scroll.add_child(content)

        # تب ماشین‌ها: گرید ۲ ستونه
        cars_grid = GridContainer.new()
        cars_grid.columns = 2
        cars_grid.add_theme_constant_override("h_separation", 8)
        cars_grid.add_theme_constant_override("v_separation", 8)
        content.add_child(cars_grid)
        for i in Globals.CARS.size():
                cars_grid.add_child(_car_card(i))

        # تب ارتقا: سه ردیف منظم
        ups_box = VBoxContainer.new()
        ups_box.add_theme_constant_override("separation", 10)
        content.add_child(ups_box)
        for u in Globals.UPGRADES:
                var uid: String = u["id"]
                var row := PanelContainer.new()
                row.add_theme_stylebox_override("panel", _sb(Color(0.97, 0.92, 0.8), Color(0.8, 0.66, 0.42), 14, 2, false))
                var hb := HBoxContainer.new()
                hb.add_theme_constant_override("separation", 8)
                row.add_child(hb)
                var info := VBoxContainer.new()
                info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                info.add_child(_mk_label(str(u["name"]), 22, false, true))
                info.add_child(_mk_label(str(u["desc"]), 15))
                hb.add_child(info)
                var right := VBoxContainer.new()
                right.alignment = BoxContainer.ALIGNMENT_CENTER
                var dots := _mk_label("", 20, true, false, Color(0.72, 0.52, 0.1))
                dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                right.add_child(dots)
                up_dots[uid] = dots
                var b := Button.new()
                b.custom_minimum_size = Vector2(110, 44)
                b.add_theme_font_override("font", font_bold)
                b.add_theme_font_size_override("font_size", 17)
                b.pressed.connect(_on_upgrade.bind(uid))
                _style_btn(b, true)
                right.add_child(b)
                up_buttons[uid] = b
                hb.add_child(right)
                ups_box.add_child(row)

        toast = _mk_label("", 19, true, false, Color(0.75, 0.2, 0.1))
        toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        toast.modulate.a = 0.0
        add_child(toast)

        _switch_tab(true)

        # استاد هر از چندی خودش سرِ کار می‌رود — گاراژ همیشه زنده است
        _demo_timer = Timer.new()
        _demo_timer.wait_time = 7.0
        _demo_timer.autostart = true
        _demo_timer.timeout.connect(_ustad_work)
        add_child(_demo_timer)
        # همین که وارد گاراژ می‌شوی، استاد مشغول کار است
        get_tree().create_timer(0.8).timeout.connect(_ustad_work)

func _car_card(i: int) -> Control:
        var c = Globals.CARS[i]
        var card := PanelContainer.new()
        card.add_theme_stylebox_override("panel", _sb(Color(0.97, 0.92, 0.8), Color(0.8, 0.66, 0.42), 14, 2, false))
        var vb := VBoxContainer.new()
        vb.add_theme_constant_override("separation", 2)
        card.add_child(vb)
        var pic := TextureRect.new()
        pic.texture = load(c["tex"])
        pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        pic.custom_minimum_size = Vector2(140, 58)
        vb.add_child(pic)
        var nm := _mk_label(str(c["name"]), 17, true)
        nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        vb.add_child(nm)
        var b := Button.new()
        b.custom_minimum_size = Vector2(140, 40)
        b.add_theme_font_override("font", font_bold)
        b.add_theme_font_size_override("font_size", 15)
        b.set_meta("car_index", i)
        _style_btn(b, true)
        b.pressed.connect(_on_car_button.bind(i))
        vb.add_child(b)
        car_buttons.append(b)
        return card

func _switch_tab(cars_tab: bool) -> void:
        cars_grid.visible = cars_tab
        ups_box.visible = not cars_tab
        tab_cars_btn.disabled = cars_tab
        tab_ups_btn.disabled = not cars_tab

func _on_car_button(i: int) -> void:
        if Globals.unlocked_car[i]:
                Globals.selected_car = i
                Globals.save_game()
                AudioMgr.play_sfx("coin")
        elif not Globals.buy_car(i):
                _show_toast("سکه کافی نداری! مأموریت برو")
                if brain != null:
                        brain.say(car_pic, str(Globals.CARS[Globals.selected_car]["id"]), "poor")
                return
        else:
                AudioMgr.play_sfx("win")
        _refresh()
        _ustad_work()
        if brain != null:
                var cid := str(Globals.CARS[Globals.selected_car]["id"])
                brain.say(car_pic, cid, "select")

func _on_upgrade(uid: String) -> void:
        if not Globals.do_upgrade(uid):
                var cost := Globals.upgrade_cost(uid)
                if cost > 0:
                        _show_toast("سکه کافی نداری! مأموریت برو")
                return
        AudioMgr.play_sfx("clank")
        _refresh()
        _ustad_work()
        if brain != null:
                brain.say(car_pic, str(Globals.CARS[Globals.selected_car]["id"]), "upgrade")

func _ustad_work() -> void:
        # انیمیشن واقعی «استاد در حال کار»: سه ضربه آچار، جرقه، صدای فلز، لرزش ماشین
        if _working:
                return
        _working = true
        AudioMgr.play_sfx("boost")
        if brain != null and _rng_ustad():
                brain.say(ustad, "ustad", "idle")
        for i in 3:
                var raise := create_tween()
                raise.tween_property(ustad, "rotation_degrees", -17.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
                await get_tree().create_timer(0.18).timeout
                var strike := create_tween()
                strike.tween_property(ustad, "rotation_degrees", 9.0, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
                sparks.restart()
                sparks.emitting = true
                AudioMgr.play_sfx("clank")
                _shake_car()
                await get_tree().create_timer(0.38).timeout
        var settle := create_tween()
        settle.tween_property(ustad, "rotation_degrees", 0.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        await settle.finished
        _working = false

func _shake_car() -> void:
        # ماشین روی جک با هر ضربه می‌لرزد
        var base := car_pic.position
        var t := create_tween()
        t.tween_property(car_pic, "position:x", base.x + 5.0, 0.05)
        t.tween_property(car_pic, "position:x", base.x - 4.0, 0.05)
        t.tween_property(car_pic, "position:x", base.x, 0.05)

func _rng_ustad() -> bool:
        return randf() < 0.45

func _show_toast(msg: String) -> void:
        toast.text = msg
        toast.position = Vector2(330, 640)
        toast.custom_minimum_size = Vector2(620, 0)
        toast.modulate.a = 1.0
        var t := create_tween()
        t.tween_interval(1.2)
        t.tween_property(toast, "modulate:a", 0.0, 0.6)

func _refresh() -> void:
        coin_label.text = str(Globals.coins)
        var c = Globals.CARS[Globals.selected_car]
        car_pic.texture = load(c["tex"])
        car_name_label.text = str(c["name"])
        for b in car_buttons:
                var i: int = b.get_meta("car_index")
                if Globals.selected_car == i:
                        b.text = Globals.L("selected")
                        b.disabled = true
                elif Globals.unlocked_car[i]:
                        b.text = Globals.L("select")
                        b.disabled = false
                else:
                        b.text = Globals.L("buy") + " " + str(Globals.CARS[i]["price"])
                        b.disabled = false
        for uid in up_buttons:
                var lvl: int = Globals.upgrades[uid]
                var cost := Globals.upgrade_cost(uid)
                var dots := ""
                for k in 3:
                        dots += "•" if k < lvl else "·"
                up_dots[uid].text = dots
                up_buttons[uid].text = Globals.L("max") if cost < 0 else str(cost) + " سکه"
                up_buttons[uid].disabled = cost < 0

func _make_shadow_tex() -> ImageTexture:
    var sz := Vector2i(240, 64)
    var img := Image.create(sz.x, sz.y, false, Image.FORMAT_RGBA8)
    var cx := sz.x / 2.0
    var cy := sz.y / 2.0
    for y in sz.y:
        for x in sz.x:
            var d := Vector2((x - cx) / (cx - 6.0), (y - cy) / (cy - 4.0)).length()
            var a: float = clamp(1.0 - d, 0.0, 1.0)
            img.set_pixel(x, y, Color(0.05, 0.03, 0.02, a * a * 0.75))
    return ImageTexture.create_from_image(img)
