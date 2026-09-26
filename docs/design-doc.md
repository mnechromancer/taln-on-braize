# Unbroken: Taln on Braize
### Design Doc — v1.1 (Approved v1.0 + Narrative Bible conformance)

*v1.1 changes, 2026-09-25: §3 vessel provenance and §4 sky brought into line with Narrative Bible v1.0 decisions 1 and 2. No system changes.*

---

## 1. Premise

Taln, Herald of War, is the only Herald who never broke. Abandoned at Aharietiam, he holds the Oathpact alone for four and a half thousand years — dying, waking on Braize, and dying again, without end, without witness. The game is that duration, made playable.

**One-line pitch**: A bullet-heaven roguelike in which the player is the thing that refuses to break — an endless, escalating siege on Damnation, run after run, death after death, with the death itself built into the loop instead of ending it.

**Scope**: Solo-developed in intent, solo protagonist in fiction. Taln only — no other playable Heralds, no co-op. The other nine Heralds exist as narrative-only references (letters, memories, Agony-visions) — they are not on Braize and do not appear as characters.

**Session length target**: ~20-40 minutes per complete session. Pacing philosophy is **tight**: keep the total weapon/skill/equipment pool deliberately small, and spend that restraint on maximizing how many of those items can meaningfully synergize with each other — density of combination over sheer item count (closer to Brotato's philosophy than Megabonk's sprawl).

**Structural model**: confirmed hybrid — continuous swarm and scripted miniboss/breaker encounters both stay in. Different **areas can lean differently**: some more swarm-dominant, some closer to a pure boss-rush, rather than forcing one ratio everywhere.

---

## 2. Core Pillars

1. **Endurance, not victory.** Success is measured by how long, how many cycles, how much held — not by a DPS ceiling.
2. **Ground, not sky.** Taln is infantry, not a Windrunner. Stoneward power is terrain, weight, and stance — control the ground under the swarm rather than escape above it.
3. **Death is a beat, not a fail state.** Taln dying and returning to Braize is lore-mandated. It's a scripted, legible loop event, not a jarring game-over.
4. **Agony as fuel, not flavor.** What was "madness" in the last draft becomes **Agony** — a real, spendable resource. His suffering is mechanically load-bearing, not cosmetic.
5. **Small pool, dense synergy.** Fewer total items, more combinations between them — depth from interaction, not from inventory size.

---

## 3. Protagonist: Taln

### The Bond — origin story

Before Taln's return to Braize, **Sja-Anat visits him**. At this point he has already kept a single Ashynite disease-culture alive and contained for thousands of years — his grandmother's, brought from Ashyn (Narrative Bible §6.2, decision 1). Sja-Anat:

- **Modifies the Ashynite culture he already carries**, Enlightening it rather than introducing a new one from outside.
- **Gives him a gem containing an Enlightened peakspren** — a second bond, not a first. Forming more than one Nahel-adjacent bond is extremely difficult without proper resources, which Sja-Anat lacked at the time; giving Taln two tools instead of one was already pushing what she could manage.
- **Advises him to use the peakspren only when absolutely necessary**, and to prioritize recovering or keeping his Honorblade as his primary means of accessing his Surges — the Blade is far more predictable than the spren.

Sja-Anat's motive reads as consistent with her established pattern (Taker of Secrets, secretly working against Odium, willing-subjects-only Enlightenment): she is experimenting on Taln — and on the culture and the spren — as much for her own sake as his. Every successful Enlightening is a rep for abilities she'll need against Odium or any other power that might try to enslave her again; Taln is a low-visibility test case she can run without drawing Odium's notice.

### The peakspren

- Kept in a **gem**, not walking around as a physical spren-form.
- **Talks, has a personality** — strange, possibly volatile, tinged with something eldritch. Grants access to **Voidlight**, unpredictably. "Unpredictable" is intentionally layered rather than one single mechanic: expect a mix of **random side effects** on use, **escalating risk the more it's used** in a given cycle, and a standing chance of **drawing unwanted attention** in-fiction (Odium-adjacent forces noticing the Voidlight signature). All three flavors are in scope, not a choice between them.
- Per Sja-Anat's own advice, it's the *second-choice* tool — the Honorblade, when available, is the steadier option.

### The Ashynite culture

- Kept in a small **Ashynite vessel** — a physical, carried container that belonged to his Ashyn-born grandmother.
- Powers the Ashynite tree. **Full mechanical specifics are backlogged** — see Section 9.

### The Honorblade

Not a starting weapon. The Honorblade lives in a **Special Room** — see Section 5. Sja-Anat's advice ("find/keep the Honorblade, it's more predictable") gives this room in-fiction weight beyond a genre-standard vault.

### Skill Trees as Capacity, Not Unlock Paths

Reframed further: capacity ceilings apply **per individual skill/perk/mod/ability**, not per tree. Each skill/perk/mod/ability has its own level cap, raised permanently by spending **banked Agony** — Agony that persists as the game's core meta-progression currency, spent between runs to push a specific skill's cap higher. Within a run, an owned skill is leveled up toward whatever cap it's currently reached using **Investiture**. **No in-run pickup raises a skill's cap** — cap increases are a between-runs, meta-progression-only action.

The three trees (**Stoneward**, **Herald**, **Ashynite**) still organize the pool by category/theme, but the actual progression math now lives at the individual-skill level, not the tree level: raising the ceiling (meta, per-skill, spending banked Agony) and finding-and-feeding items (in-run, spending Investiture) stay two separate axes, just retargeted from tree-wide caps down to individual skills.

Actual weapons/abilities/modifiers are acquired mostly through **Special Rooms** (plus some baseline drops from swarm/miniboss/breaker encounters).

