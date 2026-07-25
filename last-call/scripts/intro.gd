extends Control
## Intro on black, in two cuts: (1) the title alone, auto-fading after ~3s; (2) the backstory,
## all on one screen, dismissed by any key or click — then it fades to reveal the phone. Content
## comes from the dialogue file's "intro" block (omit it to skip straight into the chat).

var _dismissed := false
var _accept := false

func play(title: String, cards: Array) -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	if title != "":
		await _title_cut(title)
	if not cards.is_empty():
		await _backstory_cut(cards)

	var out := create_tween()
	out.tween_property(self, "modulate:a", 0.0, 0.6)
	await out.finished
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Cut 1 — the title alone, centered, auto-fading after a ~3s hold. No input needed.
func _title_cut(text: String) -> void:
	var lbl := _line(text, 64, Config.COL_TEXT)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.modulate.a = 0.0
	add_child(lbl)

	var t := create_tween()
	t.tween_property(lbl, "modulate:a", 1.0, 0.8)
	t.tween_interval(3.0)
	t.tween_property(lbl, "modulate:a", 0.0, 0.8)
	await t.finished
	lbl.queue_free()


## Cut 2 — the backstory, all on one screen, waiting for any key or click.
func _backstory_cut(cards: Array) -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.modulate.a = 0.0
	add_child(center)

	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 640
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)

	for c in cards:
		box.add_child(_line(String(c), 0, Config.COL_TEXT))
	box.add_child(_spacer(28))
	box.add_child(_line("press any key to begin", 0, Config.COL_TEXT_MUTED))

	var tw := create_tween()
	tw.tween_property(center, "modulate:a", 1.0, 1.0)
	await tw.finished

	_accept = true
	while not _dismissed:
		await get_tree().process_frame
	_accept = false
	set_process_input(false)


func _line(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 640
	l.add_theme_color_override("font_color", color)
	if font_size > 0:
		l.add_theme_font_size_override("font_size", font_size)
	return l


func _spacer(h: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size.y = h
	return s


func _input(event: InputEvent) -> void:
	if not _accept:
		return
	if (event is InputEventKey and event.pressed and not event.echo) \
			or (event is InputEventMouseButton and event.pressed):
		_dismissed = true
		get_viewport().set_input_as_handled()
