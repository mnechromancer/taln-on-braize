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

# Invest menu
const INVEST_TITLE := "Invest"
const INVEST_COST := "Cost %d Investiture"
const INVEST_OPTION := "%d   %s   level %d → %d"
const INVEST_CONSOLIDATE := "%d   Consolidate   restore %d%% Health"
const INVEST_HINT := "1–3, click, or D-pad and A"
const INVEST_HEAL := "Each level restores %d%% Health"
