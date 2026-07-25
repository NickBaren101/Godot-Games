extends PanelContainer

const REVEAL_PER_CHAR := 0.02

var _label: Label

func _ready() -> void:
	_label = $Label

## incoming=true → left, grey.  incoming=false → right, blue (outgoing).
## failed=true → outgoing colour with a warning border (the "not delivered" bubble).
func setup(text: String, incoming: bool, failed: bool = false) -> void:
	if _label == null:
		_label = $Label
	_label.text = text
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_color_override("font_color", Config.COL_TEXT)

	# Cap bubble width so neither speaker spans the whole phone.
	var content_w := float(Config.PHONE_W) - 32.0
	_label.custom_minimum_size.x = content_w * Config.BUBBLE_MAX_W

	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(14)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	if failed:
		style.bg_color = Config.COL_BUBBLE_OUT
		style.set_border_width_all(2)
		style.border_color = Config.COL_FAILED
	elif incoming:
		style.bg_color = Config.COL_BUBBLE_IN
	else:
		style.bg_color = Config.COL_BUBBLE_OUT
	add_theme_stylebox_override("panel", style)

	size_flags_horizontal = SIZE_SHRINK_BEGIN if incoming else SIZE_SHRINK_END

## Character-by-character reveal for incoming messages. Outgoing call reveal(0).
func reveal(instant: bool = false) -> void:
	if _label == null:
		_label = $Label
	if instant:
		_label.visible_ratio = 1.0
		return
	_label.visible_ratio = 0.0
	var dur: float = maxf(0.05, _label.text.length() * REVEAL_PER_CHAR)
	var tw := create_tween()
	tw.tween_property(_label, "visible_ratio", 1.0, dur)
	await tw.finished
