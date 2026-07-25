# Last Call — build spec

**For:** Claude Code, building in Godot 4.5 (Compatibility renderer)
**Deadline:** ~46 hours, solo. GMTK Game Jam 2026, theme "Countdown".
**Target:** browser-playable (HTML5), 8–10 minute experience, replayable.

> **You are building the engine, not the story.** All dialogue is authored separately by the
> developer and dropped in as `res://data/dialogue.json` later. Your job is a system that runs
> any conforming content file, plus placeholder content to develop against, plus a validator.
> **Do not write real dialogue. Do not write example lines with emotional content.** See §5.

This document is the complete specification. Where something is underspecified, pick the
simplest option that satisfies §13 and note the choice. §14 lists things that must not be built.

---

## 1. What this is

A text-message conversation with one contact. **The phone is at 4%.** Every message the player
sends costs battery proportional to its length. Waiting costs battery. Receiving replies costs
battery. The player cannot say everything before the phone dies.

The player never types. They pick from a list of things they could send, each showing its cost.
The list changes as the conversation moves.

**Design thesis:** the cost of a message is its length, so honesty is literally expensive and
deflection is cheap. The player will instinctively economise, and economising is the mistake
the game is about. Build every system to serve that.

---

## 2. The central mechanic: 4% for ten minutes

The most important thing in the document and the easiest to get wrong.

Battery is a float. **The display is an integer.** `battery = 4.00` shows as `4%`. It stays on
`4%` for around ninety seconds of play, then ticks to `3%`.

The number changes exactly four times in a full playthrough. Each change is an event. Between
changes the player sits with a terrifying number that refuses to move, which is what a dying
phone actually feels like — the dread is slow, not fast.

Do not smooth this. No decimals on the display, no seconds-remaining readout, no progress bar
that fills. The unmoving digit *is* the tension.

**The act structure is the digit.** Every time the displayed number drops, the content pool
opens up and the conversation changes register.

| Display | Float range | Act |
|---|---|---|
| `4%` | 4.00 → 3.00 | 1 |
| `3%` | 3.00 → 2.00 | 2 |
| `2%` | 2.00 → 1.00 | 3 |
| `1%` | 1.00 → 0.00 | Finale (§8) |

---

## 3. Numbers

All in a single `Config` autoload as constants, tunable in one place.

| Constant | Value | Meaning |
|---|---|---|
| `START_BATTERY` | `4.00` | Starting charge, float |
| `COST_PER_CHAR` | `0.005` | Send cost = `max(0.02, len(text) * COST_PER_CHAR)` |
| `IDLE_DRAIN` | `0.003` | Percent per second, idle or waiting |
| `RECEIVE_DRAIN` | `0.003` | Percent per second during the typing indicator |
| `LOW_POWER_DRAIN` | `0.0015` | Replaces `IDLE_DRAIN` once below 1.00 |
| `TYPING_MIN` | `1.2` | Seconds, minimum typing indicator duration |
| `TYPING_MAX` | `4.0` | Seconds, maximum |
| `TYPING_PER_CHAR` | `0.05` | Seconds per character of the incoming reply |

Typing duration: `clamp(len(reply) * TYPING_PER_CHAR, TYPING_MIN, TYPING_MAX)`.

`COST_PER_CHAR` is a placeholder value. It gets tuned against the real dialogue later using the
validator in §6 — which is why nothing may hardcode a cost.

**Pacing target.** 8–10 minutes wall-clock. Drain accounts for roughly 1.4% of the 4.00 budget
across that span; sends account for the rest. If it runs short, lower `IDLE_DRAIN` — never
raise `START_BATTERY`.

**Low power mode.** Below `1.00`, drain halves to `LOW_POWER_DRAIN`, the phone surface dims to
80% brightness, and `TYPING_MIN` rises to `2.0`. Realistic, and it buys the finale room.

