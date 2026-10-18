# Unbroken: Taln on Braize
### Design Doc — v2.0 (Approved 2026-10-17)

*v2.0, approved 2026-10-17, from the Phase 2 gate playtest. The gate verdict: the direction holds, but it has to go much further, and the gate build's plant / hold / relocate loop is one **playstyle**, not the base loop. v2.0 adds four playstyles chosen as **Aspects** (§10), boons as **Sja-Anat's residue** (§11), and **one persistent, interconnected Braize** in place of separate arenas (§4–5). It rewords Pillar 2 and pulls the Ashynite disease core forward out of the backlog (§9). These rulings were made by the project owner on 2026-10-17. Sections §10–11 are appended so existing section numbers stay stable for cross-references. Everything else in v1.1 stands unless a section says otherwise.*

*v1.1 changes, 2026-09-25: §3 vessel provenance and §4 sky brought into line with Narrative Bible v1.0 decisions 1 and 2. No system changes.*

---

## 1. Premise

Taln, Herald of War, is the only Herald who never broke. Abandoned at Aharietiam, he holds the Oathpact alone for four and a half thousand years — dying, waking on Braize, and dying again, without end, without witness. The game is that duration, made playable.

**One-line pitch**: A bullet-heaven roguelike in which the player is the thing that refuses to break — an endless, escalating siege on Damnation, run after run, death after death, with the death itself built into the loop instead of ending it.

**Scope**: Solo-developed in intent, solo protagonist in fiction. Taln only — no other playable Heralds, no co-op. The other nine Heralds exist as narrative-only references (letters, memories, Agony-visions) — they are not on Braize and do not appear as characters. Playstyle variety comes from **Aspects** of Taln (§10), not from other characters.

**Session length target**: ~20-40 minutes per complete session. Pacing philosophy is **tight**: keep the total weapon/skill/equipment pool deliberately small, and spend that restraint on maximizing how many of those items can meaningfully synergize with each other — density of combination over sheer item count (closer to Brotato's philosophy than Megabonk's sprawl).

**Inspirations** *(v2.0)*: Megabonk and Risk of Rain 2 for the run (escalation on a clock, roaming a big map, elites, build snowball), with **bigger maps for more epic traversal**. RTS setup for Earthshaper's towers and constructs. Hades 2's boon offers, recast as Sja-Anat's residue (§11). Metroidvania gating across cycles, and launcher movement for both traversal and combat.

**Structural model**: confirmed hybrid — continuous swarm and scripted miniboss/breaker encounters both stay in. Different **regions can lean differently**: some more swarm-dominant, some closer to a pure boss-rush, rather than forcing one ratio everywhere.

---

## 2. Core Pillars

