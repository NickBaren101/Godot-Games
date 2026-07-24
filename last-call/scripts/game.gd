extends Control

enum State { IDLE, SENDING, THEY_TYPE, FINALE, ENDING }

const OptionScene := preload("res://scenes/option_row.tscn")
const MORE_ID := "__more__"

var battery: float = Config.START_BATTERY
var state: State = State.SENDING          # blocked until the opening finishes
var current_act: int = 0
var displayed_digit: int = int(ceil(Config.START_BATTERY))
var low_power := false
var finale_started := false
var _halted := false

var convo: Conversation

# Silence / passive waiting
var _idle_time := 0.0
var _silence_chain: Array = []       # remaining authored follow-ups for the current burst
var _silence_active := false         # true while a silence line is being delivered
var _silence_exhausted := false      # true once the generic waits[] pool is spent

# Option window (for the "more…" row)
var _opt_offset := 0

@onready var _contact: Label = $Center/Phone/PhoneMargin/VBox/Header/ContactName
@onready var _battery_label: Label = $Center/Phone/PhoneMargin/VBox/Header/BatteryLabel
@onready var _battery_bar: ColorRect = $Center/Phone/PhoneMargin/VBox/BatteryBar
@onready var _battery_fill: ColorRect = $Center/Phone/PhoneMargin/VBox/BatteryBar/Fill
@onready var _phone: PanelContainer = $Center/Phone
@onready var _transcript = $Center/Phone/PhoneMargin/VBox/Transcript
@onready var _options: VBoxContainer = $Center/Phone/PhoneMargin/VBox/Options
@onready var _ending = $Ending


func _ready() -> void:
	_style_phone()

	convo = Conversation.new()
	var err := convo.load_file(Config.DIALOGUE_PATH)
	if err != "":
		_fatal(err)
		return

	_contact.text = String(convo.data.get("contact_name", "contact"))
	_update_battery_display()

	current_act = 1
	convo.enter_act(1)
	_play_opening()


func _style_phone() -> void:
	var s := StyleBoxFlat.new()
	s.set_corner_radius_all(24)
	s.bg_color = Config.COL_PHONE
	s.content_margin_left = 0
	s.content_margin_right = 0
	s.content_margin_top = 0
	s.content_margin_bottom = 0
	_phone.add_theme_stylebox_override("panel", s)
	_contact.add_theme_color_override("font_color", Config.COL_TEXT_MUTED)
	_battery_label.add_theme_color_override("font_color", Config.COL_BATTERY)
	_battery_fill.position = Vector2.ZERO


func _fatal(msg: String) -> void:
	_halted = true
	_transcript.add_incoming("[engine] " + msg)


# --- Main loop ------------------------------------------------------------

func _process(delta: float) -> void:
	if _halted or state == State.ENDING:
		return

	var rate: float = Config.RECEIVE_DRAIN if state == State.THEY_TYPE else _idle_rate()
	battery = maxf(battery - rate * delta, 0.0)
	_update_battery_display()

	if state == State.IDLE and not _silence_active:
		_idle_time += delta
		_maybe_nudge()

	_check_thresholds()


func _idle_rate() -> float:
	return Config.LOW_POWER_DRAIN if low_power else Config.IDLE_DRAIN


func _update_battery_display() -> void:
	var digit: int = clampi(int(ceil(battery)), 0, int(Config.START_BATTERY))
	_battery_label.text = "%d%%" % digit
	var track_w: float = _battery_bar.size.x
	_battery_fill.size = Vector2(track_w * (battery / 100.0), _battery_bar.size.y)


func _check_thresholds() -> void:
	var digit: int = clampi(int(ceil(battery)), 0, int(Config.START_BATTERY))
	if digit < displayed_digit:
		displayed_digit = digit
		_flash_battery()
		if digit >= 2:
			Audio.digit_drop()
		# the drop to 1 coincides with the finale; its tone is played there.

	if not finale_started and battery <= Config.LOW_POWER_AT:
		_run_finale()
		return

	if not finale_started:
		if current_act < 2 and battery <= 3.0:
			_advance_act(2)
		if current_act < 3 and battery <= 2.0:
			_advance_act(3)