**No random failures.** Ordinary sends always deliver — the game has no dice rolls. The only
undelivered message is at the finale, and it is *deterministic*: if the final message you choose
costs more battery than remains, it can't send (the phone dies mid-send), appearing with a "not
delivered" marker. That is a consequence of the choice, not chance. Do not add a retry.

---

## 4. Core loop

1. Player sees the transcript, the battery digit, and 3–5 options with costs.
2. Player clicks an option (send) or holds `Space` (wait).
3. Battery decreases.
4. A reply arrives after a typing delay, during which battery continues to drain.
5. Option list updates: sent option removed, its `unlocks` added, its `removes` deleted.
6. Repeat until the float crosses `1.00`, triggering the finale.

**Option display order: cheapest first.** Long expensive lines sit at the bottom where the
player has to look past the cheap ones to reach them. This ordering is load-bearing.

**Cap the visible list at 5.** If the pool is larger, show the 5 cheapest plus a sixth row
reading `more…` that cycles the window. Do not scroll the option list.

**Cost display:** two decimals, e.g. `0.04%`. Against a `4%` battery that reads as alarmingly
expensive, which is correct.

---

## 5. Content pipeline

The developer writes `res://data/dialogue.json`. You define the schema, load it defensively,
and ship placeholder content so the engine can be built and tested before real content exists.

### Schema

```
contact_name    string
opening[]       { text, delay, outgoing? }   messages already on screen before the player's
                first turn. outgoing:true renders it as a player-sent message (opens the chat
                mid-conversation); default is incoming from the contact. Never cost battery.
opening_silence[] { idle_time, text }  follow-ups sent if the opening goes unanswered (see §8)
act_transitions { "2": [{text}], "3": [{text}] }   fired when the digit drops
options[]
  id          string, unique
  text        string, what the player sends. Cost is DERIVED, never stored in the file.
  act         int 1–3. For start options, the act they auto-enter. Unlock-only options
              ignore this (they appear the moment they're unlocked) unless defer is set.
  start       bool, in the pool from the beginning if act <= current act
  reply[]     array of strings — each becomes its own bubble with its own typing delay
  unlocks[]   option ids added to the pool when this is sent — they appear immediately
  removes[]   option ids deleted from the pool after this is sent
  persistent  optional bool — if true, the option is not consumed when sent
  defer       optional bool — unlock-only: keep hidden until its act (a later-surfacing beat)
  silence[]   optional { idle_time, text, final? } — ordered follow-ups the contact sends
              if the player stays silent after this option's reply; each fires after
              idle_time seconds of silence, in order. A reply cancels the rest of the
              chain (the contact is cut off). final:true on the last entry = go quiet
              afterward instead of falling back to waits[] (see §8)
waits[]         { act, text }          fallback lines pulled after a silence chain is spent; filter by act, never repeat
finale
  messages[]          strings, pushed when the finale triggers
  options[]           { id, text } — exactly 4
  delivered_reply[]   strings, shown only if the final message delivers
  closing_delivered   string
  closing_failed      string
  closing_final       string
unsaid_header   string, heading for the unsent-message list
```

### Placeholder content

Generate a `dialogue.json` that exercises every code path and is **unmistakably fake**. Use
text like `"[A1] short option"`, `"[A2] medium length placeholder option text here"`,
`"[REPLY] placeholder"`. Vary the lengths so the cost formula is visibly working.

It must include: at least 12 options spread across all 3 acts, at least one `start: true` per
act, at least one option with a non-empty `unlocks`, at least one with a non-empty `removes`,
one `persistent` option, at least 2 `waits` per act, and a complete `finale` block.

Do not write real dialogue. Do not write placeholder text with emotional content, character
names, or implied backstory — it will be deleted, and a half-real placeholder is worse than an
obviously fake one because it invites the developer to keep it.

### Rendering constraints the content depends on

- **Render all text verbatim.** The real dialogue deliberately mixes capitalisation styles
  between the two speakers. Never auto-capitalise, trim, title-case, or "fix" punctuation.
