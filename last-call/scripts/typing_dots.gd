extends PanelContainer

func _ready() -> void:
	size_flags_horizontal = SIZE_SHRINK_BEGIN

	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(14)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.bg_color = Config.COL_BUBBLE_IN
	add_theme_stylebox_override("panel", style)

	var i := 0
	for dot in $HBox.get_children():
		var d := dot as ColorRect
		d.color = Config.COL_TEXT_MUTED
		var tw := create_tween().set_loops()
		tw.tween_interval(0.15 * i)
		tw.tween_property(d, "modulate:a", 1.0, 0.4)
		tw.tween_property(d, "modulate:a", 0.3, 0.4)
		tw.tween_interval(0.15 * (2 - i))
		i += 1
