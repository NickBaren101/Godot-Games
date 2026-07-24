extends Node

# --- Content -------------------------------------------------------------
## Path to the active dialogue file. Swapping content = changing this line only.
const DIALOGUE_PATH := "res://data/dialogue.json"

# --- Battery / economy (see GDD §3) --------------------------------------
const START_BATTERY := 4.00        # starting charge, float
const COST_PER_CHAR := 0.003795     # send cost = max(0.02, len(text) * COST_PER_CHAR)
const MIN_SEND_COST := 0.02
const IDLE_DRAIN := 0.003          # percent per second, idle or waiting
const RECEIVE_DRAIN := 0.003       # percent per second during the typing indicator
const LOW_POWER_DRAIN := 0.0015    # replaces IDLE_DRAIN once below 1.00
const TYPING_MIN := 1.2            # seconds, minimum typing indicator duration
const TYPING_MAX := 4.0            # seconds, maximum
const TYPING_PER_CHAR := 0.05      # seconds per character of the incoming reply

# --- Low power mode ------------------------------------------------------
const LOW_POWER_AT := 1.00         # float at/below which low power engages
const LOW_POWER_TYPING_MIN := 2.0  # TYPING_MIN rises to this in low power
const LOW_POWER_DIM := 0.8         # phone surface brightness in low power

# --- Silence / passive waiting -------------------------------------------
const FALLBACK_IDLE_TIME := 20.0   # idle seconds before a generic waits[] line fires when no authored chain is active

# --- Options list --------------------------------------------------------
const MAX_VISIBLE_OPTIONS := 5     # cap the visible list; a 6th "more…" row cycles the window

# --- Derived cost --------------------------------------------------------
static func send_cost(text: String) -> float:
	return max(MIN_SEND_COST, text.length() * COST_PER_CHAR)

## Two-decimal cost string for the UI, e.g. "0.04%".
static func cost_label(text: String) -> String:
	return "%0.2f%%" % send_cost(text)

# --- Palette (GDD §10) ---------------------------------------------------
const COL_PAGE_BG := Color("14161a")       # page background
const COL_PHONE := Color("1c1f25")         # phone surface
const COL_BUBBLE_IN := Color("2a2e36")     # incoming bubble
const COL_BUBBLE_OUT := Color("3d4a5c")    # outgoing bubble
const COL_TEXT := Color("e8e6e1")          # text primary
const COL_TEXT_MUTED := Color("8b8f96")    # text muted
const COL_BATTERY := Color("c07a5e")       # battery
const COL_FAILED := Color("a85c50")        # failed / undelivered

# --- Layout --------------------------------------------------------------
const PHONE_W := 420
const PHONE_H := 760
const BUBBLE_MAX_W := 0.72         # bubble max width as fraction of phone content width