func _advance_act(act: int) -> void:
	current_act = act
	convo.enter_act(act)
	var trans: Array = convo.data.get("act_transitions", {}).get(str(act), [])
	for m in trans:
		_transcript.add_incoming(String(m.get("text", "")))
	_reset_silence([])                # transitions use the generic fallback; new act may add waits
	if state == State.IDLE:
		_refresh_options()


# --- Opening --------------------------------------------------------------

func _play_opening() -> void:
	for msg in convo.data.get("opening", []):
		var delay: float = float(msg.get("delay", 0.6))
		await get_tree().create_timer(delay).timeout
		if _halted:
			return
		Audio.receive()
		_transcript.add_incoming(String(msg.get("text", "")))
	if finale_started:
		return
	_reset_silence(convo.data.get("opening_silence", []))
	state = State.IDLE
	_refresh_options()


# --- Options --------------------------------------------------------------

func _refresh_options() -> void:
	_clear_options()
	var opts: Array = convo.visible_options()
	var total: int = opts.size()
	if total == 0:
		return
	if _opt_offset >= total:
		_opt_offset = 0
	var show_more: bool = total > Config.MAX_VISIBLE_OPTIONS
	var count: int = Config.MAX_VISIBLE_OPTIONS if show_more else total
	for i in range(count):
		var opt: Dictionary = opts[(_opt_offset + i) % total]
		_add_row(String(opt.get("id", "")), String(opt.get("text", "")), Config.cost_label(String(opt.get("text", ""))), _on_option_chosen)
	if show_more:
		_add_row(MORE_ID, "more…", "", _on_option_chosen)


func _add_row(id: String, text: String, cost_text: String, handler: Callable) -> void:
	var row := OptionScene.instantiate()
	_options.add_child(row)
	row.setup(id, text, cost_text)
	row.chosen.connect(handler)


func _clear_options() -> void:
	for c in _options.get_children():
		c.queue_free()


func _cycle_options() -> void:
	var total: int = convo.visible_options().size()
	if total > 0:
		_opt_offset = (_opt_offset + Config.MAX_VISIBLE_OPTIONS) % total
	_refresh_options()


func _on_option_chosen(id: String) -> void:
	if state != State.IDLE:
		return                       # clicks during THEY_TYPE are ignored, never queued
	if id == MORE_ID:
		_cycle_options()
		return
	state = State.SENDING
	_reset_silence([])
	var opt: Dictionary = convo.send(id)
	var text: String = String(opt.get("text", ""))
	var cost: float = Config.send_cost(text)
	battery = maxf(battery - cost, 0.0)
	Audio.send()
	_clear_options()
	_transcript.add_outgoing(text)
	_update_battery_display()

	await _run_reply(opt.get("reply", []))
	if finale_started:
		return
	_reset_silence(opt.get("silence", []))
	state = State.IDLE
	_refresh_options()


# --- Incoming replies -----------------------------------------------------

func _run_reply(reply: Array) -> void:
	state = State.THEY_TYPE
	for line in reply:
		if finale_started:
			_transcript.hide_typing()
			return
		var s := String(line)
		_transcript.show_typing()
		await get_tree().create_timer(_typing_duration(s)).timeout
		if finale_started:
			_transcript.hide_typing()
			return
		_transcript.hide_typing()
		Audio.receive()
		_transcript.add_incoming(s)
		await get_tree().create_timer(0.25).timeout


func _typing_duration(text: String) -> float:
	var tmin: float = Config.LOW_POWER_TYPING_MIN if low_power else Config.TYPING_MIN
	return clampf(text.length() * Config.TYPING_PER_CHAR, tmin, Config.TYPING_MAX)


# --- Silence / passive waiting --------------------------------------------

## Begin a fresh player turn: adopt this burst's authored follow-up chain (a copy, so
## popping never mutates the loaded dialogue), zero the idle clock, re-arm the fallback.
func _reset_silence(chain: Array) -> void:
	_silence_chain = chain.duplicate()
	_idle_time = 0.0
	_silence_exhausted = false


