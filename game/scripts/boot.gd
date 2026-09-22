extends Control
## صحنه بوت — لایه دفاعی و تشخیصی بوقی
## همیشه یک چیزی نشان می‌دهد؛ اگر منو بالا نیاید، دلیلش روی صفحه نوشته می‌شود.

var status_label: Label
var detail_label: Label

func _ready() -> void:
        var bg := ColorRect.new()
        bg.color = Color(0.075, 0.06, 0.075)
        bg.set_anchors_preset(Control.PRESET_FULL_RECT)
        add_child(bg)

        if ResourceLoader.exists("res://assets/sprites/logo.png"):
                var logo := TextureRect.new()
                logo.texture = load("res://assets/sprites/logo.png")
                logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
                logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
                logo.set_anchors_preset(Control.PRESET_CENTER_TOP)
                logo.anchor_left = 0.3
                logo.anchor_right = 0.7
                logo.offset_top = 90.0
                logo.offset_bottom = 290.0
                logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
                add_child(logo)

        status_label = _mk_label("بوقی: تور شهرها", 44)
        status_label.set_anchors_preset(Control.PRESET_CENTER)
        status_label.anchor_top = 0.52
        status_label.anchor_bottom = 0.60
        status_label.offset_left = -300
        status_label.offset_right = 300
        add_child(status_label)

        detail_label = _mk_label("", 15)
        detail_label.set_anchors_preset(Control.PRESET_CENTER)
        detail_label.anchor_top = 0.62
        detail_label.anchor_bottom = 0.95
        detail_label.offset_left = -420
        detail_label.offset_right = 420
        detail_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
        add_child(detail_label)

        var model := OS.get_model_name()
        var ver := Engine.get_version_info()
        var ver_str := "%d.%d.%d" % [ver["major"], ver["minor"], ver["patch"]]
        detail_label.text = "Loading menu… / در حال باز کردن منو\n" + model + " — Godot " + ver_str + "\nاگر بالای صفحه «v0.8» طلایی نمی‌بینی، یعنی فایل قدیمی نصب شده"
        # پلاک نسخه — بزرگ و طلایی، بالای صفحه؛ انگشت‌نگاری بیلد v0.7
        var ver_label := _mk_label("بوقی v0.8 — بیلد ۹", 34)
        ver_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
        ver_label.anchor_top = 0.02
        ver_label.anchor_bottom = 0.11
        ver_label.offset_left = 16
        ver_label.offset_right = -16
        ver_label.add_theme_color_override("font_color", Color(0.96, 0.76, 0.25))
        add_child(ver_label)
        _go_menu()

func _mk_label(txt: String, size: int) -> Label:
        var l := Label.new()
        l.text = txt
        l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        l.add_theme_font_size_override("font_size", size)
        var f := load("res://assets/fonts/Vazirmatn-Bold.ttf")
        if f != null:
                l.add_theme_font_override("font", f)
        return l

func _go_menu() -> void:
        await get_tree().process_frame
        await get_tree().process_frame
        var packed: PackedScene = load("res://scenes/menu.tscn")
        if packed == null:
                _fail("منو پیدا نشد: res://scenes/menu.tscn")
                return
        var inst := packed.instantiate()
        if inst == null:
                _fail("ساخت صحنه منو شکست خورد (instantiate = null)")
                return
        get_tree().root.add_child.call_deferred(inst)
        await get_tree().create_timer(1.0).timeout
        if not is_instance_valid(self):
                return
        # چک سلامت: پنل اصلی منو باید ساخته شده باشد؛ وگرنه دلیلش را نشان بده
        if inst.get("panel_home") == null:
                _fail("منو نیمه‌کاره ماند (پنل اصلی ساخته نشد — جزئیات از لاگ پایین صفحه)")
                return
        detail_label.text = "منو آماده شد — نسخه درست نصب شده"
        var tw := create_tween()
        tw.tween_property(self, "modulate:a", 0.0, 0.35)
        tw.tween_callback(queue_free)

func _fail(msg: String) -> void:
        status_label.text = "خطای راه‌اندازی"
        var tail := _log_tail()
        detail_label.text += "\n\n" + msg
        if tail != "":
                detail_label.text += "\n\n— آخرِ لاگ —\n" + tail
        detail_label.text += "\nلطفاً از این صفحه عکس بگیر و برایم بفرست"
        detail_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))

func _log_tail() -> String:
        # لاگ گودوت (file_logging فعال است) — خطاهای اسکریپت روی صفحه نشان داده می‌شوند
        for p in ["user://logs/godot.log", "user://logs/godot.log.1"]:
                if not FileAccess.file_exists(p):
                        continue
                var f := FileAccess.open(p, FileAccess.READ)
                if f == null:
                        continue
                var lines: Array[String] = []
                while not f.eof_reached():
                        var l := f.get_line()
                        if l.strip_edges() != "":
                                lines.append(l)
                f.close()
                var errs: Array[String] = []
                for l in lines:
                        if l.contains("ERROR") or l.contains("Failed") or l.contains("error"):
                                errs.append(l)
                var pick: Array[String] = errs if not errs.is_empty() else lines
                var out := ""
                for i in range(max(0, pick.size() - 7), pick.size()):
                        out += pick[i].substr(0, 110) + "\n"
                if out != "":
                        return out
        return ""
