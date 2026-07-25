#!/usr/bin/env python3
"""Validate a Last Call dialogue.json against the schema and report its economy.

Usage:  python3 tools/validate_dialogue.py data/dialogue.json

Structural problems fail loudly (non-zero exit). The economy section is
informational. COST_PER_CHAR and the minimum send cost are read out of
scripts/config.gd so this script and the game never disagree.
"""

import json
import os
import re
import sys

REQUIRED_TOP = [
    "contact_name", "opening", "act_transitions",
    "options", "waits", "finale", "unsaid_header",
]
REQUIRED_FINALE = [
    "messages", "options", "delivered_reply",
    "closing_delivered", "closing_failed", "closing_final",
]
TARGET_LOW, TARGET_HIGH, TARGET_MID = 5.5, 6.5, 6.0


def read_config_constants(config_path):
    """Pull COST_PER_CHAR and the minimum send cost out of config.gd."""
    rate, min_cost = None, 0.02
    try:
        with open(config_path, encoding="utf-8") as f:
            text = f.read()
    except OSError:
        return None, min_cost
    m = re.search(r"const\s+COST_PER_CHAR\s*:?=\s*([0-9.]+)", text)
    if m:
        rate = float(m.group(1))
    m = re.search(r"const\s+MIN_SEND_COST\s*:?=\s*([0-9.]+)", text)
    if m:
        min_cost = float(m.group(1))
    return rate, min_cost


def cost_of(text, rate, min_cost):
    return max(min_cost, len(text) * rate)


def validate_silence(chain, label, errors):
    """A silence chain is an optional list of {idle_time: number>0, text: non-empty}."""
    if chain is None:
        return
    if not isinstance(chain, list):
        errors.append("%s must be a list" % label)
        return
    for i, entry in enumerate(chain):
        if not isinstance(entry, dict):
            errors.append("%s[%d] must be an object" % (label, i))
            continue
        it = entry.get("idle_time")
        if isinstance(it, bool) or not isinstance(it, (int, float)) or it <= 0:
            errors.append("%s[%d] idle_time must be a positive number (got %r)"
                          % (label, i, it))
        txt = entry.get("text")
        if not isinstance(txt, str) or txt.strip() == "":
            errors.append("%s[%d] text must be a non-empty string" % (label, i))
        if "final" in entry and not isinstance(entry.get("final"), bool):
            errors.append("%s[%d] final must be true or false" % (label, i))


