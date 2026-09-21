extends Control
## Main menu: home (plate name), missions list (50), garage (cars + upgrades)

var font: FontFile
var font_bold: FontFile
var panel_home: PanelContainer
var panel_levels: PanelContainer
var panel_garage: PanelContainer
var coin_label: Label
var plate_edit: LineEdit

func _ready() -> void:
        font = load("res://assets/fonts/Vazirmatn-Regular.ttf")
        font_bold = load("res://assets/fonts/Vazirmatn-Bold.ttf")
        _build_ui()
        _refresh()
        if OS.get_cmdline_user_args().has("--autotest"):
                await get_tree().create_timer(1.5).timeout
                get_viewport().get_texture().get_image().save_png("/home/z/my-project/scripts/shot_menu.png")
                get_tree().quit()

func _mk_label(txt: String, size: int, bold := false) -> Label:
        var l := Label.new()
        l.text = txt
        l.add_theme_font_override("font", font_bold if bold else font)
        l.add_theme_font_size_override("font_size", size)
        l.add_theme_color_override("font_color", Color(0.29, 0.216, 0.157))
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
                sb.shadow_color = Color(0.25, 0.16, 0.09, 0.28)
                sb.shadow_size = 8
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

func _mk_button(txt: String, size := 26, primary := true) -> Button:
        var b := Button.new()
        b.text = txt
        b.add_theme_font_override("font", font_bold)
        b.add_theme_font_size_override("font_size", size)
        b.custom_minimum_size = Vector2(200, 64)
        _style_btn(b, primary)
        return b

func _build_ui() -> void:
        var bg := TextureRect.new()
        bg.texture = load("res://assets/sprites/menu_bg.png")
        bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        bg.set_anchors_preset(Control.PRESET_FULL_RECT)
        add_child(bg)

        var center := CenterContainer.new()
        center.set_anchors_preset(Control.PRESET_FULL_RECT)
        add_child(center)

        # ---------- HOME ----------
        panel_home = PanelContainer.new()
        var hb := VBoxContainer.new()
        hb.add_theme_constant_override("separation", 14)
        hb.custom_minimum_size = Vector2(640, 0)
        panel_home.add_child(hb)

        hb.add_child(_mk_label("بوقی: تور شهرها", 48, true))
        hb.add_child(_mk_label("فصل ۱ — تهران", 26))

        var plate_box := Control.new()
        plate_box.custom_minimum_size = Vector2(300, 290)
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
        plate_edit.add_theme_font_size_override("font_size", 32)
        plate_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
        plate_edit.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
        plate_edit.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
        plate_edit.add_theme_color_override("font_color", Color(0.29, 0.216, 0.157))
        plate_edit.add_theme_color_override("caret_color", Color(0.29, 0.216, 0.157))
        plate_edit.add_theme_color_override("font_placeholder_color", Color(0.62, 0.5, 0.38))
        plate_edit.placeholder_text = "..."
        plate_edit.anchor_left = 0.16
        plate_edit.anchor_right = 0.84
        plate_edit.anchor_top = 0.50
        plate_edit.anchor_bottom = 0.80
        plate_edit.text_changed.connect(func(_t): _on_plate_changed())
        plate_box.add_child(plate_edit)
        hb.add_child(plate_box)

        var b_play := _mk_button(Globals.L("play"), 30)
        b_play.pressed.connect(func(): _show(panel_levels))
        hb.add_child(b_play)
        var b_garage := _mk_button(Globals.L("garage"), 30)
        b_garage.pressed.connect(func(): _show(panel_garage))
        hb.add_child(b_garage)

        coin_label = _mk_label("🪙 " + str(Globals.coins), 28, true)
        hb.add_child(coin_label)
        center.add_child(panel_home)

        # ---------- LEVELS ----------
        panel_levels = PanelContainer.new()
        var lv := VBoxContainer.new()
        panel_levels.add_child(lv)
        lv.add_child(_mk_label(Globals.L("levels") + " — " + "تهران", 34, true))
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
                b.custom_minimum_size = Vector2(112, 78)
                b.add_theme_font_override("font", font)
                b.add_theme_font_size_override("font_size", 20)
                b.disabled = not Globals.level_unlocked(id)
                _style_btn(b, false)
                b.pressed.connect(_start_level.bind(id))
                grid.add_child(b)
        scroll.add_child(grid)
        lv.add_child(scroll)
        var b_back1 := _mk_button(Globals.L("back"), 24)
        b_back1.pressed.connect(func(): _show(panel_home))
        lv.add_child(b_back1)
        center.add_child(panel_levels)

        # ---------- GARAGE ----------
        panel_garage = PanelContainer.new()
        var gv := VBoxContainer.new()
        gv.add_theme_constant_override("separation", 8)
        panel_garage.add_child(gv)
        gv.add_child(_mk_label(Globals.L("garage") + " — استاد فنر", 34, true))
        var gscroll := ScrollContainer.new()
        gscroll.custom_minimum_size = Vector2(1000, 470)
        var gcol := VBoxContainer.new()
        gcol.add_theme_constant_override("separation", 6)
        gscroll.add_child(gcol)

        for i in Globals.CARS.size():
                var c = Globals.CARS[i]
                var row := HBoxContainer.new()
                row.add_theme_constant_override("separation", 16)
                var pic := TextureRect.new()
                pic.texture = load(c["tex"])
                pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
                pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
                pic.custom_minimum_size = Vector2(180, 90)
                row.add_child(pic)
                var info := VBoxContainer.new()
                info.custom_minimum_size = Vector2(320, 0)
                info.add_child(_mk_label(str(c["name"]), 26, true))
                info.add_child(_mk_label(str(c["desc"]), 20))
                row.add_child(info)
                var cb := Button.new()
                cb.custom_minimum_size = Vector2(170, 56)
                cb.add_theme_font_override("font", font_bold)
                cb.add_theme_font_size_override("font_size", 22)
                cb.set_meta("car_index", i)
                _style_btn(cb, true)
                cb.pressed.connect(_on_car_button.bind(i))
                row.add_child(cb)
                gcol.add_child(row)

        gcol.add_child(HSeparator.new())
        for u in Globals.UPGRADES:
                var urow := HBoxContainer.new()
                urow.add_theme_constant_override("separation", 16)
                urow.add_child(_mk_label(str(u["name"]) + " — " + str(u["desc"]), 22))
                var lvl_label := Label.new()
                lvl_label.name = "ul_" + str(u["id"])
                urow.add_child(lvl_label)
                var ub := Button.new()
                ub.set_meta("up_id", str(u["id"]))
                ub.custom_minimum_size = Vector2(220, 52)
                ub.add_theme_font_override("font", font_bold)
                ub.pressed.connect(_on_upgrade.bind(str(u["id"])))
                ub.name = "ub_" + str(u["id"])
                _style_btn(ub, false)
                urow.add_child(ub)
                gcol.add_child(urow)

        gv.add_child(gscroll)
        var b_back2 := _mk_button(Globals.L("back"), 24)
        b_back2.pressed.connect(func(): _show(panel_home))
        gv.add_child(b_back2)
        center.add_child(panel_garage)

        for p in [panel_home, panel_levels, panel_garage]:
                p.add_theme_stylebox_override("panel", _sb(Color(0.99, 0.965, 0.9), Color(0.29, 0.216, 0.157), 26, 5))

        _show(panel_home)