1. **Endurance, not victory.** Success is measured by how long, how many cycles, how much held — not by a DPS ceiling. *(v2.0: every Aspect is a different way of holding. See §10.)*
2. **The ground is the weapon.** *(v2.0 rewording of "Ground, not sky.")* Taln is infantry, not a Windrunner. He never flies, and base Taln has no jump. When he leaves the ground, it's because the ground threw him: terrain, Cohesion, Tension, a Shoulder off a drop. The payoff is always the landing. Stoneward power is terrain, weight and stance: control the ground under the swarm, or bring it down on them.
3. **Death is a beat, not a fail state.** Taln dying and returning to Braize is lore-mandated. It's a scripted, legible loop event, not a jarring game-over.
4. **Agony as fuel, not flavor.** What was "madness" in the last draft becomes **Agony** — a real, spendable resource. His suffering is mechanically load-bearing, not cosmetic.
5. **Small pool, dense synergy.** Fewer total items, more combinations between them — depth from interaction, not from inventory size. *(v2.0: each Aspect's own kit stays small; the shared pool and boons are where Aspects cross over.)*

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
- *(v2.0)* Drawing attention becomes literal once enemies stop being omniscient (§10, Awareness): Voidlight is loud. Stealth play is play that keeps the gem quiet.

### The Ashynite culture

- Kept in a small **Ashynite vessel** — a physical, carried container that belonged to his Ashyn-born grandmother.
- Powers the Ashynite tree. *(v2.0)* The **disease core** (seeding, spread through the swarm, infected enemies, Blight damage) is pulled forward to serve the Plaguebringer Aspect. The rest of the tree stays backlogged. See Section 9.

### The Honorblade

Not a starting weapon. The Honorblade lives in a **Special Room** — see Section 5. Sja-Anat's advice ("find/keep the Honorblade, it's more predictable") gives this room in-fiction weight beyond a genre-standard vault.

### Skill Trees as Capacity, Not Unlock Paths

Reframed further: capacity ceilings apply **per individual skill/perk/mod/ability**, not per tree. Each skill/perk/mod/ability has its own level cap, raised permanently by spending **banked Agony** — Agony that persists as the game's core meta-progression currency, spent between runs to push a specific skill's cap higher. Within a run, an owned skill is leveled up toward whatever cap it's currently reached using **Investiture**. **No in-run pickup raises a skill's cap** — cap increases are a between-runs, meta-progression-only action.

The three trees (**Stoneward**, **Herald**, **Ashynite**) still organize the pool by category/theme, but the actual progression math now lives at the individual-skill level, not the tree level: raising the ceiling (meta, per-skill, spending banked Agony) and finding-and-feeding items (in-run, spending Investiture) stay two separate axes, just retargeted from tree-wide caps down to individual skills.

Actual weapons/abilities/modifiers are acquired mostly through **Special Rooms** (plus some baseline drops from swarm/miniboss/breaker encounters). *(v2.0)* **Boons** (§11) are offered through the same channels. Trees organize the pool; **Aspects** (§10) organize how a run plays.

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
- **One persistent Braize** *(v2.0)*. Braize is **one hand-built, interconnected map** that stays the same from cycle to cycle. Its nine **stations** (Narrative Bible §3.4) are its nine **regions**, grouped into **three tiers** by depth. The map is big and vertical: crags, chasms, ledges and drops built for traversal, ground-launching and setting up positions. Routes between regions run through **gates**: ledges too high, chasms too wide, ground too broken. Gates open through **meta-progression**, so each cycle can reach further into the same place (Metroidvania across cycles). Braize being one place, learned over thousands of years, is the fiction.

---

## 5. Core Loop (bullet-heaven skeleton, adapted)

*(v2.0 rewrite for the persistent map. Proposed structure; the Core Systems Spec carries the numbers as they are tested.)*

1. Choose an **Aspect** (§10) between cycles. Drop into a cycle at a **Tier I entry** on Braize. Full 3D third-person movement + ability use against a continuous swarm that **escalates on Braize's clock**.
2. Kill enemies → collect Investiture → spend on ability use and in-run leveling (capped per-skill); build Agony independently through damage taken and hardship endured.
3. **Roam the region.** Major Fused and voidspren roam as **elites and minibosses**, Megabonk/RoR2-style. They are mid-run difficulty spikes distinct from the swarm and from breakers, and some act as **commanders** that strengthen the swarm around them and spot Taln for it (§10, Doomhunter).
4. Agony fills toward 100%; on reaching it with a Cataclysm possible, choose to **Welcome the Agony** (Catalyze now, no point banked) or decline (bank the point, skip Catalyzing this fill).
5. **Special Rooms**: each region contains exactly **three** — one **region-specific**, one **random**, one **progress-conditional** (gated on run or meta-progress) — **placed in the world** and found by exploring. Rewards include the Honorblade (temporary, for that run), new weapons/abilities/modifiers and **boons** (§11). Special Rooms are the primary way Taln acquires new kit on a given run, not just a Honorblade gate.
6. Each region holds **one breaker** — the region's boss, the moment other Heralds would have broken, that Taln survives instead. The breaker is **found in the world and player-triggered**. Once it falls, the routes onward open, and Taln pushes into a region of the **next tier** by whichever route the map and his opened gates allow. A cycle crosses **one region per tier**: three of nine, now chosen by route rather than drawn. **Additional breakers only appear if the player chooses to stay and keep fighting** in a region past its breaker, drawn from a rotating cast rather than a repeated archetype. Minibosses and breakers draw on Fused/voidspren **without reskinning existing canon Fused** — original, invented Fused variants are the intended source pool instead.
7. Death returns Taln to Braize's torture-loop — since the game already is Braize, death is reframed as a narratively-motivated checkpoint, not a jarring reset. The cycle ends **Held** when the Tier III breaker falls and he leaves, or **Closed** on the ninth Return. Neither is victory or defeat.
8. Meta-progression persists across cycles: raised per-skill caps, the Heraldic catalyst-cost-reduction skill, **opened gates**, Aspects, lore fragments.

---

## 6. Meta-Progression (draft direction)

- **Persistent currency confirmed**: Agony banks across runs as the meta-progression currency, spent per-skill to raise that skill's level cap — "the longer he holds, the stronger the Oathpact becomes" is now the literal spending mechanic, not just framing.
- Unlock targets: raised per-skill caps, the Heraldic catalyst-cost-reduction skill, Special Room variants/difficulty, lore/story unlocks (his memories, fragments of what's happening on Roshar without him, more of Sja-Anat's involvement).
- *(v2.0)* **Traversal gates** on the persistent map are a meta unlock target. Each opens new routes between regions for every later cycle. What opens a gate (banked Agony, Ashynite **Echoes**, a cleared breaker, or a mix) is open; see §8.
- *(v2.0)* **Aspects** may be unlocked through meta-progression or available from the start; open, see §8.

---

## 7. Tech / Tools

- **Engine**: Godot.
- **Camera/perspective**: Full 3D, third-person. Terrain deformation (Cohesion) and stance-based combat (Tension) both benefit from real 3D space.
- **Art pipeline**: Blender for 3D assets.
- **Dev environment**: VS Code.

---

## 8. Open Questions / Not Yet Decided

*(v2.0)* Raised by this revision, to settle through the playstyle grayboxes (roadmap P2-10 to P2-16) rather than up front:

- **Persistent-map numbers:** region size, how long a region takes, how difficulty rises on the clock, and whether the 20–40 min session still fits three regions.
- **What opens a gate:** banked Agony, Echoes, breaker clears, or a mix; and whether gates compete with cap raises for banked Agony.
- **Aspect availability:** all four from the start, or unlocked through meta-progression.
- **Boon sources:** how offers split between Toa'uma and the culture, and whether each source leans toward particular Aspects.
- **Multi-level ground:** the prototype's ground supports one walkable surface per spot. Whether Braize needs true overhangs (paths under paths) is a later call.
- **Base Anchored/Fracture:** v2.0 moves them behind the Earthshaper Aspect (§10). The grayboxes will show whether a lighter version belongs in the base loop.

---

## 9. Backlog

- **Ashynite tree specifics** — the actual list of diseases/afflictions, boon/bane pairings, how they stack or spread onto enemies, and how the Incubator/transmission-vector/Echo framing (from Word-of-Brandon material on Ashyn) translates into concrete gameplay systems. Deliberately deferred; revisit once the other two trees and the capacity/imbuement systems are further along.
  - *(v2.0)* **Pulled forward:** the disease core the Plaguebringer Aspect needs (seeding, spread by swarm density, infected enemies, Blight damage, culture-sourced boons). The rest of the tree (its full disease list, Echoes as meta effects, Incubator framing) stays here.

---

## 10. Aspects and Playstyles *(v2.0)*

### One pressure, four answers

The swarm escalates on Braize's clock, and every Aspect is a different way of **holding** against it (Pillar 1). An **Aspect** is chosen between cycles. It sets Taln's starting Weapon and Surge and grants an **Aspect passive** (no slot) that defines the loop. Like Hades' weapon aspects, it's a lens on the same Taln, not a different character.

**Aspect + drift:** the Aspect seeds the run, but in-run picks (Special Room kit and especially boons, §11) can pull a run toward hybrids. Each Aspect's own kit is small (Pillar 5). The shared pool is where Aspects cross over.

| Aspect | Answer to the swarm | Loop | What it should feel like |
|---|---|---|---|
| **Earthshaper** | Fortify it | Land → set up (raise stone towers and walls with Cohesion, call stone constructs and set their rally points) → attrition → Braize cracks the ground under you (Fracture) → move → repeat | A tower-defense / summoner commander. RTS-lite setup on ground you chose. The gate build's Anchored / Well-pool / Fracture rhythm is this Aspect's seed |
| **Meteor** | Crash through it | Get thrown by the ground (catapult terrain, a Cohesion pillar, a Tension-stiffened ramp, a Shoulder off a drop) → arc → land as the attack. Landing damage scales with fall speed and height → chain into the next launch | Mayhem traversal. Movement is the primary damage source, and the big map is the weapon |
| **Doomhunter** | Cut its head off | Track commanders (elites and minibosses that buff the swarm around them and spot Taln for it) → reach them → kill → that part of the region goes weak and deaf | A hunt. Two approaches on one Aspect: **stealth** (pick off spotters unseen) or **tank** (walk straight through the buffed swarm). The approach is the player's preference, set by drift or a passive variant |
| **Plaguebringer** | Outlast it | Stay unseen while the map fills → seed the Ashynite culture → it spreads through the crowd and buffs the infected → evade them until the disease takes them | Patient and tense. The swarm is the fuel, and the bigger it gets the better the payoff. A curator's game (Narrative Bible §6.4: "infection is a bargain") |

### Shared systems the Aspects add

- **Awareness.** Enemies stop being omniscient. The swarm hunts Taln's *last known position*. Spotters (commanders, Notice hunters) report sightings. Voidlight use and loud kills make noise. Doomhunter's stealth approach and Plaguebringer need it; Toa'uma's "drawing attention" (§3) becomes literal through it.
- **Commanders.** Elites and minibosses that buff the nearby swarm and spot for it. Every Aspect meets them; Doomhunter is built around them.
- **Disease core.** Pulled forward from the Ashynite backlog (§9) for Plaguebringer; available to drift through culture boons.

### Graybox order

Earthshaper → Meteor → Doomhunter → Plaguebringer, each on its own graybox branch off a shared base slice of the map (roadmap P2-10 to P2-16). Each Aspect is kept, reworked or cut on its own playtest.

---

## 11. Boons — Sja-Anat's residue *(v2.0)*

Boons are run-scoped offers in the Hades mould: **pick one of three**, each tagged by its source, offered in Special Rooms and after some encounters. They're the main **drift** mechanism between Aspects (§10).

**She does not make contact** (Narrative Bible decision 5 stands). The boons are what she *left* in him: bargains offered by the two things she Enlightened.

- **Toa'uma** offers Voidlight bargains. Volatile and loud; they lean on Strain and the attention it draws.
- **The culture** offers Ashynite bargains. Each is a boon paired with what it needs from him (Narrative Bible §6.4).

Her design shows in both, and her voice in neither. Proposed: boons don't take a skill slot and end with the cycle. Whether they level with Investiture is open. Their numbers and the offer rules belong to the Core Systems Spec.

---

*v1.0 approved as the Phase 1 Initial Design Doc. v2.0 approved 2026-10-17: the grayboxes (roadmap P2-10 onward) build against it. Next system-level work builds on this baseline — see the Roadmap doc.*
