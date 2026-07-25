class_name Conversation
extends RefCounted

var data: Dictionary = {}

var _all_options: Array = []        # option dicts, in file order
var _by_id: Dictionary = {}         # id -> option dict
var _activated: Dictionary = {}     # id -> true (via start, or unlocked)
var _removed: Dictionary = {}       # id -> true
var _sent: Dictionary = {}          # id -> true
var _entered: Dictionary = {}       # id -> true (ever appeared in the pool)
var _used_waits: Array = []         # indices of waits[] already delivered

var current_act: int = 0

## Returns "" on success, or a human-readable error string.
func load_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "dialogue file not found: %s" % path
	var raw := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return "dialogue file is not a valid JSON object: %s" % path
	data = parsed
	_all_options = data.get("options", [])
	for opt in _all_options:
		_by_id[String(opt.get("id", ""))] = opt
	return ""

# --- Pool -----------------------------------------------------------------

## Advance to an act: activate this act's start options, and retire any option from an
## earlier act (its window has closed). Future-act options shown early via an unlock are
## kept. Idempotent per act.
func enter_act(act: int) -> void:
	current_act = maxi(current_act, act)
	for opt in _all_options:
		var id := String(opt.get("id", ""))
		if _act_of(opt) < current_act:
			# a previous-act option does not carry forward (still counts as "unsent"
			# in the ending if it was ever shown — _entered is untouched here).
			if not _sent.has(id):
				_removed[id] = true
		elif bool(opt.get("start", false)) and _act_of(opt) <= current_act:
			_activated[id] = true

## Currently sendable options, cheapest first (GDD §4). Also marks anything shown
## as having "entered the pool" for the finale's unsent list.
func visible_options() -> Array:
	var res: Array = []
	for opt in _all_options:
		var id := String(opt.get("id", ""))
		if not _activated.has(id):
			continue
		# Start options only enter _activated once their act is reached, so they gate
		# themselves. An unlocked option appears immediately — unless it is explicitly
		# deferred, in which case it waits for its act (a beat meant to land later).
		if bool(opt.get("defer", false)) and _act_of(opt) > current_act:
			continue
		if _removed.has(id):
			continue
		if _sent.has(id) and not bool(opt.get("persistent", false)):
			continue
		_entered[id] = true
		res.append(opt)
	res.sort_custom(_cheaper_first)
	return res

func _cheaper_first(a: Dictionary, b: Dictionary) -> bool:
	return cost_of(a) < cost_of(b)

## Mark an option sent and apply its unlocks / removes. Returns the option dict.
func send(id: String) -> Dictionary:
	var opt: Dictionary = _by_id.get(id, {})
	_sent[id] = true
	for uid in opt.get("unlocks", []):
		_activated[String(uid)] = true
	for rid in opt.get("removes", []):
		_removed[String(rid)] = true
	return opt

func cost_of(opt: Dictionary) -> float:
	return Config.send_cost(String(opt.get("text", "")))

func _act_of(opt: Dictionary) -> int:
	return int(opt.get("act", 1))

# --- Waits ----------------------------------------------------------------

## One unused waits[] line matching the act, or "" if none remain. Never repeats.
func pull_wait(act: int) -> String:
	var waits: Array = data.get("waits", [])
	for i in range(waits.size()):
		if _used_waits.has(i):
			continue
		var w: Dictionary = waits[i]
		if int(w.get("act", 0)) == act:
			_used_waits.append(i)
			return String(w.get("text", ""))
	return ""

# --- Finale ---------------------------------------------------------------

## Every option that entered the pool and was never sent, in file order.
func unsent_texts() -> Array:
	var res: Array = []
	for opt in _all_options:
		var id := String(opt.get("id", ""))
		if _entered.has(id) and not _sent.has(id):
			res.append(String(opt.get("text", "")))
	return res
