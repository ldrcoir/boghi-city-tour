extends Control
## DialogueBox — حباب دیالوگ نواری پایین صفحه با تایپ‌رایتر RTL
## تپ: اگر در حال تایپ است، جمله کامل می‌شود؛ اگر کامل است، سیگنال next می‌آید.
## صدا ندارد عمداً (درس «صدای زشت» v0.9) — طنز از متن و ریتم می‌آید.

signal next_requested

const COL_BG := Color(0.085, 0.095, 0.115, 0.96)
const COL_BORDER := Color(0.85, 0.68, 0.28, 0.55)
const COL_CREAM := Color(0.95, 0.93, 0.88)
const COL_GOLD := Color(0.96, 0.76, 0.25)
const COL_OFF := Color(0.86, 0.62, 0.55) # گوینده‌ی نامرئی (پشت دیوار)

var font_body: FontFile
var font_name: FontFile
var _name_label: Label
var _body_label: Label
var _panel: PanelContainer
var _full_text := ""
var _chars_per_sec := 34.0
var _active := false

func _ready() -> void:
        set_anchors_preset(Control.PRESET_FULL_RECT)
        mouse_filter = Control.MOUSE_FILTER_IGNORE
        font_body = _font("res://assets/fonts/Vazirmatn-Regular.ttf")
        font_name = _font("res://assets/fonts/Lalezar-Regular.ttf")
        _panel = PanelContainer.new()
        var sb := StyleBoxFlat.new()
        sb.bg_color = COL_BG
        sb.border_color = COL_BORDER
        sb.set_border_width_all(2)
        sb.set_corner_radius_all(18)
        sb.shadow_color = Color(0, 0, 0, 0.5)
        sb.shadow_size = 12
        sb.content_margin_left = 22
        sb.content_margin_right = 22
        sb.content_margin_top = 12
        sb.content_margin_bottom = 14
        _panel.add_theme_stylebox_override("panel", sb)
        _panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var vb := VBoxContainer.new()
        vb.add_theme_constant_override("separation", 4)
        vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _panel.add_child(vb)
        _name_label = Label.new()
        _style_label(_name_label, 26, true, true)
        _name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        vb.add_child(_name_label)
        _body_label = Label.new()
        _style_label(_body_label, 24, false, false)
        _body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        _body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        vb.add_child(_body_label)
        add_child(_panel)
        # نوار پایین — عرض پنل با انکرها (ضد چیدمان دستی)
        _panel.anchor_left = 0.5
        _panel.anchor_right = 0.5
        _panel.anchor_top = 1.0
        _panel.anchor_bottom = 1.0
        _panel.offset_left = -420.0
        _panel.offset_right = 420.0
        _panel.offset_top = -196.0
        _panel.offset_bottom = -24.0
        _panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
        _panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
        visible = false

func _font(path: String) -> FontFile:
        if ResourceLoader.exists(path):
                var r := load(path)
                if r is FontFile:
                        return r
        return null

func _style_label(l: Label, size: int, disp: bool, outline: bool) -> void:
        var f := font_name if disp else font_body
        if f != null:
                l.add_theme_font_override("font", f)
        l.add_theme_font_size_override("font_size", size)
        l.add_theme_color_override("font_color", COL_GOLD if disp else COL_CREAM)
        if outline:
                l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
                l.add_theme_constant_override("outline_size", 5)

## گوینده‌ی نامرئی (زن اکبر!) → از پشت دیوار؛ رنگ و برچسب متفاوت
func show_line(who: String, text: String, offscreen := false) -> void:
        _name_label.text = who + ("  (از پشت دیوار)" if offscreen else "")
        _name_label.add_theme_color_override("font_color", COL_OFF if offscreen else COL_GOLD)
        _full_text = text
        _body_label.text = text
        _body_label.visible_characters = 0
        visible = true
        _active = true

func hide_line() -> void:
        visible = false
        _active = false

func is_typing() -> bool:
        return _active and _body_label.visible_characters < _full_text.length()

func is_active() -> bool:
        return _active

func _process(delta: float) -> void:
        if _active and is_typing():
                _body_label.visible_characters += int(maxf(1.0, _chars_per_sec * delta))

## تپ روی صحنه از side متصل می‌شود؛ خودِ باکس mouse_filter=IGNORE دارد
func tap() -> void:
        if not _active:
                return
        if is_typing():
                _body_label.visible_characters = -1 # کامل نشون بده
        else:
                next_requested.emit()