### Resources

- **Investiture** — primary, in-run spendable resource. Sourced from the peakspren bond, from Braize itself (ambient), and from slain voidspren/Fused (on-kill). Fuels basic ability use and in-run leveling across all three trees. **Fully independent from Agony.**
- **Agony** — secondary resource, one meter with a per-fill decision point rather than two separate pools. In-run, it builds from taking damage, dying/returning, and enduring hardship in-cycle. When it fills to 100%, **if a Cataclysm is currently possible** (an eligible catalyst — weapon/item/skill — is equipped), Taln is prompted to **"Welcome the Agony."** The tradeoff is direct and mutually exclusive: **accept → Catalyze now, no Agony point banked; decline → bank the point toward meta-progression, no Catalyze this fill.**

### Imbuing & Cataclysms

Catalysis requires Agony maxed to 100% — that's the hard gate. Once there, if a Cataclysm is possible, Taln is offered the "Welcome the Agony" choice (see Resources above); accepting opens the Catalyze decision.

Each individual **catalyst** (a weapon, item, or skill capable of Catalyzing) has its **own Agony cost**, spent against that single 100% fill. **Cheap catalysts are available as soon as Catalysis unlocks** — the mechanic works from the start, not just after investment. A **Heraldic skill** reduces per-catalyst Agony cost as it's upgraded, widening what fits under one 100% fill over time: starting range is roughly "one expensive catalyst OR one cheap one," progressing toward "two cheap ones," and further from there as the skill levels. Combination isn't a separate expensive mode with its own premium; it's whatever fits under the budget once individual costs are low enough.

**Activation**: Cataclysms fire via a **hold-and-click on the specific catalyst in the UI** — an explicit, deliberate input, not an automatic proc.

---

## 4. Setting: Braize as the Arena

- Braize/Damnation: shadows and a black sky with no sun and no light sources; every light is Invested (Narrative Bible §3.2, decision 2). Visually the inverse of Roshar's storms-and-light aesthetic. Desaturated, ashen, wrong-feeling geometry.
- The arena is not neutral ground — it's built to torture him. Terrain should feel hostile/reactive rather than a generic field full of monsters.
- Enemy roster candidate pool: Fused, voidspren, Odium's forces generally.
- Cyclical structure: each run = one torture-cycle. The genre's "waves never stop" convention needs no invented metaphor here — Braize already is that.

---

## 5. Core Loop (bullet-heaven skeleton, adapted)

1. Drop into a cycle on Braize. Full 3D third-person movement + ability use against a continuous, escalating swarm.
2. Kill enemies → collect Investiture → spend on ability use and in-run leveling (capped per-skill); build Agony independently through damage taken and hardship endured.
3. **Major Fused or voidspren appear as minibosses** within a cycle, Megabonk-style — mid-run difficulty spikes distinct from the swarm and from breaker encounters.
4. Agony fills toward 100%; on reaching it with a Cataclysm possible, choose to **Welcome the Agony** (Catalyze now, no point banked) or decline (bank the point, skip Catalyzing this fill).
5. **Special Rooms**: each area contains exactly **three** — one **area-specific**, one **random**, one **progress-conditional** (gated on run or meta-progress) — all unlocking once that area's standard waves are cleared. Rewards include the Honorblade (temporary, for that run) as well as new weapons/abilities/modifiers — Special Rooms are the primary way Taln acquires new kit on a given run, not just a Honorblade gate.
6. Each area's standard structure ends in **one breaker** — the area's boss, the moment other Heralds would have broken, that Taln survives instead. **Additional breakers only appear if the player chooses to keep fighting waves in that area** past clearing it, drawn from a rotating cast rather than a repeated archetype. Minibosses and breakers draw on Fused/voidspren **without reskinning existing canon Fused** — original, invented Fused variants are the intended source pool instead.
7. Death returns Taln to Braize's torture-loop — since the game already is Braize, death is reframed as a narratively-motivated checkpoint, not a jarring reset.
8. Meta-progression persists across cycles: raised per-skill caps, the Heraldic catalyst-cost-reduction skill, lore fragments.

---

## 6. Meta-Progression (draft direction)

- **Persistent currency confirmed**: Agony banks across runs as the meta-progression currency, spent per-skill to raise that skill's level cap — "the longer he holds, the stronger the Oathpact becomes" is now the literal spending mechanic, not just framing.
- Unlock targets: raised per-skill caps, the Heraldic catalyst-cost-reduction skill, Special Room variants/difficulty, lore/story unlocks (his memories, fragments of what's happening on Roshar without him, more of Sja-Anat's involvement).

---

## 7. Tech / Tools

- **Engine**: Godot.
- **Camera/perspective**: Full 3D, third-person. Terrain deformation (Cohesion) and stance-based combat (Tension) both benefit from real 3D space.
- **Art pipeline**: Blender for 3D assets.
- **Dev environment**: VS Code.

---

## 8. Open Questions / Not Yet Decided

None currently logged at approval time. Anything raised after this point gets tracked in a future revision, not folded back into v1.0 silently.

---

## 9. Backlog

- **Ashynite tree specifics** — the actual list of diseases/afflictions, boon/bane pairings, how they stack or spread onto enemies, and how the Incubator/transmission-vector/Echo framing (from Word-of-Brandon material on Ashyn) translates into concrete gameplay systems. Deliberately deferred; revisit once the other two trees and the capacity/imbuement systems are further along.

---

*Approved as the Phase 1 Initial Design Doc. Next system-level work (Core Systems Spec, Narrative Bible, Art Direction) builds on this baseline — see the Roadmap doc.*
