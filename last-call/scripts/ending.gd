extends Control

func play(delivered: bool, unsent: Array, texts: Dictionary) -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	await _card(String(texts["closing_delivered"] if delivered else texts["closing_failed"]))
	await _unsaid(String(texts["unsaid_header"]), unsent)
	await _card(String(texts["closing_final"]))
	_show_end(String(texts.get("closing_thanks", "")))


func _card(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_color_override("font_color", Config.COL_TEXT)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.offset_left = 48
	lbl.offset_right = -48
	lbl.modulate.a = 0.0
	add_child(lbl)

	var t := create_tween()
	t.tween_property(lbl, "modulate:a", 1.0, 0.6)
	t.tween_interval(2.5)
	t.tween_property(lbl, "modulate:a", 0.0, 0.6)
	await t.finished
	lbl.queue_free()


func _unsaid(header: String, unsent: Array) -> void:
	var vp := get_viewport_rect().size
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size.x = vp.x - 96
	col.position = Vector2(48, vp.y)
	add_child(col)

	var head := Label.new()
	head.text = header
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.custom_minimum_size.x = vp.x - 96
	head.add_theme_color_override("font_color", Config.COL_TEXT)
	col.add_child(head)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 24
	col.add_child(spacer)

	for line in unsent:
		var l := Label.new()
		l.text = String(line)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = vp.x - 96
		l.add_theme_color_override("font_color", Config.COL_TEXT_MUTED)
		col.add_child(l)

	await get_tree().process_frame
	var content_h: float = col.size.y
	var duration: float = maxf(6.0, unsent.size() * 1.4)
	var t := create_tween()
	t.tween_property(col, "position:y", -content_h, duration)
	await t.finished
	col.queue_free()


func _show_end(thanks: String) -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.modulate.a = 0.0
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	center.add_child(box)

	if thanks != "":
		var lbl := Label.new()
		lbl.text = thanks
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", Config.COL_TEXT)
		box.add_child(lbl)

	var btn := Button.new()
	btn.text = "replay"
	btn.add_theme_color_override("font_color", Config.COL_TEXT)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(btn)
	btn.pressed.connect(func(): get_tree().reload_current_scene())

	var t := create_tween()
	t.tween_interval(0.6)
	t.tween_property(center, "modulate:a", 1.0, 0.6)