- Handle any text length gracefully — a 4-character option and a 90-character option must both
  render correctly in the option list without clipping or reflowing the layout.
- `reply` arrays may hold 1–3 strings. Each gets its own bubble and its own typing delay.

---

## 6. The validator

Build `tools/validate_dialogue.py` — a standalone Python 3 script, no dependencies, run as
`python3 tools/validate_dialogue.py data/dialogue.json`. This is how the developer will check
their writing later, so its output matters as much as the game's.

**Structural checks (fail loudly):**
- File parses; all required keys present
- All option ids unique
- Every id in any `unlocks` or `removes` exists
- No option unlocks or removes itself
- Every option is reachable — either `start: true`, or named in some option's `unlocks`.
  **Orphan detection is the highest-value check here**; hand-authored branching trees always
  strand a few options, and a stranded option never appears in the game or in the unsent list.
- `act` is 1–3; `waits` covers all 3 acts; `finale.options` has exactly 4

**Economy report (informational):**
- Total send cost at the current `COST_PER_CHAR`, i.e. `sum(max(0.02, len(text) * rate))`
- **Target band: 5.5 to 6.5** against the 4.00 budget. That is what makes a single playthrough
  surface 55–65% of the content.
- If outside the band, print the `COST_PER_CHAR` that would hit 6.0, to be pasted into
  `config.gd`. Never suggest changing `START_BATTERY` or the dialogue.
- Per-act option counts, cheapest and most expensive option, mean cost

Read `COST_PER_CHAR` out of `scripts/config.gd` rather than duplicating the constant.

---

## 7. Act transitions

Acts advance on **battery thresholds, not player progress.** This guarantees the pacing holds
regardless of what the player picks, which matters because not every branch can be playtested.

When the float crosses `3.00` or `2.00`: push that act's `act_transitions` messages, then add
all options with `act <= current_act` to the pool. **Options never expire** — act 1 options
remain available in act 3.

---

## 8. Waiting and the finale

**Waiting.** *(Revised 2026-07-24 — replaces the original `Space`-hold design.)* Waiting is now
passive: the player does nothing and the battery drains at the current rate. If the player stays
silent, the contact speaks again on its own. Each contact message can carry an authored `silence`
chain (options) or `opening_silence` (the opening) — ordered follow-ups that fire after their own
`idle_time` seconds of silence, escalating in order (e.g. the contact explaining itself after a
sensitive line). When a chain is spent (or a burst has none), the generic `waits[]` pool is the
fallback, one act-matching line per `FALLBACK_IDLE_TIME` seconds, until it too runs dry — after
which the contact goes quiet and the battery drains to the finale. There is no wait button.

**Finale.** When the float crosses `1.00`: lock the pool, clear the option list, push
`finale.messages`, then show only the 4 `finale.options`. The player picks one.

- Battery after the cost `> 0` → the message **delivers**. Show `delivered_reply`. The final
  string is cut off mid-word as the phone dies — truncate at ~70% of its length at runtime.
- Battery after the cost `<= 0` → the message **fails**. Undelivered marker, no reply.

**Neither outcome is a win.** No score, rank, grade, or "best ending" label anywhere.

**Closing sequence**, all on black, each card held 2.5s with a 0.6s fade:

1. `closing_delivered` or `closing_failed`
2. `unsaid_header`, then every option that entered the pool and was never sent, in grey,
   scrolling slowly upward. Hold until the list clears.
3. `closing_final`
4. Fade to black, single `replay` button.

Card 2 is the payoff of the entire game. Give it room. Do not speed it up, do not add a skip.

---

## 9. Scene and script structure

