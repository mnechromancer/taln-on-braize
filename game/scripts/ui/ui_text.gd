class_name UiText
extends RefCounted
## Every player-visible UI string, in the neutral UI register (Narrative Bible
## §8 rule 2): plain labels, never addressed from the fiction, no fourth-wall
## breaks. tools/checks/p2_05_checks.gd greps these (and scene text) for the
## words the between-run screen and HUD must never use.

# HUD
const HEALTH := "Health"
const INVESTITURE := "Investiture"
const NEXT_LEVEL := "Next level %d"
const INVEST_READY := "Invest  [Tab / Back]"
const DRAW := "Draw"
const STRAIN := "Strain"
const WAVE := "Wave %d / %d"
const STATION := "Station %d / %d"
const LULL := "Lull"
const RETURNS := "Returns %d"
# Braize slice: region name, tier and the difficulty clock; then the objective.
const REGION := "%s   Tier %d   Clock %d"
const BREAKER_SITE := "Breaker site  %d m  %s"
const SIEGE := "Siege  %d s"
const SEALS_OPEN := "Seals open: Tier %d ahead"
## Direction to a point relative to the camera, clockwise from straight ahead.
const ARROWS: Array[String] = ["↑", "↗", "→", "↘", "↓", "↙", "←", "↖"]
const READY := "ready"
const SECONDS := "%.1f s"
const COST := "%d"

const AGONY := "Agony"
const NOTICE_BANKED := "Agony banked"
const NOTICE_UNLOCKED := "Agony banked. Catalysis unlocked"

# Welcome the Agony and Catalyze
const WELCOME_TITLE := "Welcome the Agony"
const WELCOME_OPTION := "Welcome  [1 / A]"
const BANK_OPTION := "Bank  [2 / B]"
const CATALYZE_TITLE := "Catalyze"
const CATALYZE_BUDGET := "%d of %d ninths left"
const CATALYZE_ICON := "%s   %d"
const CATALYZE_HINT := "Hold to commit: mouse, or D-pad and A"
const RELEASE := "Release  [R / Y]"

# Between-run screen
const OUTCOME_HELD := "Held"
const OUTCOME_CLOSED := "Closed"
const SUMMARY_TIME := "Time  %d:%02d"
const SUMMARY_KILLS := "Kills  %d"
const SUMMARY_RETURNS := "Returns  %d"
const SUMMARY_FILLS := "Agony fills  %d Welcomed, %d Banked"
const SUMMARY_AGONY := "Agony banked this cycle %d, in total %d; %d to spend"
const CAPS_TITLE := "Raise a cap"
const CAP_RAISE := "%s   cap %d → %d   (costs %d)"
const CAP_MAX := "%s   cap %d"
const BEGIN_NEXT := "Begin the next cycle"
const ASPECT_TITLE := "Aspect"
# Launch pick (Braize slice)
const START_TITLE := "Begin the cycle as"
const ASPECT_OPTION := "%s"
const ASPECT_CHOSEN := "%s   (next cycle)"
const GATES_TITLE := "Open a way"
const GATE_OPEN := "%s   (costs %d)"
const GATE_OPENED := "%s   open"

# A felled breaker's drop (Braize slice)
const KIT_TITLE := "Take one"
const KIT_OPTION := "%d   %s   %s"
## By SkillDef.Kind.
const KIT_KINDS: Array[String] = ["Weapon", "Surge", "Perk"]

# Invest menu
const INVEST_TITLE := "Invest"
const INVEST_COST := "Cost %d Investiture"
const INVEST_OPTION := "%d   %s   level %d → %d"
const INVEST_CONSOLIDATE := "%d   Consolidate   restore %d%% Health"
const INVEST_HINT := "1–3, click, or D-pad and A"
const INVEST_HEAL := "Each level restores %d%% Health"