func _maybe_nudge() -> void:
	if _silence_active or state != State.IDLE or finale_started:
		return
	if not _silence_chain.is_empty():
		var entry: Dictionary = _silence_chain[0]
		if _idle_time >= float(entry.get("idle_time", Config.FALLBACK_IDLE_TIME)):
			_silence_chain.pop_front()
			# A `final` last line ends the exchange: the contact finishes its thought and
			# goes quiet, with no generic waits[] "you there?" nudge tacked on afterward.
			if _silence_chain.is_empty() and bool(entry.get("final", false)):
				_silence_exhausted = true
			_fire_incoming(String(entry.get("text", "")))
	elif not _silence_exhausted and _idle_time >= Config.FALLBACK_IDLE_TIME:
		var line: String = convo.pull_wait(current_act)
		if line == "":
			_silence_exhausted = true
		else:
			_fire_incoming(line)


func _fire_incoming(text: String) -> void:
	_silence_active = true
	state = State.THEY_TYPE
	_clear_options()
	_transcript.show_typing()
	await get_tree().create_timer(_typing_duration(text)).timeout
	_transcript.hide_typing()
	if not finale_started:
		Audio.receive()
		_transcript.add_incoming(text)
		state = State.IDLE
		_refresh_options()
	_idle_time = 0.0
	_silence_active = false


# --- Finale + closing -----------------------------------------------------

func _run_finale() -> void:
	if finale_started:
		return
	finale_started = true
	low_power = true
	state = State.FINALE
	_silence_chain = []
	_phone.modulate = Color(Config.LOW_POWER_DIM, Config.LOW_POWER_DIM, Config.LOW_POWER_DIM, 1.0)
	_flash_battery()
	Audio.low_power()
	_clear_options()

	var fin: Dictionary = convo.data.get("finale", {})
	for m in fin.get("messages", []):
		await get_tree().create_timer(0.6).timeout
		Audio.receive()
		_transcript.add_incoming(String(m))

	await get_tree().create_timer(0.4).timeout
	_render_finale_options(fin.get("options", []))


func _render_finale_options(options: Array) -> void:
	_clear_options()
	for opt in options:
		var text: String = String(opt.get("text", ""))
		_add_row(String(opt.get("id", "")), text, Config.cost_label(text), _on_finale_chosen)


func _on_finale_chosen(id: String) -> void:
	if state != State.FINALE:
		return
	state = State.SENDING
	_clear_options()
	var fin: Dictionary = convo.data.get("finale", {})
	var text := ""
	for opt in fin.get("options", []):
		if String(opt.get("id", "")) == id:
			text = String(opt.get("text", ""))
			break
	var cost: float = Config.send_cost(text)
	var after: float = battery - cost
	var delivered: bool = after > 0.0
	battery = maxf(after, 0.0)
	_update_battery_display()
	Audio.send()
	_transcript.add_outgoing(text, not delivered)

	if delivered:
		await _run_finale_reply(fin.get("delivered_reply", []))
		Audio.phone_dies()
		_start_closing(true, fin)
	else:
		Audio.send_fail()
		await get_tree().create_timer(1.0).timeout
		Audio.phone_dies()
		_start_closing(false, fin)


func _run_finale_reply(reply: Array) -> void:
	state = State.THEY_TYPE
	for i in range(reply.size()):
		var s := String(reply[i])
		if i == reply.size() - 1:
			s = s.substr(0, int(s.length() * 0.7))   # cut off mid-word as the phone dies
		_transcript.show_typing()
		await get_tree().create_timer(_typing_duration(s)).timeout
		_transcript.hide_typing()
		Audio.receive()
		_transcript.add_incoming(s)
		await get_tree().create_timer(0.25).timeout


func _start_closing(delivered: bool, fin: Dictionary) -> void:
	state = State.ENDING
	_ending.play(delivered, convo.unsent_texts(), {
		"closing_delivered": String(fin.get("closing_delivered", "")),
		"closing_failed": String(fin.get("closing_failed", "")),
		"closing_final": String(fin.get("closing_final", "")),
		"unsaid_header": String(convo.data.get("unsaid_header", "")),
	})


# --- Battery flash --------------------------------------------------------

func _flash_battery() -> void:
	_battery_label.pivot_offset = _battery_label.size * 0.5
	_battery_label.scale = Vector2(1.15, 1.15)
	var tw := create_tween()
	tw.tween_property(_battery_label, "scale", Vector2.ONE, 0.25)
