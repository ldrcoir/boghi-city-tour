extends Control
## OnlineRace — پوشش جست‌وجوی حریف آنلاین + جایگزینی هوشمند AI
## FSM: SEARCHING (0..wait) → TIMEOUT → TAKEOVER(اکبر می‌آید) → سیگنال ai_takeover
## وقتی سرور آماده شد فقط بخش transport داخل SEARCHING سیم می‌شود؛ بقیه دست‌نخورده.
## طراحی داستانی: لودر خشک ممنوع — خط‌های بوقی حوصله‌ی کاربر را نگه می‌دارد.

signal ai_takeover
signal cancelled

const COL_GLASS := Color(0.10, 0.11, 0.13, 0.96)
const COL_GOLD := Color(0.96, 0.76, 0.25)
const COL_CREAM := Color(0.95, 0.93, 0.88)
const COL_RED := Color(0.78, 0.15, 0.12)

const SEARCH_LINES := [
        "دنبال یه راننده‌ی واقعی تو محله…",
        "کی‌چی آنلاینه؟… داری گرم می‌شی؟",
        "یه حریف از سراسر ایران… صبر کن هنوز!",
        "اینترنت محله نفسش بند اومد…",
]
const TAKEOVER_LINES := [
        "پیدا نشد! اکبر پشت فرمون می‌شینه…",
        "اکبر: بگذریم که حاجی‌خانم منتظره!",
]

var wait_s := 15.0
var _phase := "SEARCHING"
var _t := 0.0
var _status: Label
var _dots: Label
var _bar: ProgressBar
var _done := false

func _ready() -> void:
        layout_direction = Control.LAYOUT_DIRECTION_LTR
        set_anchors_preset(Control.PRESET_FULL_RECT)
        var veil := ColorRect.new()
        veil.color = Color(0, 0, 0, 0.72)
        veil.set_anchors_preset(Control.PRESET_FULL_RECT)
        add_child(veil)
        var panel := PanelContainer.new()
        var sb := StyleBoxFlat.new()
        sb.bg_color = COL_GLASS
        sb.border_color = COL_GOLD
        sb.set_border_width_all(2)
        sb.set_corner_radius_all(22)
        sb.shadow_color = Color(0, 0, 0, 0.55)
        sb.shadow_size = 14
        sb.content_margin_left = 26
        sb.content_margin_right = 26
        sb.content_margin_top = 20
        sb.content_margin_bottom = 20
        panel.add_theme_stylebox_override("panel", sb)
        panel.custom_minimum_size = Vector2(560, 300)
        panel.set_anchors_preset(Control.PRESET_CENTER)
        panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
        panel.grow_vertical = Control.GROW_DIRECTION_BOTH
        add_child(panel)
        var vb := VBoxContainer.new()
        vb.add_theme_constant_override("separation", 14)
        vb.alignment = BoxContainer.ALIGNMENT_CENTER
        panel.add_child(vb)
        var f_d := _font("res://assets/fonts/Lalezar-Regular.ttf")
        var f_b := _font("res://assets/fonts/Vazirmatn-Bold.ttf")
        var title := Label.new()
        title.text = "مسابقه آنلاین"
        if f_d != null:
                title.add_theme_font_override("font", f_d)
        title.add_theme_font_size_override("font_size", 34)
        title.add_theme_color_override("font_color", COL_GOLD)
        title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        vb.add_child(title)
        _status = Label.new()
        if f_b != null:
                _status.add_theme_font_override("font", f_b)
        _status.add_theme_font_size_override("font_size", 21)
        _status.add_theme_color_override("font_color", COL_CREAM)
        _status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        _status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        _status.custom_minimum_size = Vector2(500, 60)
        vb.add_child(_status)
        _dots = Label.new()
        _dots.text = "• • •"
        _dots.add_theme_font_size_override("font_size", 26)
        _dots.add_theme_color_override("font_color", COL_GOLD)
        _dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        vb.add_child(_dots)
        _bar = ProgressBar.new()
        _bar.min_value = 0
        _bar.max_value = 1.0
        _bar.value = 0.0
        _bar.show_percentage = false
        _bar.custom_minimum_size = Vector2(500, 14)
        var fill := StyleBoxFlat.new()
        fill.bg_color = COL_RED
        fill.set_corner_radius_all(7)
        _bar.add_theme_stylebox_override("fill", fill)
        var bg_sb := StyleBoxFlat.new()
        bg_sb.bg_color = Color(0.18, 0.19, 0.22)
        bg_sb.set_corner_radius_all(7)
        _bar.add_theme_stylebox_override("background", bg_sb)
        vb.add_child(_bar)
        var hint := Label.new()
        hint.text = "دلتنگ نشدی؟ می‌تونی صبر کنی، اکبر همیشه در دسترسه!"
        if f_b != null:
                hint.add_theme_font_override("font", f_b)
        hint.add_theme_font_size_override("font_size", 15)
        hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
        hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        vb.add_child(hint)
        var cancel := Button.new()
        cancel.text = "بی‌خیال"
        if f_b != null:
                cancel.add_theme_font_override("font", f_b)
        cancel.add_theme_font_size_override("font_size", 18)
        cancel.custom_minimum_size = Vector2(180, 48)
        cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        var csb := StyleBoxFlat.new()
        csb.bg_color = Color(0.20, 0.22, 0.25)
        csb.set_corner_radius_all(12)
        cancel.add_theme_stylebox_override("normal", csb)
        cancel.pressed.connect(func(): _finish(false))
        vb.add_child(cancel)

func _font(path: String) -> FontFile:
        if ResourceLoader.exists(path):
                var r := load(path)
                if r is FontFile:
                        return r
        return null

func start(p_wait_s := 15.0) -> void:
        wait_s = maxf(5.0, p_wait_s)
        _phase = "SEARCHING"
        _t = 0.0
        _status.text = SEARCH_LINES[0]

func _process(delta: float) -> void:
        if _done:
                return
        _t += delta
        _dots.visible = fmod(_t, 0.8) < 0.55
        if _phase == "SEARCHING":
                _bar.value = clamp(_t / wait_s, 0.0, 1.0)
                var idx := int(_t / maxf(wait_s / SEARCH_LINES.size(), 0.01))
                _status.text = SEARCH_LINES[clampi(idx, 0, SEARCH_LINES.size() - 1)]
                if _t >= wait_s:
                        _phase = "TAKEOVER"
                        _t = 0.0
                        _status.text = TAKEOVER_LINES[0]
                        _status.add_theme_color_override("font_color", Color(0.95, 0.55, 0.35))
        elif _phase == "TAKEOVER":
                _status.text = TAKEOVER_LINES[0] if _t < 1.4 else TAKEOVER_LINES[1]
                if _t >= 2.6:
                        _finish(true)

func _finish(takeover: bool) -> void:
        if _done:
                return
        _done = true
        if takeover:
                ai_takeover.emit()
        else:
                cancelled.emit()
        queue_free()