func _show(p: PanelContainer) -> void:
        panel_home.visible = p == panel_home
        panel_levels.visible = p == panel_levels
        panel_garage.visible = p == panel_garage
        if p == panel_garage:
                _refresh_garage()
        _refresh()

func _on_plate_changed() -> void:
        Globals.plate_name = plate_edit.text.strip_edges()
        if Globals.plate_name.is_empty():
                Globals.plate_name = "بوقی"
        Globals.save_game()

func _on_car_button(i: int) -> void:
        if Globals.unlocked_car[i]:
                Globals.selected_car = i
                Globals.save_game()
        elif not Globals.buy_car(i):
                pass
        _refresh_garage()
        _refresh()

func _on_upgrade(uid: String) -> void:
        Globals.do_upgrade(uid)
        _refresh_garage()
        _refresh()

func _refresh_garage() -> void:
        _scan_and_refresh(panel_garage)

func _scan_and_refresh(root: Node) -> void:
        for ch in root.get_children():
                if ch is Button and ch.has_meta("car_index"):
                        var i: int = ch.get_meta("car_index")
                        if Globals.selected_car == i:
                                ch.text = Globals.L("selected")
                        elif Globals.unlocked_car[i]:
                                ch.text = Globals.L("select")
                        else:
                                ch.text = Globals.L("buy") + " " + str(Globals.CARS[i]["price"])
                elif ch is Button and ch.has_meta("up_id"):
                        var uid: String = ch.get_meta("up_id")
                        var lvl: int = Globals.upgrades[uid]
                        var cost := Globals.upgrade_cost(uid)
                        var dots := ""
                        for k in 3:
                                dots += "●" if k < lvl else "○"
                        var ll: Label = panel_garage.find_child("ul_" + uid, true, false)
                        if ll:
                                ll.text = dots
                        ch.text = Globals.L("max") if cost < 0 else str(cost) + " 🪙"
                _scan_and_refresh(ch)

func _refresh() -> void:
        if coin_label:
                coin_label.text = "🪙 " + str(Globals.coins)
        if plate_edit:
                plate_edit.text = Globals.plate_name

func _start_level(id: int) -> void:
        Globals.set_meta("start_level", id)
        get_tree().change_scene_to_file("res://scenes/game.tscn")
