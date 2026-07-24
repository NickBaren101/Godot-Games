extends PanelContainer

signal chosen(id: String)

var _id: String
var _hovered := false

func setup(id: String, text: String, cost_text: String) -> void:
	_id = id
	var text_label: Label = $HBox/TextLabel
	var cost_label: Label = $HBox/CostLabel
	text_label.text = text
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_color_override("font_color", Config.COL_TEXT)
	cost_label.text = cost_text
	cost_label.add_theme_color_override("font_color", Config.COL_TEXT_MUTED)
	_apply_style()

func _apply_style() -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(10)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	style.bg_color = Config.COL_BUBBLE_IN if not _hovered else Config.COL_BUBBLE_OUT
	add_theme_stylebox_override("panel", style)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		chosen.emit(_id)

func _on_mouse_entered() -> void:
	_hovered = true
	_apply_style()

func _on_mouse_exited() -> void:
	_hovered = false
	_apply_style()

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