```
res://
  main.tscn                 Root, Control, full-rect
  scenes/
    bubble.tscn             PanelContainer > MarginContainer > Label
    typing_dots.tscn        HBoxContainer > 3x ColorRect
    option_row.tscn         Button > HBoxContainer > Label (text) + Label (cost)
  scripts/
    config.gd               Autoload. Constants from §3.
    game.gd                 State machine, battery, act transitions. On main.
    conversation.gd         Loads JSON, owns the option pool, resolves unlocks/removes.
    transcript.gd           Owns the ScrollContainer/VBoxContainer, spawns bubbles.
    audio.gd                Autoload. Procedural SFX (§11).
    ending.gd               The closing sequence.
  data/
    dialogue.json           Placeholder, to be replaced
  tools/
    validate_dialogue.py
```

`main.tscn`:

```
Main (Control)
├── Background (ColorRect)
└── Phone (MarginContainer, custom_minimum_size 420x760, centred)
    └── VBoxContainer
        ├── Header (HBoxContainer)
        │   ├── ContactName (Label)
        │   └── BatteryLabel (Label)          ← integer only
        ├── BatteryBar (ColorRect)
        ├── Transcript (ScrollContainer, size_flags_vertical = EXPAND_FILL)
        │   └── Messages (VBoxContainer)
        └── Options (VBoxContainer)
```

**States:** `IDLE`, `SENDING`, `THEY_TYPE`, `FINALE`, `ENDING`. Input accepted only in `IDLE`
and `FINALE`. Single most important correctness detail — a click during `THEY_TYPE` must be
**ignored, not queued**.

`conversation.gd` must be fully decoupled from the JSON's actual text: no branching on string
contents, no hardcoded ids anywhere in the engine. Swapping in a completely different content
file must require zero code changes.

---

## 10. Visuals

Portrait phone frame, centred on a flat dark background. Everything is a rectangle. No external
assets — jam rule and time constraint both.

| Role | Hex |
|---|---|
| Page background | `#14161a` |
| Phone surface | `#1c1f25` |
| Incoming bubble | `#2a2e36` |
| Outgoing bubble | `#3d4a5c` |
| Text primary | `#e8e6e1` |
| Text muted | `#8b8f96` |
| Battery | `#c07a5e` |
| Failed / undelivered | `#a85c50` |

The battery is the warning colour from the first frame. At 4% there is no "normal" state.

Bubbles: `PanelContainer` + `StyleBoxFlat`, `corner_radius_*` = 14, content margins 10/14.
`Label` with `autowrap_mode = AUTOWRAP_WORD_SMART`, `custom_minimum_size.x` capped at 70% of
phone width. Alignment via `size_flags_horizontal` — `SHRINK_BEGIN` incoming, `SHRINK_END`
outgoing.

**Battery bar** is a sliver from the start — 4% of the bar width, ~16px. It barely moves. That
is the point. Tween `size.x` over 0.3s on change.

**Text reveal.** Incoming messages appear character-by-character via `Tween` on the Label's
`visible_ratio`, 0 → 1 over `len * 0.02` seconds. Outgoing appear instantly.

**Auto-scroll.** After adding any bubble, wait a frame before the container knows its height:

```gdscript
await get_tree().process_frame
scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
```

**Typing dots:** three 5px `ColorRect` circles, looping `Tween` on `modulate:a` between 0.3 and
1.0, offset 0.15s each.

**Digit change:** flash the battery label once (scale 1.15 → 1.0 over 0.25s) plus the tone from
§11. No popup, no notification.

**Not a clone of any real messaging app.** Generic layout, this palette. Do not reproduce
iMessage blue, WhatsApp green, or any real app's chrome.

---

## 11. Audio

All procedural, no files. `AudioStreamGenerator` at `mix_rate = 22050`, square wave. One
helper: `Audio.blip(freq: float, duration: float, volume: float)`.

| Event | Sound |
|---|---|
| Player sends | 880 Hz, 0.05s, quiet |
| Reply arrives | 660 Hz, 0.06s |
| Send fails | 220 Hz, 0.18s |
| Battery digit drops | 330 Hz, 0.12s |
| Enter low power (1%) | 300 Hz then 250 Hz, 0.1s each |
| Phone dies | 425 Hz, 0.9s, then silence |

