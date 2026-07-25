extends ScrollContainer

const BubbleScene := preload("res://scenes/bubble.tscn")
const TypingScene := preload("res://scenes/typing_dots.tscn")

var _messages: VBoxContainer
var _typing: Control = null

func _ready() -> void:
	_messages = $Messages

## Incoming message — grey, left, revealed character by character.
func add_incoming(text: String) -> void:
	var b := BubbleScene.instantiate()
	_messages.add_child(b)
	b.setup(text, true)
	b.reveal(false)
	_auto_scroll()

## Outgoing message — blue, right, streamed character by character (await returns
## when the reveal finishes). failed=true adds the "not delivered" marker beneath it.
func add_outgoing(text: String, failed: bool = false) -> void:
	var b := BubbleScene.instantiate()
	_messages.add_child(b)
	b.setup(text, false, failed)
	_auto_scroll()
	await b.reveal(false)
	if failed:
		var marker := Label.new()
		marker.text = "not delivered"
		marker.add_theme_color_override("font_color", Config.COL_FAILED)
		marker.add_theme_font_size_override("font_size", 11)
		marker.size_flags_horizontal = Control.SIZE_SHRINK_END
		marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_messages.add_child(marker)
	_auto_scroll()

func show_typing() -> void:
	if _typing != null:
		return
	_typing = TypingScene.instantiate()
	_messages.add_child(_typing)
	_auto_scroll()

func hide_typing() -> void:
	if _typing != null:
		_typing.queue_free()
		_typing = null

func _auto_scroll() -> void:
	await get_tree().process_frame
	scroll_vertical = int(get_v_scroll_bar().max_value)