def main():
    if len(sys.argv) != 2:
        print("usage: python3 tools/validate_dialogue.py <dialogue.json>")
        return 2

    path = sys.argv[1]
    here = os.path.dirname(os.path.abspath(__file__))
    root = os.path.dirname(here)
    config_path = os.path.join(root, "scripts", "config.gd")

    rate, min_cost = read_config_constants(config_path)
    if rate is None:
        print("WARNING: could not read COST_PER_CHAR from scripts/config.gd; "
              "using 0.005")
        rate = 0.005

    errors = []

    # --- Parse ------------------------------------------------------------
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except OSError as e:
        print("FATAL: cannot open %s (%s)" % (path, e))
        return 1
    except json.JSONDecodeError as e:
        print("FATAL: %s is not valid JSON: %s" % (path, e))
        return 1

    for key in REQUIRED_TOP:
        if key not in data:
            errors.append("missing required top-level key: '%s'" % key)

    options = data.get("options", [])
    finale = data.get("finale", {})

    # --- Option ids -------------------------------------------------------
    ids = []
    for i, opt in enumerate(options):
        oid = opt.get("id")
        if oid is None:
            errors.append("option #%d has no 'id'" % i)
        else:
            ids.append(oid)
    seen, dupes = set(), set()
    for oid in ids:
        if oid in seen:
            dupes.add(oid)
        seen.add(oid)
    for oid in sorted(dupes):
        errors.append("duplicate option id: '%s'" % oid)
    id_set = set(ids)

    # --- unlocks / removes references + self-reference --------------------
    for opt in options:
        oid = opt.get("id")
        for field in ("unlocks", "removes"):
            for ref in opt.get(field, []):
                if ref not in id_set:
                    errors.append("option '%s' %s unknown id '%s'"
                                  % (oid, field, ref))
                if ref == oid:
                    errors.append("option '%s' %s itself" % (oid, field))

    # --- act range --------------------------------------------------------
    for opt in options:
        act = opt.get("act")
        if act not in (1, 2, 3):
            errors.append("option '%s' has act %r (must be 1, 2, or 3)"
                          % (opt.get("id"), act))
        if "defer" in opt and not isinstance(opt.get("defer"), bool):
            errors.append("option '%s' defer must be true or false"
                          % opt.get("id"))

    # --- silence chains (options + opening_silence) -----------------------
    for opt in options:
        validate_silence(opt.get("silence"),
                         "option '%s' silence" % opt.get("id"), errors)
    validate_silence(data.get("opening_silence"), "opening_silence", errors)

    # --- reachability / orphans (highest-value check) ---------------------
    unlocked = set()
    for opt in options:
        for ref in opt.get("unlocks", []):
            unlocked.add(ref)
    for opt in options:
        oid = opt.get("id")
        if not opt.get("start", False) and oid not in unlocked:
            errors.append("ORPHAN: option '%s' is unreachable "
                          "(not start:true and never unlocked)" % oid)

    # --- waits cover all three acts --------------------------------------
    wait_acts = set()
    for w in data.get("waits", []):
        wait_acts.add(w.get("act"))
    for a in (1, 2, 3):
        if a not in wait_acts:
            errors.append("waits[] has no line for act %d" % a)

    # --- finale block -----------------------------------------------------
    if not isinstance(finale, dict):
        errors.append("'finale' must be an object")
    else:
        for key in REQUIRED_FINALE:
            if key not in finale:
                errors.append("finale missing required key: '%s'" % key)
        fin_opts = finale.get("options", [])
        if len(fin_opts) != 4:
            errors.append("finale.options must have exactly 4 entries "
                          "(found %d)" % len(fin_opts))

    # --- Report -----------------------------------------------------------
    print("=" * 60)
    print("Validating: %s" % path)
    print("COST_PER_CHAR = %s   MIN_SEND_COST = %s" % (rate, min_cost))
    print("=" * 60)

    if errors:
        print("\nFAILED - %d structural problem(s):\n" % len(errors))
        for e in errors:
            print("  * " + e)
        print("\nFix these before shipping. Economy report skipped.")
        return 1

    print("\nStructure OK.\n")

    # Economy -------------------------------------------------------------
    per_act = {1: 0, 2: 0, 3: 0}
    costs = []
    for opt in options:
        c = cost_of(opt.get("text", ""), rate, min_cost)
        costs.append((c, opt.get("id")))
        per_act[opt.get("act", 0)] = per_act.get(opt.get("act", 0), 0) + 1
    total = sum(c for c, _ in costs)

    print("--- Economy report -------------------------------------------")
    print("Options: %d   (act 1: %d, act 2: %d, act 3: %d)"
          % (len(options), per_act[1], per_act[2], per_act[3]))
    print("Total send cost: %.3f   (budget 4.00, target band %.1f-%.1f)"
          % (total, TARGET_LOW, TARGET_HIGH))
    if costs:
        cheapest = min(costs)
        dearest = max(costs)
        print("Cheapest: %.3f  (%s)" % (cheapest[0], cheapest[1]))
        print("Dearest:  %.3f  (%s)" % (dearest[0], dearest[1]))
        print("Mean:     %.3f" % (total / len(costs)))

    if total < TARGET_LOW or total > TARGET_HIGH:
        total_len = sum(len(o.get("text", "")) for o in options)
        if total_len > 0:
            suggested = TARGET_MID / total_len
            print("\nOut of band. To hit %.1f, set in scripts/config.gd:"
                  % TARGET_MID)
            print("    const COST_PER_CHAR := %.5f" % suggested)
            print("(Never change START_BATTERY or the dialogue to compensate.)")
    else:
        print("\nIn band. A single playthrough should surface ~55-65%% "
              "of the content.")

    return 0


if __name__ == "__main__":
    sys.exit(main())