No music. Do not add music. A receive blip that doesn't arrive is the loudest thing in the game.

---

## 12. Build order

Ship a broken web build to itch at the end of step 1. Do not leave exporting until Sunday.

1. **Skeleton** — phone frame, float battery ticking, integer display, one hardcoded bubble.
   Export to HTML5, confirm it runs in a browser. *This checkpoint de-risks the whole jam.*
2. **Transcript** — bubble scene, spawn from an array, auto-scroll, both alignments.
3. **Schema + placeholder + validator** — §5 and §6. Getting the data contract right before
   building on it is what lets real content drop in without touching code.
4. **Options** — load JSON, cost formula, click to send, unlocks/removes resolving.
5. **Incoming side** — typing indicator, delays, `visible_ratio` reveal, drain while typing.
6. **Waiting** — `Space`, the `waits[]` pool, 4-second trigger.
7. **Acts** — threshold transitions, unprompted messages, low power mode at 1%.
8. **Finale + closing sequence** — §8. Budget 3 hours. The unsent list is the payoff.
9. **Audio** — §11. One hour, all of it.
10. **Stop.** Hand back for content.

If behind at step 8, cut 6 and 9 — the game works without waiting and without sound. Never
cut 8.

---

## 13. Acceptance criteria

- [ ] Runs in a browser from an itch.io HTML5 upload, no console errors.
- [ ] Battery starts at `4.00`, displays as `4%`. No decimals shown anywhere in the UI.
- [ ] The displayed digit changes exactly 3 times before the finale (4→3→2→1).
- [ ] A full playthrough on placeholder content reaches the closing sequence every time.
- [ ] Battery only ever decreases. Nothing restores it.
- [ ] Clicking during `THEY_TYPE` does nothing and queues nothing.
- [ ] Sending removes the option (unless `persistent`) and its `unlocks` appear.
- [ ] The unsent list contains every option that entered the pool and was never sent, and
      nothing else.
- [ ] All text renders verbatim — no auto-capitalisation, trimming, or punctuation changes.
- [ ] The final message delivers or fails based purely on remaining battery.
- [ ] Replacing `dialogue.json` wholesale requires **zero** code changes. Demonstrate this by
      running the game against a second, differently-shaped placeholder file.
- [ ] `validate_dialogue.py` catches: a broken `unlocks` reference, a duplicate id, and an
      orphaned option. Test it against a deliberately broken file.
- [ ] `find . -name "*.png" -o -name "*.ogg" -o -name "*.ttf"` returns nothing.

---

## 14. Explicit non-goals

Do not build these, even with time to spare:

- **Real dialogue, or placeholder text that reads as real dialogue.** The developer is writing
  this. Placeholder text stays obviously fake.
- A charger, power bank, or anything that slows or restores drain beyond the automatic low
  power mode in §3
- A second contact or second conversation
- Free-text input of any kind
- A score, rating, ending grade, or "you saw X% of the content" screen
- Achievements, unlockables, New Game+
- Settings, volume slider, or a main menu — go straight into the conversation
- Save/load. The run is the run.
- A seconds-remaining or decimal-percentage readout anywhere in the UI
- A skip button on the closing sequence

Spare time goes to the closing sequence's timing and to hardening the validator.

---

## 15. Export settings

Godot 4.5, **Compatibility renderer** (Forward+ does not reliably run in browsers).

Web preset: canvas resize policy `Adaptive`, export as `index.html` into a folder, zip the
whole folder.

On the itch upload: kind **HTML**, tick **"This file will be played in the browser"**, viewport
**480 × 800**, and tick **"SharedArrayBuffer support"** under Frame options. Without that last
checkbox Godot 4 renders a blank canvas, and you will find out at 3am.