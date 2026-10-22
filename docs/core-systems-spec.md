# Unbroken: Taln on Braize
### Core Systems Spec — v1.6 (v1.0–v1.2 approved; v1.3 rows for review at the Phase 2 gate; v1.4 rows follow Design Doc v2.0; v1.5 from P2-10; v1.6 from P2-12; see §15)

*Phase 2 deliverable. Parent documents: Design Doc v1.1 (governs mechanics intent), Narrative Bible v1.1 (governs fiction), Art Direction v1.1 (governs visuals). This document turns their intent into numbers, state machines and system boundaries that the prototype can be built against. Every number here is a **starting value for the prototype**, not a balance commitment; the Phase 4 Balancing doc supersedes them.*

*Tags: **[DD]** restates a Design Doc rule (do not change here) · **[PROPOSED]** originated in this spec (all approved in v1.0; see §14) · **[NINE]** a place where Braize's nine-centricity (Narrative Bible §3.3, decision 4) is carried structurally.*

---

## 0. Scope

**In scope:** run structure and pacing; Investiture economy and leveling curve; Agony meter, Welcome the Agony, catalyst costs and Catalyze flow; Toa'uma (peakspren) risk model; health, damage, mitigation and Return (death); movement, stance and camera values; enemy scaling and spawn budget; technical architecture boundaries (Godot / GDScript / C++); performance and light budgets.

**Out of scope (owned elsewhere):** individual skill/weapon/catalyst content and Cataclysm effects (Phase 4 Full Content List); final meta cap-raise curve (Phase 4 Meta-Progression Spec — §9 here is provisional); enemy roster and attack patterns (Phase 3 Enemy Design doc); data authoring format (Phase 3 Content Pipeline doc — §11.4 here defines only the fields systems depend on); Ashynite mechanics (Design Doc §9 backlog), except the disease core that Design Doc v2.0 pulls forward (§15 v1.4).

**Units:** distance in meters (1 Godot unit = 1 m), time in seconds, speeds in m/s, rates per second unless stated.

---

## 1. Run Structure and Pacing

### 1.1 Hierarchy [PROPOSED]

> **v1.4:** stations become the nine regions of one persistent map, and a cycle crosses one region per tier by route. §1.1–1.3 hold for the gray-box stand-in until P2-10 replaces them. See §15 v1.4 #4.

| Level | Name | Definition |
|---|---|---|
| Run | **Cycle** | One session, one torture-cycle. Target 25–35 min standard; 20–40 min envelope [DD]. |
| Area | **Station** | One of **nine** areas [NINE]. A cycle visits **three** stations. |
| Segment | **Wave** | A station's standard swarm is **nine waves** [NINE], ~45 s each. |

**Why three of nine:** nine full stations cannot fit a 20–40 min session with three Special Rooms and a breaker each. Three stations × three Special Rooms = nine Special Rooms per cycle [NINE].

**Station selection:** the nine stations are grouped into three tiers of three. A cycle draws one station from Tier I, then Tier II, then Tier III (seeded per cycle). Swarm-dominant vs boss-leaning weighting is a per-station property [DD].

### 1.2 Station timeline

| Phase | Duration (target) | Contents |
|---|---|---|
| Waves 1–9 | ~6.75 min | Continuous swarm, escalating per wave. **Minibosses spawn at the start of waves 4 and 7.** |
| Lull | player-paced | Swarm drops to a trickle (15% of wave-9 spawn budget). All three Special Rooms unlock [DD]. Breaker site activates. |
| Special Rooms | ~45–75 s each | Area-specific, random, progress-conditional [DD]. Player may skip any. |
| Breaker | ~90–150 s | **Player-triggered** by entering the breaker site. One breaker per station, fixed per station [DD]. |
| Overstay (optional) | open-ended | After the breaker, the player may keep fighting: waves resume at wave-9 intensity +9% per overstay wave; an **additional breaker every three overstay waves**, drawn from the rotating cast of nine [DD][NINE]. Leaving is available between overstay waves. |

Standard cycle: 3 × (6.75 + ~2.5 rooms + ~2 breaker) ≈ 34 min at the long end; ~26 min if rooms are skipped quickly.

### 1.3 Cycle end — no win, no loss [PROPOSED]

A cycle ends in exactly one of two ways, and **neither is framed as victory or defeat** (Narrative Bible §2.3, Pillars 1 and 3):

- **Held:** the third station's breaker falls and the player leaves (or leaves overstay). Fiction: the Fused rotate him to the next cycle.
- **Closed:** Taln Returns (dies) for the **ninth** time in the cycle [NINE]. Fiction: the cycle closes over him; same outcome as Held, different beat.

Both routes keep every banked Agony point and unlocked lore. Held adds a station-clear lore fragment per station cleared; Closed does not. The between-run screen never says "win," "lose," "game over" or "victory."

---

## 2. Investiture (in-run resource)

### 2.1 Role [DD]

Primary in-run resource; fully independent of Agony. Spent on (a) manual Surge use and (b) leveling owned skills toward their current cap. Sources: on-kill, Braize ambient (the Well), and the peakspren bond.

Investiture is held in one reservoir with no cap. **Using Surges and leveling draw from the same pool** — that tension is intended.

### 2.2 Station value multiplier

All Investiture income is multiplied by the station's value: **v = 1 / 2 / 3** for the first / second / third station of the cycle.

### 2.3 Sources

| Source | Base amount (×v) | Notes |
|---|---|---|
| Swarm kill | 1 mote | Mote must be collected. Pickup radius 2.5 m; motes inside radius fly to Taln at 18 m/s. Motes persist 30 s, then sink into the ground (lost to the Well). |
| Elite kill | 9 | Single large mote. |
| Miniboss kill | 90 | Burst of motes. |
| Breaker kill | 270 | Burst of motes; auto-collected. |
| **Ambient Well** | 0.5/s | Always on during waves and overstay. Off during Special Rooms. |
| **Well pools** | 4/s while **Anchored** (§6.3) inside | Up to 3 pools active per station, radius 3 m, each holds 90. A depleted pool relocates after 20 s. Standing in a pool without Anchoring gives 1/s. |
| **Toa'uma: Draw** | 30 | Manual action, 9 s cooldown. Adds Strain (§5). |

Design intent of the Well pools: Braize pays Taln to stand still, and then punishes him for it (§6.4). That is the "ground, not sky" rhythm — plant, hold, relocate.

### 2.4 Leveling [PROPOSED]

- **Player-triggered.** When held Investiture ≥ the next level cost, the level indicator lights. The player presses **Invest** to pause and choose. The player can bank Investiture past the threshold (e.g., to afford Surges through a breaker) and level later. Level costs are not refunded by waiting — there is no interest.
- **Offer:** up to three options, drawn from **owned skills below their current cap** (weighted toward skills with fewer levels). No new skills are offered at level-up; new kit comes from Special Rooms and encounter drops [DD]. If fewer than three are eligible, fewer are shown.
- **Cost of the nth level-up in the cycle (n = 0, 1, 2, …):**

  `C(n) = round(54 × 1.1^n)`

  | n | 0 | 4 | 8 | 13 | 17 | 22 | 26 |
  |---|---|---|---|---|---|---|---|
  | C(n) | 54 | 79 | 116 | 186 | 273 | 440 | 644 |

- **Pacing target:** ~9 level-ups per station, ~27 per standard cycle [NINE]. Check against income (median player, ~35% of income spent on Surges):

  | Station | Est. gross income | Net for leveling | Cost of 9 levels | Result |
  |---|---|---|---|---|
  | 1 (v=1) | ~1,450 | ~940 | 733 (n 0–8) | ~10 levels |
  | 2 (v=2) | ~4,100 | ~2,650 | 1,729 (n 9–17) | ~10 levels |
  | 3 (v=3) | ~7,700 | ~5,000 | 4,077 (n 18–26) | ~10 levels |

  Assumes kill rate ~100/min (S1) → ~180/min (S2) → ~250/min (S3), plus elites, two minibosses, the breaker and ambient Well; Well pools excluded. Estimate lands at ~30 levels, slightly over target: trim via mote value or the 1.1 growth rate once real telemetry exists. The prototype must log kill rates; this table is the first thing the Balancing doc replaces.

- **Level-up heal:** each level-up restores 9% of max Health [NINE].
- **Capped out:** if Invest is pressed and every owned skill is at cap, the player may **Consolidate** instead: spend C(n) to restore 25% max Health. C(n) still advances n. Early meta (low caps) hits this often; that is the felt pressure to spend banked Agony on caps.

### 2.5 Skill slots and taxonomy [PROPOSED]

| Kind | Occupies slot | Levels | Input |
|---|---|---|---|
| **Weapon** | Yes | Yes | Auto-fires; no Investiture cost |
| **Surge** (Cohesion/Tension abilities; Voidlight skills) | Yes | Yes | Manual; costs Investiture; max 3 bound at once |
| **Perk** | Yes | Yes | Passive |
| **Modifier** | No | No | Passive; alters a tagged skill or set of skills. The synergy glue (Pillar 5) |
| **Catalyst** | — | — | Not a kind: a **tag** on any Weapon, Surge, Perk or Modifier, with a cost tier (§4.3) |

- **Nine skill slots per cycle** [NINE], no per-tree limit.
- Taln starts each cycle with one Weapon, one Surge, and the innate Heraldic cost-reduction skill (§4.4), which does not use a slot.
- Each skill starts at level 1 when acquired. **Starting cap: 3.** Maximum cap: **9** [NINE]. Caps are raised only between cycles with banked Agony [DD].

---

## 3. Agony — the meter

### 3.1 Structure [DD + NINE]

One meter. Internally 0–900; displayed as **nine segments ("ninths")** with notches, 100 per ninth. Catalyst costs are expressed in ninths (§4.3).

### 3.2 Gain

| Source | Agony | Notes |
|---|---|---|
| Damage taken | 1 per 1% of max Health lost, post-mitigation | A full health bar of damage = 100 = one ninth |
| **Return** (death) | 300 (three ninths) | §6.6 |
| Endurance | 1/s | Always, during waves, lull and overstay. Time on Braize is itself the hardship |
| Pressed | +2/s | While ≥ 9 enemies are within 6 m [NINE] |
| Breaker phase | +1/s | While a breaker is alive |

- **Target cadence:** one full fill every ~3 min for a median player → **~9 fills per standard cycle** [NINE].
- **Self-correcting:** struggling players take more damage and Return more, fill faster, and bank more. Strong players bank less per cycle but survive longer. This is deliberate: the meta economy favors endurance, not skill ceiling (Pillar 1).
- **Anti-farming guard:** Returns grant Agony but cost held Investiture, escalate pressure (§6.6) and count toward the ninth-Return close. No invulnerable damage sources may exist in the arena.
- Gain is suspended during Special Rooms, level-up pause, and the Return sequence.

### 3.3 On reaching 900

The meter locks at 900; further gain is discarded until it resolves.

**Case A — no Cataclysm possible** (no catalyst owned, Catalysis not yet unlocked, or the cheapest owned catalyst costs more than nine ninths — impossible by §4.4 but checked anyway): the point **auto-banks**. Non-pausing notice. Meter → 0.

**Case B — Cataclysm possible:** the **Welcome the Agony** prompt fires [DD].

### 3.4 Welcome the Agony — state machine [PROPOSED timing]

```
FILLED ──► PROMPT  (time scale 0.1×, 6.0 s real-time window)
            ├─ Decline / timeout ──► BANK   (+1 banked point, meter → 0)
            └─ Welcome ──────────► CATALYZE (time scale 0.1×, 9.0 s real-time window)
                                     ├─ commit ≥1 catalyst, then Release or budget exhausted
                                     │      ──► FIRE (all committed Cataclysms fire together; meter → 0; no point banked)
                                     └─ window expires with 0 committed
                                            ──► BANK (+1, meter → 0)   ← accepting is never a trap
```

- **Timeout defaults to Bank.** Declining is the conservative choice and costs nothing but the Cataclysm.
- **Commit input:** hold-and-click on the catalyst's icon for **0.6 s real-time** [DD activation]; gamepad: hold A on the focused icon. The icon fills in Agony hue while held; its cost appears as notches consumed on the meter (Art Direction, Catalyze UI).
- **Committed catalysts fire together on Release**, so combinations resolve as one event. Firing order within the event is by cost tier, cheapest first.
- **Unspent ninths are discarded.** The budget is one fill; there is no remainder carry. Packing the budget is the skill expression.
- **Accessibility option:** full pause instead of 0.1× dilation for both windows.

---

## 4. Catalysts and Cataclysm Budget

### 4.1 Gate [DD]

Catalysis requires a full meter (9/9). Cheap catalysts work as soon as Catalysis is unlocked.

### 4.2 Catalysis unlock [PROPOSED]

Catalysis unlocks on the player's **first banked Agony point** ever. Before that, fills auto-bank (Case A). Rationale: the first-ever fill teaches banking; the second teaches the choice.

### 4.3 Cost tiers

Every catalyst belongs to one tier. Costs are in ninths, set by the level of the Heraldic skill (§4.4).

| Tier | Intent |
|---|---|
| **Lesser** | Cheap; available from the start; the combination fodder |
| **Greater** | Mid |
| **Grand** | Expensive; fills the whole budget at base |

### 4.4 The Heraldic cost-reduction skill

Working name **Bearer of Agonies** (a canon title of Taln's; name open). Innate — owned every cycle, no slot, starts at level 1. Levels in-run with Investiture like any skill, capped by its meta cap. **Starting cap: 2** (so early meta allows one catalyst per fill only [DD]).

| Level | Lesser | Greater | Grand | Largest combinations under 9 |
|---|---|---|---|---|
| 1 | 5 | 7 | 9 | any one [DD start state] |
| 2 | 5 | 7 | 8 | any one |
| 3 | 4 | 6 | 8 | **two Lesser** [DD "two cheap"] |
| 4 | 4 | 6 | 7 | two Lesser |
| 5 | 4 | 5 | 7 | Lesser + Greater |
| 6 | 3 | 5 | 6 | three Lesser · Lesser + Grand |
| 7 | 3 | 4 | 6 | Greater + Greater · Lesser + Grand |
| 8 | 3 | 4 | 5 | Greater + Grand |
| 9 | 2 | 4 | 5 | four Lesser · Lesser + Lesser + Grand |

Costs are a table, not a formula, so each level can be tuned to unlock a specific combination shape. Combination has no premium [DD]; it is whatever fits.

---

## 5. Toa'uma — Voidlight risk model

### 5.1 Surge routing [PROPOSED]

Taln's Surges run through one of two channels:

- **Toa'uma (default):** every Surge cast and every Draw routes Voidlight through the gem and adds **Strain**.
- **Honorblade (once acquired from its Special Room, for the rest of that cycle [DD]):** Cohesion/Tension Surges route through the Blade and add **no Strain**. Skills explicitly tagged *Voidlight* always route through Toa'uma.

This makes Sja-Anat's advice literal (Design Doc §3, Narrative Bible §5.3): the Blade is the predictable channel; the spren is the one that bites.

### 5.2 Strain

Per-cycle value, 0–9 [NINE]. **No decay within a cycle**; resets to 0 at cycle start. Displayed only diegetically (gem pulse, per Art Direction), plus an optional HUD pip row.

| Action | Strain |
|---|---|
| Draw (§2.3) | +1.0 |
| Surge cast via Toa'uma | +0.25 × the Surge's Investiture cost ÷ 25 |

### 5.3 The three flavors of unpredictable [DD: all three in scope]

**Random side effects** — on every Toa'uma-routed use, roll `p = 0.05 + 0.05 × Strain` (max 0.50). On a hit, draw from a weighted table. The table is mixed (volatile, not purely punitive). Initial table:

| Effect | Weight | Result |
|---|---|---|
| Overcharge | 3 | The Surge fires at 200% magnitude |
| Voidlight burn | 3 | Taln takes 6% max Health (feeds Agony normally) |
| Misfire | 2 | The Surge fires at a random direction within ±45° of aim (a 90° cone) |
| Lurch | 2 | Local gravity spike: Taln and enemies within 6 m slowed 40% for 2 s |
| Echo | 1 | The Surge fires again 1.0 s later at no cost |
| Speaks | 2 | A Toa'uma line; no mechanical effect |

A Draw can't Misfire or Echo; those results are rerolled. An Overcharged Draw grants double Investiture.

**Escalating risk** — carried by `p` rising with Strain.

**Drawing attention** — at Strain **3, 6 and 9**, a **Notice** event: an elite hunter pack (Enemy Design doc defines them) spawns on the arena edge and targets Taln directly. Placeholder pack sizes until that doc lands: 3 hunters at Strain 3, 5 at Strain 6, 9 at Strain 9. Hunters from the Strain 3 and 6 Notices die after 30 s if not killed; at Strain 9, the hunters persist until killed and Voidlight side-effect weights shift toward Burn and Misfire.

---

## 6. Taln: Health, Damage, Stance, Return

### 6.1 Core stats (base, before skills)

| Stat | Value |
|---|---|
| Max Health | 150 |
| Health regen | 0 (regen only from skills/perks) |
| Armor | 0 |
| Move speed | 6.0 m/s |
| Crit chance / multiplier | 5% / 1.5× |

### 6.2 Damage model

- **Mitigation:** `damage_taken = raw × 100 / (100 + Armor)` — diminishing returns, never immune.
- **Damage types:** **Kinetic** (Stoneward, Honorblade), **Void** (Toa'uma and all enemy Voidlight), **Blight** (Ashynite; reserved, backlogged). Enemies carry per-type resistance multipliers; Taln's Armor applies to all types.
- **Contact damage:** each enemy may damage Taln at most once per 0.75 s. After any hit, Taln has 0.2 s of global invulnerability (prevents swarm frame-stacking).
- **Knockback:** enemies have **Mass** (swarm 1, elite 4, miniboss 20, breaker ∞). Knockback distance = force ÷ Mass. Taln's knockback received is ignored while Anchored.

### 6.3 Stance: Anchored [PROPOSED — Pillar 2]

> **v1.4:** §6.3 and §6.4 move behind the Earthshaper Aspect. See §15 v1.4 #2.

- **Enter:** no movement input for **0.6 s**.
- **While Anchored:** +40 Armor; immune to knockback; Well-pool draw 4/s (§2.3); Stoneward skills may key off the state.
- **Exit:** any movement input or a Shoulder charge. Re-entering requires another 0.6 s, counted from when input stops or the charge ends.

### 6.4 Fracture — Braize punishes stillness

Art Direction: "stillness is punished visually before mechanically." Timeline for continuous stillness within a 3 m radius:

| Stationary time | Effect |
|---|---|
| 0–6 s | None |
| 6–9 s | Ground darkens and cracks around Taln (visual only) |
| 9 s + | **Fracture:** 3% max Health per second as Kinetic damage, rising 1% per further second, until Taln moves > 3 m |

The Fracture timer resets after Taln has been > 3 m from the spot for 3 s. Net rhythm: plant for ~6–9 s of Anchored benefit, then relocate.

### 6.5 Shoulder (base mobility) [PROPOSED]

> **v1.4:** still no base jump. Air time comes from the ground. See §15 v1.4 #3.

**No jump.** Taln is infantry; the ground is the game (Pillar 2). Base mobility is a heavy charge:

| Parameter | Value |
|---|---|
| Distance | 4.5 m over 0.25 s |
| Cooldown | 3.0 s |
| Effect | Knocks back swarm-Mass enemies in path (force 12); 0.25 s invulnerability during charge |
| Terrain | Walls hit within 60° of head-on stop the charge; shallower hits slide along the wall. Crosses gaps up to 1 m; over a wider gap the charge ends just past the edge and Taln falls in. Off a drop (no ground at the same level beyond the edge) the charge carries on through the air |
| End | Taln stops dead when the charge ends. Momentum carry is reserved for upgrades |

### 6.6 Return (death)

- **Trigger:** Health reaches 0.
- **Sequence:** fixed-timing Return beat per Art Direction (ash, reassemble, one breath). **4.5 s** first viewing; skippable to **1.5 s** thereafter. Enemies do not act during it.
- **On reform:** full Health; a **reform shockwave** kills swarm-tier enemies and knocks back elites within 9 m [NINE] (prevents instant re-death); **+300 Agony**; **Braize takes one third of held Investiture** (sinks to the Well); **pressure step:** spawn budget +9% for the rest of the station.
- **Position:** Taln reforms in place, unless in a hazard or out of bounds, then at the nearest safe navmesh point.
- **Ninth Return closes the cycle** (§1.3).

---

## 7. Movement and Camera

### 7.1 Character controller

| Parameter | Value |
|---|---|
| Collider | Capsule, height 2.0 m, radius 0.45 m |
| Move speed | 6.0 m/s |
| Acceleration / deceleration | 40 / 55 m/s² (≈0.15 s to full speed; weighty but responsive) |
| Turn rate | 720°/s, faces movement direction; upper body faces aim during Surge casts |
| Max slope | 40° |
| Step height | 0.35 m |
| Gravity | 20 m/s² (ledge drops only; no jump) |
| Movement frame | Camera-relative on the ground plane |

Swarm speeds are set relative to Taln (§8.2) so kiting is always possible without Shoulder, but not comfortable.

### 7.2 Camera [PROPOSED]

Third-person, high and far enough to read the swarm (Megabonk readability reference, Art Direction).

| Parameter | Value |
|---|---|
| Rig | SpringArm3D on a yaw pivot following Taln |
| Default distance | 10 m |
| Default pitch | −40° |
| Pitch range | −25° to −65° |
| Zoom range | 7–14 m (player setting) |
| FOV | 70° vertical |
| Follow | Position lerp, 12/s; no lag on yaw |
| Orbit | Mouse / right stick, 180°/s at full stick; free 360° yaw |
| Collision | Spring arm margin 0.3 m; geometry between camera and Taln fades to 30% opacity instead of pulling the camera in (keeps swarm framing stable) |
| Shake | Trauma model (0–1, decays 1.5/s; offset ∝ trauma²); global scale in settings. Juice pass (Phase 6) owns values |

### 7.3 Aiming

- **Weapons** auto-target (nearest, or per-weapon rule).
- **Surges:** one scheme for both KB+M and gamepad: camera-forward projected on the ground with a **30° soft-lock cone** to the densest cluster within the Surge's range. While a Surge is ready, a ground reticle shows its area.

---

## 8. Enemies — scaling and spawning (system level only)

Roster, families and attack patterns belong to the Enemy Design doc. This section defines the numbers the spawner and the stat system need.

### 8.1 Tiers

| Tier | Base HP | Base contact dmg | Speed (m/s) | Simulation (§11) |
|---|---|---|---|---|
| Swarm | 12 | 6 | 3.2–4.6 | SwarmServer (data, C++) |
| Elite | 120 | 14 | 3.0–5.0 | SwarmServer, flagged |
| Miniboss | 2,500 | 20 + attacks | 2.5–4.0 | Scene nodes (GDScript) |
| Breaker | 9,000 | attacks | varies | Scene nodes (GDScript) |

### 8.2 Scaling

- **HP multiplier:** `(1 + 0.12 × w) × S_s`, with w = wave index 0–8 and **S = 1.0 / 2.2 / 4.5** by station.
- **Damage multiplier:** `(1 + 0.05 × w) × D_s`, **D = 1.0 / 1.5 / 2.1**.
- Overstay continues w past 8 at the same slopes.
- Top swarm speed never exceeds 80% of Taln's current move speed.

### 8.3 Balancing target: time-to-kill, not DPS

Weapon numbers are set in content docs, but they are tuned against these targets for a median build at each point:

| Target | Station 1 W1 | Station 1 W9 | Station 3 W9 |
|---|---|---|---|
| Swarm TTK (single target, primary weapon) | 0.4 s | 0.5 s | 0.6 s |
| Elite TTK | 3 s | 3.5 s | 4 s |
| Miniboss TTK | — | 40 s | 45 s |
| Breaker TTK | 90–150 s at station end | | |

Flat TTK across a cycle is the contract: power growth should roughly match enemy scaling, with the felt escalation coming from **density**, not bullet-sponge enemies.

### 8.4 Spawn budget

- Each enemy type has a **cost** (swarm 1, elite 9 [NINE]).
- **Budget per second:** `B = B0 × (1 + 0.15 × w) × P_s × (1.09 ^ returns_this_station)`, with **B0 = 2.0**, **P = 1.0 / 1.6 / 2.2** by station.
- Spawns occur on a ring 18–26 m from Taln, outside camera frustum where possible, never inside walls or hazards.
- **Alive cap:** 400 swarm-tier (prototype target); stretch 800 (§12). When at cap, budget accumulates up to 5 s of spending, then is discarded.

---

## 9. Meta-Progression hooks (provisional — Phase 4 owns the final curve)

- **Banked Agony** is the only meta currency [DD].
- **Cap raise cost:** raising a skill's cap from c to c + 1 costs **c − 1 points**. Standard skill 3 → 9: 2 + 3 + 4 + 5 + 6 + 7 = **27 points** [NINE]. Heraldic skill 2 → 9: 28.
- **Expected banking:** 0–9 per cycle; median ~5 (players will Welcome some fills).
- **Open for Phase 4:** total time-to-full-caps target (depends on pool size); whether unlocking new skills into the pool costs Agony; Special Room variant unlock costs.

---

## 10. Nine-centricity ledger

Narrative Bible decision 4 says to carry nine wherever the spec can hold it. Carried here:

| Place | Status |
|---|---|
| Nine stations; nine breakers | Strong — structural |
| Agony meter in ninths; catalyst costs in ninths | Strong — core math |
| Nine Returns close a cycle | Strong — defines the run end |
| Nine Special Rooms per cycle (3 × 3) | Strong — falls out of structure |
| Skill cap max 9; 27-point cap cost | Medium |
| Nine waves per station | **Weak — first to drop** if pacing tuning fights it |
| Nine skill slots | **Weak — second to drop** if the small pool makes nine feel empty |
| 9% level heal, 9% Return pressure, 9 m shockwave, 9 elite cost, ≥9 enemies for Pressed | Cosmetic — tune freely |

The player should notice the counting eventually; the spec should never force a bad number to preserve it.

---

## 11. Technical Architecture

### 11.1 Engine and language [PROPOSED]

> **v1.4:** the flow field becomes a window that follows Taln, and the swarm's target becomes a known position. See §15 v1.4 #5–6.

- **Godot 4.7.x** (current stable at time of writing: 4.7.2). Pin the exact version in the repo; upgrade only between milestones.
- **Renderer:** Forward+ (clustered lighting; required by the light budget in §12).
- **GDScript** for everything whose design is still moving: game flow, run/station state, Agony and Investiture logic, Welcome/Catalyze state machine, skills, minibosses, breakers, UI.
- **C++ via GDExtension (godot-cpp)** for things whose design is settled and whose cost scales with entity count:
  1. **SwarmServer** — swarm and elite simulation as data (struct-of-arrays), not nodes: steering, separation, spatial hash, flow-field following, contact-damage queries, death events, mote spawning.
  2. **Projectile/hit resolution** — weapon projectiles and area queries against the SwarmServer spatial hash.
  3. **Flow field** — per-station navigation field toward Taln, rebuilt locally when Cohesion edits terrain.
  4. Later, if profiling demands: Cohesion terrain edits (heightfield modification + collision rebuild).
- **Rule:** nothing goes to C++ until its GDScript interface exists and is stable, except SwarmServer, which is known from day one to need it. C++ is for throughput, not for design iteration.

### 11.2 Why this boundary changes system design (why this section belongs here)

Because swarm enemies are **rows in arrays, not scene nodes**:
- Swarm enemies cannot have per-instance scripts. Behavior is parameterized: a swarm type is a data record (speed, HP, Mass, steering weights, contact damage, family, behavior enum).
- Swarm rendering is **MultiMeshInstance3D with vertex-shader animation** (matches Art Direction technical constraints: instanced, shared material, shader animation).
- Swarm collision with Taln and projectiles is **distance queries in the spatial hash**, not physics bodies.
- Anything with bespoke behavior (minibosses, breakers, Notice hunters if they get unique AI) is a normal scene with GDScript and physics.

### 11.3 Signals and API between layers

SwarmServer exposes a narrow API to GDScript: `spawn(type_id, position)`, `apply_damage_in_radius(...)`, `apply_damage_in_cone(...)`, `query_count_in_radius(...)`, `apply_impulse_in_radius(...)`, plus signals `enemy_died(type_id, position)` and `taln_contacted(damage, type)`. Everything else (Agony, Investiture, loot) reacts to those signals in GDScript.

### 11.4 Data records systems depend on

Authored as Godot `Resource` files (`.tres`). The Content Pipeline doc owns the full format; these fields are required by systems in this spec:

- **Skill:** `id`, `kind` (Weapon/Surge/Perk), `tree` (Stoneward/Herald/Ashynite), `tags[]`, `investiture_cost` (Surges), `routing` (Toa'uma / Blade-eligible / Voidlight-only), `level_params[1..9]`, `catalyst_tier` (none/Lesser/Greater/Grand).
- **Modifier:** `id`, `target_tags[]`, `effects[]`, `catalyst_tier`.
- **Swarm type:** `id`, `family` (one of nine), `hp`, `contact_damage`, `speed`, `mass`, `resist{Kinetic,Void,Blight}`, `spawn_cost`, `behavior`.

### 11.5 Persistence

Meta state (banked points, per-skill caps, unlocks, lore flags) saved to `user://` as versioned JSON with a schema version field. Each cycle has a **seed** that drives station selection, Special Room draws and side-effect rolls, logged for bug reports.

---

## 12. Performance and Light Budgets

Target hardware (provisional): mid-range desktop GPU (GTX 1660 / RX 6600 class), 60 fps at 1080p.

| Budget | Value |
|---|---|
| Swarm-tier alive | 400 at 60 fps (prototype gate); 800 stretch |
| Physics tick | 60 Hz; SwarmServer steps at 30 Hz with render interpolation |
| Dynamic lights, non-shadow (OmniLight3D/SpotLight3D) | ≤ 32 visible |
| Shadow-casting lights | ≤ 2 (Taln's own light; one breaker/hazard source) |
| Swarm enemies as lights | **Never.** Enemy eyes and Voidlight are emissive + glow post-process only |
| Well pools / Taln cracks / gem / Honorblade | One light each, counted against the 32 |
| Decals (telegraphs, stains) | ≤ 64 visible |
| Draw calls | Swarm: one MultiMesh per swarm type visible |

No directional light exists in any scene (Art Direction v1.1).

---

## 13. Prototype Build Order (Phase 2 features against this spec)

> **v1.4:** steps 1–7 are done (P2-01 to P2-08). The playstyle graybox order is in §15 v1.4 #9.

1. **Gray-box arena:** one flat-plus-ramps station, heightfield ground, three Well pools. Camera and controller (§7), Anchored and Fracture (§6.3–6.4), Shoulder (§6.5).
2. **SwarmServer v0 (C++):** one swarm type, seek + separation, spatial hash, MultiMesh rendering, contact damage (§6.2), alive cap (§8.4).
3. **One Weapon + one Stoneward Surge** routed through Toa'uma with Strain (§5). Suggested prototype Surge: a Cohesion ground-cone that roots swarm for 2 s and deals Kinetic damage — tests "control the ground under the swarm" without terrain deformation.
4. **Investiture loop:** motes, pickup, ambient Well, pools, Invest/level-up with C(n) (§2).
5. **Agony meter + Welcome prompt** with a stub catalyst (Lesser) that only flashes the screen (§3–4).
6. **Return** sequence and ninth-Return close (§6.6, §1.3).
7. **Telemetry:** kill rate/min, Investiture income by source, level-up times, Agony fills and choices, Returns, Strain curve. The go/no-go gate is judged partly on these numbers.

---

## 14. Decisions Log

All twelve approved 2026-09-25 as recommended.

| # | Decision | Ruling | Where |
|---|---|---|---|
| 1 | Cycle structure | 3 of 9 stations per cycle, one per tier | §1.1 |
| 2 | Cycle end | Held or Closed (ninth Return); no fail state, no win/lose framing | §1.3 |
| 3 | Leveling trigger | Player-triggered (Invest), not automatic | §2.4 |
| 4 | Skill slots | Nine, no per-tree limit; revisit when pool size is known | §2.5 |
| 5 | Welcome/Catalyze timing | 0.1× time dilation; full-pause accessibility option | §3.4 |
| 6 | Unspent ninths on Catalyze | Discarded | §3.4 |
| 7 | Catalysis unlock | On first banked Agony point | §4.2 |
| 8 | Honorblade routing | Removes Strain from Cohesion/Tension Surges; Voidlight skills always route through Toa'uma | §5.1 |
| 9 | Mobility | No jump; Shoulder is base mobility. v1.4: stands; air time comes only from the ground (Design Doc v2.0 Pillar 2) | §6.5 |
| 10 | Stance rhythm | Anchored bonus + Fracture punishment | §6.3–6.4 |
| 11 | Heraldic cost-reduction skill name | "Bearer of Agonies" as working name; final name open for Content List | §4.4 |
| 12 | Tech stack | Godot 4.7.x, Forward+, GDScript + C++ (GDExtension) boundary as specified | §11 |

---

## 15. Revisions

### v1.1 — 2026-09-26 (from the P2-01 gray-box playtest)

| # | Change | Where | Why |
|---|---|---|---|
| 1 | Shoulder no longer stops at every edge: off a drop it carries on through the air; over a gap wider than 1 m it ends just past the edge and Taln falls in. Gaps up to 1 m are still crossed | §6.5 | Taln should use the environment to fling himself around |
| 2 | Shoulder stops only at walls hit within 60° of head-on (`shoulder_wall_stop_angle_deg`); shallower hits slide along the wall | §6.5 | A little sliding reads better than dead stops on glancing contact |
| 3 | Clarified: the charge stops dead when it ends. Momentum carry is an upgrade surface, not base behavior | §6.5 | Movement feel is meant to be a build-defining axis |
| 4 | Anchored also ends on a Shoulder charge; its 0.6 s timer restarts when the charge ends | §6.3 | Came from the P2-01 handoff; accepted in playtest |
| 5 | Clarified: Fracture damage lands in once-per-second pulses (3% at 9 s, then +1% each pulse) rather than continuously. Base behavior; expected to be modified by upgrades | §6.4 | Keeps damage events and Health signals readable |

### v1.2 — 2026-09-26 (P2-03 step 0)

| # | Change | Where | Why |
|---|---|---|---|
| 1 | Surge aiming is unified for both inputs: camera-forward on the ground plane with a 30° soft-lock cone toward the densest cluster in range. A ground reticle shows the Surge's area while it's ready | §7.3 | The camera captures the mouse (P2-01), so there's no cursor ground-point to aim at |
| 2 | Draw can't Misfire or Echo; those results are rerolled. An Overcharged Draw grants double Investiture | §5.3 | Those side effects only make sense for Surges |
| 3 | Notice pack sizes are placeholders: 3 hunters at Strain 3, 5 at Strain 6, 9 at Strain 9. The Enemy Design doc replaces them | §5.3 | Notice needs a pack size to spawn before the Enemy Design doc exists |
| 4 | Clarified: Misfire turns the Surge within ±45° of its aim, a 90° cone | §5.3 | "Within 90° of aim" could be read as ±90° |
| 5 | Hunters from the Strain 3 and 6 Notices die after 30 s if not killed (not a kill: no kill rewards). Strain 9 hunters still persist until killed | §5.3 | The spec said only Strain 9 hunters persist, without saying when the others go. 30 s is about 6 s to close from 26 m plus ~24 s of hunting, and shorter than a wave, so packs rarely stack |

### v1.3 — 2026-09-26 (P2-04 to P2-08)

Rows marked **(ruled)** restate design rulings given in the P2-04–P2-08 handoff; the rest are clarifications made while building.

| # | Change | Where | Why |
|---|---|---|---|
| 1 | **(ruled)** Flow field: a Dijkstra field over the station ground's cells toward Taln's cell, 8 neighbors, no diagonal corner-cutting past closed cells. Rebuilds when Taln changes cell, at most 10 Hz (`flow_rebuild_interval`), and on every ground change. Enemies follow it; within 3 m of Taln (`flow_direct_range`), or with a clear grid line of sight to his cell, they seek directly; where his cell can't be reached they seek directly. Notice hunters follow it too; rooted enemies ignore it | §11.1 | The spec named the field but not its rules; the P2-04 handoff set them |
| 2 | Clarified: "rebuilt locally when Cohesion edits terrain" is met by a full rebuild on every ground change. A full 128×128 rebuild costs ~0.6 ms in the unoptimized dev build; a Dijkstra field can't be patched locally anyway, since one edit can change distances anywhere. Rebuilds run on a physics tick with no simulation step, so the two costs never share a tick | §11.1 | The handoff's full rebuild and the spec's "locally" read as a conflict; they aren't, once "locally" means in place at runtime |
| 3 | Clarified: the 3 m direct-seek range is measured along the field (path distance), not in a straight line. A closed cell Taln stands on still seeds the field | §11.1 | Straight-line, an enemy at the foot of a cliff Taln stands on is "within 3 m" and would seek into the cliff; along the field it walks to a ramp. Path distance is never shorter than straight-line, so this only removes direct seeks that can't work |
| 4 | **(ruled)** A station context holds `station_index`; v = 1 / 2 / 3 by index (tuning). Every §2.3 income source is multiplied by v, **including Draw** (the table's ×v applies to it). The debug grant isn't | §2.2, §2.3 | Handoff P2-05 |
| 5 | **(ruled)** `enemy_died` gains a third argument, `rewarded`. Deaths that aren't kills (a Notice hunter's time running out; later the Return shockwave) are `rewarded = false`: they drop nothing and don't count as kills. The swarm type record gains `investiture_drop` (swarm 1, Notice hunter 9, one large mote) and a `tier` (Swarm / Elite) so elite motes count as elite income | §11.3, §11.4, §2.3 | Handoff P2-05; `tier` so income by source can tell §2.3's swarm and elite kills apart |
| 6 | Clarified motes: they live in C++ (MoteServer, beside SwarmServer, per §11.1). Pickup is measured from a point 1 m above Taln's feet to the mote, which hovers 0.35 m up; a mote that has started flying keeps flying until collected, even if Taln moves out of range; one left 30 s sinks and fades over 1 s and can't be collected while sinking. v is applied when a mote is collected | §2.3, §11.1 | "Fly to Taln once inside" needed a rule for Taln leaving the radius; heights were unstated |
| 7 | Clarified: the ambient Well pays only while the spawner is running a wave (not while it's paused, and not in the between-station lull; §2.3 names waves and overstay only) | §2.3 | The P2-07 stand-in cycle adds a lull the spec's table doesn't mention |
| 8 | **(ruled)** Pools: 3 active; 4/s while Anchored inside, 1/s inside otherwise; each holds 90; the disc shrinks and dims as it drains; a drained pool reappears 20 s later at a random spot whose 3 m disc is fully unblocked, ≥ 12 m from Taln and ≥ 15 m from the other pools. Clarified: capacity counts base Investiture, so a pool pays 90 × v and lasts 22.5 s Anchored at any station; the disc's cells must also sit within 0.2 m of each other (a pool is flat); the 3 m trigger stays full size while the disc shrinks | §2.3 | Handoff P2-05; capacity in paid units would drain three times faster in station 3 |
| 9 | **(ruled)** Leveling: Invest is Tab / gamepad Back; with C(n) held the game pauses fully and offers up to 3 owned skills below cap, drawn without replacement with weight 1 / current level; pick with 1–3, a click, or D-pad and A; a pick spends C(n), advances n, levels the skill and heals 9%; with every owned skill capped the only option is Consolidate (C(n), n + 1, heal 25%). Clarified: Invest again closes the menu without spending; picks in the first 0.2 s (real time) are ignored so a key held from play can't pick; A confirms through Godot's built-in `ui_accept` in paused menus only, so the game's action table still leaves A unbound | §2.4 | Handoff P2-05; the spec didn't say whether the menu can be backed out of |
| 10 | **(ruled)** A cycle starts with 0 Investiture (`debug_start_investiture` = 0); Ctrl+4 still grants 100 | §2.1, §2.4 | Handoff P2-05 |
| 11 | **(ruled)** Breaking Stroke and Settle are defined to level 9 by continuing each parameter's L2→L3 step, as placeholders: Stroke's interval floors at 0.5 s, Settle's cone caps at 120°. A cap beyond a skill's defined levels clamps to them with a warning | §2.5 | Handoff P2-05; caps can reach 9, the P2-03 tables stopped at 3 |
| 12 | **(ruled)** Meta state is an autoload persisted to `user://meta.json` with `schema_version: 1`: per-skill caps (starting 3; Bearer of Agonies 2), banked Agony, `catalysis_unlocked`, `return_seen`; saved on every change. Clarified: it also keeps `banked_total` (every point ever banked) for the between-run screen's "in total" | §9, §11.5 | Handoff P2-05 |
| 13 | **(ruled)** Voidlight Burn ignores invulnerability (`Health.damage(..., ignore_invulnerability)`) | §5.3, §6.2 | A Shoulder or post-hit invulnerability window could otherwise cancel Burn's cost |
| 14 | Clarified Agony gain: the damage gain counts every source after mitigation (Burn and Fracture included), and only the Health actually lost (a killing blow's overkill doesn't count); gain is suspended during Special Rooms (none exist yet), the Invest pause, the Welcome/Catalyze windows and the Return sequence; the breaker gain is a hook until breakers exist | §3.2 | The spec's list named Special Rooms, the Invest pause and the Return; the windows follow from §3.3's lock |
| 15 | **(ruled)** Bearer of Agonies: Herald Perk, innate (no slot), level 1 each cycle, cap from meta state (starting 2), offered at Invest like any skill; its §4.4 cost table lives in its `.tres` | §4.4, §2.5 | Handoff P2-06 |
| 16 | **(ruled)** Placeholder Cataclysms, magnitudes in the skills' `.tres`: Settle (Lesser) 360° within 9 m, 40 Kinetic, root 3 s; Breaking Stroke (Greater) within 9 m, 80 Kinetic, knockback force 12. Pulled forward from §13 step 5's flash-only stub so the gate can judge the Welcome/Bank choice (roadmap). Their visuals fade within 0.6 s so they never hide telegraphs for more than a moment | §4, §13 | Handoff P2-06; Art Direction VFX rule |
| 17 | **(ruled)** Welcome/Catalyze: 0.1× time with windows in real time (prompt 6 s, Catalyze 9 s), or a full pause with `catalyze_full_pause` (off by default); the mouse is free during both; Welcome = 1 / pad A / click, Bank = 2 / pad B / click, timeout banks; commit by holding the mouse on a catalyst's icon for 0.6 s real time, or D-pad focus and hold A; Release = R / pad Y / click; Catalyze also fires by itself when nothing uncommitted still fits the budget | §3.4 | Handoff P2-06 |
| 18 | Decided on ambiguity, **for confirmation at the Phase 2 gate**: a Catalyze window that runs out with something committed fires it (the spec covers only running out with nothing committed, which banks). During both windows Taln can still walk but can't Shoulder, cast or Draw, and Invest is shut. An A press that Welcomed doesn't also commit: A has to come up first. "Real time" is unscaled frame time, so headless runs behave like played ones | §3.4 | Committing is a clear intent to fire; walking keeps agency in the slow-down while the choice keys stay unambiguous (pad B is also Shoulder, clicks also cast) |
| 19 | **(ruled)** Phase 2 stand-in cycle: three consecutive nine-wave stations on the gray-box map; `station_index` advances 0 → 1 → 2, taking v, S, D and P with it; between stations a 15 s lull with the spawner at 15% of the wave-9 budget; after station 3's ninth wave the cycle ends Held. **Replaced when real stations, Special Rooms and breakers exist** | §1.1–1.3 | Handoff P2-07: the gate needs the whole loop before those exist |
| 20 | **(ruled)** A CycleDirector (autoload) owns the cycle's seed, logs it, and seeds every random stream in the station from it (spawner, swarm, Toa'uma, motes, pools, leveling); it counts Returns (0–9) and the cycle's stats, and a cycle starts with every in-run value reset (Investiture 0, skills level 1, n = 0, Strain 0 with Notices re-armed, Agony 0, Returns 0, wave 0, station 0, Fracture cleared) | §1.3, §11.5 | Handoff P2-07 |
| 21 | **(ruled)** The Return replaces the P2-01 Health refill. It lasts 4.5 s the first time ever (`return_seen`); after that any press skips it once 1.5 s have passed. During it the swarm is frozen (no movement or contact damage; it still draws), and so are the spawner, Agony, Investiture income, motes, the Well and Fracture. On reform: full Health; `kill_in_radius` kills swarm-tier enemies (mass ≤ 1) within 9 m, unrewarded, and the heavier ones take knockback force 12; +300 Agony (a fill opens the prompt once control is back); Braize takes a third of held Investiture; `returns_this_station` rises (spawn pressure); Taln reforms in place, or at the nearest open cell if his cell is closed or off the ground. The ninth Return has no reform: the cycle ends Closed | §6.6, §1.3 | Handoff P2-07; "nearest safe navmesh point" is the nearest open ground cell here |
| 22 | Decided on ambiguity, **for confirmation at the Phase 2 gate**: during the Return Taln is invulnerable and can't move or act (his skills stop); the world stops at once rather than first slowing (the handoff also asks for it frozen, and §6.6 says enemies don't act); a Welcome or Catalyze window open when he dies banks the point, even with catalysts committed; a killing blow that fills the meter holds its prompt until he reforms; he reforms with a fresh Fracture timer. Placeholder beat: the body sinks into ash-dark, the screen drains to black and lifts as he reassembles | §6.6 | "Time slows" (Art Direction) and "frozen" (handoff) pull opposite ways; firing Cataclysms from a corpse, or reforming into an escalated Fracture, would read wrong |
| 23 | **(ruled)** The between-run screen states Held or Closed plainly, the cycle's time, kills, Returns, fills Welcomed vs Banked, and Agony banked this cycle and in total; banked Agony raises caps there at c − 1 points per step for Breaking Stroke, Settle and Bearer of Agonies; "Begin the next cycle" loads the station again with a new seed. Placeholder dark panel, framed later as Taln's memory | §1.3, §9 | Handoff P2-07 |
| 24 | **(ruled)** Telemetry: a TelemetryRecorder (autoload) writes each cycle as JSON Lines to `user://telemetry/cycle_<timestamp>_<seed>.jsonl`: kills (with `rewarded`), Investiture income by source and spends, level-ups (time, n, choice), Agony fills (choice, committed catalysts), Returns, Strain changes, Notices, side effects, wave and station changes; a snapshot every 10 s (alive, kill rate, held Investiture, Health, Agony, Strain) and a summary line at cycle end. `tools/telemetry_report.gd` prints kill rate per wave, income by source per station, the level-up timeline beside the C(n) prediction, fills per station and the choice split, Returns and the Strain curve | §13 step 7 | Handoff P2-08 |
| 25 | Telemetry details. Clarified: every line carries `t`, seconds of game time into the cycle (pauses excluded); income is summed per second by source and stamped with its station (flushed at every wave, lull and station change) rather than logged per mote or per frame; Strain is logged when it changes; a Return logs its reform; a fill logs what was committed as well as what fired; a cycle freed before its end gets an `abandoned` line; check scripts record nothing unless a check turns it on. Report: kill rates are per minute of running waves (Return freezes and lulls left out); station averages are over the cycles that reached that station. Decided on ambiguity, **for confirmation at the Phase 2 gate**: the "C(n) prediction" anchors each station at its logged start and spreads §2.4's net leveling income for that station evenly over its nine waves, spending it on C(0), C(1), … in turn; that net includes miniboss and breaker income the stand-in doesn't have, so the prediction runs early | §13 step 7 | Per-frame income (ambient, pools) would swamp the file; the spec gives a pacing table, not a timeline |

### v1.4 — 2026-10-17 (Phase 2 gate playtest → Design Doc v2.0 draft)

Rows marked **(ruled)** restate the project owner's rulings of 2026-10-17 (Design Doc v2.0). The rest are proposals for the playstyle grayboxes to test. Their numbers are set in the milestone that builds them and logged as later revisions. Nothing here changes built behavior until that milestone lands.

| # | Change | Where | Why |
|---|---|---|---|
| 1 | **(ruled)** **Aspects.** Chosen between cycles. An Aspect sets the starting Weapon and Surge and grants an Aspect passive that takes no slot. In-run picks can drift a run toward hybrids. Four Aspects: Earthshaper, Meteor, Doomhunter, Plaguebringer | §2.5 | Design Doc v2.0 §10: the gate loop is one playstyle, not the base loop |
| 2 | **(ruled)** Anchored (§6.3: its Armor bonus, knockback immunity and the 4/s Anchored pool rate) and Fracture (§6.4) move behind the **Earthshaper** Aspect. Without it, Taln never Anchors or Fractures, and Well pools pay the unanchored 1/s. Pools stay as map features for every Aspect | §6.3, §6.4, §2.3 | Plant / hold / relocate is Earthshaper's loop. Fracture would tax stealth waiting (Plaguebringer) and constant motion (Meteor) for no reason |
| 3 | **(ruled)** Decision 9 stands: base Taln has no jump. Air time comes only from the ground: launch terrain (catapults, Tension-stiffened ramps), Cohesion pillars, and Shoulder off a drop (already built, v1.1 #1). Landing damage scaled by fall speed and height belongs to the Meteor Aspect; its numbers are set in P2-12 | §6.5 | Design Doc v2.0 Pillar 2, "the ground is the weapon" |
| 4 | **(ruled)** **One persistent map.** The nine stations are the nine regions of one hand-built, interconnected Braize, grouped into three tiers by depth, the same every cycle. Routes between regions pass **gates** that open through meta-progression. [PROPOSED] A cycle drops Taln at a Tier I entry and crosses **one region per tier**, chosen by route (still three of nine, still nine Special Rooms). v = 1 / 2 / 3 and S, D, P follow the region's tier. Inside a region, a **difficulty clock** replaces the nine timed waves: it advances w one step per wave length (45 s), so §8.2 and §8.4 carry over unchanged. Special Rooms are placed in the region. The breaker is found and player-triggered, and its fall opens the routes onward. Held = the Tier III breaker falls and Taln leaves; Closed is unchanged. Staying past a breaker is overstay (§1.2). Region size, gate rules and session fit are open until P2-10 | §1.1–1.3, §10 | Design Doc v2.0 §4–5. Nine waves were already first to drop (§10); the clock keeps the scaling math |
| 5 | [PROPOSED] **Windowed flow field.** The field covers a window of cells (start: 128 × 128, today's whole station) that recenters on Taln when he comes within a margin of its edge. A recenter is a full rebuild, as in v1.3 #2. Spawns stay inside the window. A swarm enemy outside it seeks directly, and one beyond a despawn distance is removed unrewarded | §11.1, §8.4 | A 512 m map has ~16× the cells of today's 0.6 ms field, and the swarm only ever lives near Taln (spawn ring 18–26 m) |
| 6 | [PROPOSED] **Awareness.** SwarmServer's flow target becomes a **known position** set from GDScript instead of Taln's node. An Awareness system (GDScript) updates it from sightings (spotters with line of sight to Taln) and noise (Toa'uma use, kills, landings), and lets it go stale when nothing reports. Until P2-13 lands, the known position is Taln's every tick, so behavior is unchanged | §11.3, §5.3 | Doomhunter's stealth approach and Plaguebringer need enemies that can lose Taln. Toa'uma's Notice already models "drawing attention" |
| 7 | [PROPOSED] **Commanders.** A swarm-type flag for elites and minibosses that buff swarm within an aura (speed, damage, resist; numbers in P2-13) and act as spotters for Awareness (#6) | §8.1, §11.4 | Design Doc v2.0 §10, Doomhunter |
| 8 | **(ruled)** The **Ashynite disease core** is in scope: Blight damage (§6.2, reserved until now), seeding, spread by swarm density, and infected enemies that are buffed until the disease takes them. The rest of the Ashynite tree stays backlogged. [PROPOSED] Spread runs in SwarmServer over its spatial hash, as per-enemy infection data. Plaguebringer's full-map play presses on the 400 alive cap, so §12's 800 stretch becomes a P2-15 target | §0, §6.2, §11.1, §12 | Design Doc v2.0 §9, §10 |
| 9 | [PROPOSED] **Graybox build order** (replaces §13 for Phase 2): P2-10 shared base slice (2–3 regions, one gate stub, windowed field, difficulty clock, Aspect scaffold, Anchored/Fracture behind an Aspect flag) → P2-11 Earthshaper → P2-12 Meteor → P2-13 Awareness + commanders (shared) → P2-14 Doomhunter → P2-15 Ashynite disease core + Plaguebringer → P2-16 boons. Each playstyle is built on its own branch off the shared base and kept, reworked or cut on its own playtest | §13 | Roadmap Phase 2 rows |
| 10 | **(ruled)** **Boons** are Sja-Anat's residue, not contact (Narrative Bible §4.5): offers of **one of three**, each tagged with its source (Toa'uma or the culture), given in Special Rooms and after some encounters. [PROPOSED] A boon takes no skill slot and ends with the cycle. Whether boons level is open until P2-16 | §2.5 | Design Doc v2.0 §11 |
| 11 | [PROPOSED] **New records.** `AspectDef`: `id`, `starting_weapon`, `starting_surge`, `passive`, `flags` (e.g. `anchored`, `fracture`), `tags[]`. `BoonDef`: `id`, `source` (Toa'uma / culture), `tags[]`, `effects[]`, `bane` (culture boons). `Region`: `id`, `tier`, `station_value`, `gates[]`. `Gate`: `id`, `kind`, `unlock` (meta condition), `links` (two regions). The swarm type gains `commander` (aura radius, buff, spotter). Meta state gains `opened_gates[]` and `aspects_unlocked[]` | §11.4, §11.5 | The fields the systems in #1–#10 depend on |
| 12 | Clarified: `StationGround` keeps one walkable surface per cell (the top one). Graybox regions stay within that: ledges, drops and ramps, no paths under paths. True multi-level ground is an open question (Design Doc v2.0 §8) | §11.1 | Persistent-map verticality would otherwise outrun the ground model silently |
| 13 | Editorial: removed a duplicated, headerless copy of the decisions table that followed §14 | §14 | Stray paste from v1.0 |

### v1.5 — 2026-10-17 (P2-10, the Braize slice)

Rows marked **(ruled)** restate the project owner's P2-10 rulings; the rest are clarifications made while building.

| # | Change | Where | Why |
|---|---|---|---|
| 1 | **(ruled)** **Breaker stand-in: a siege at the site.** Each region's breaker site is a tall beacon (emissive and unfogged, no light) with a 4.5 m trigger ring. Walking in starts a 60 s siege at 2× spawn budget, with a 9-hunter Notice-type pack that expires after 90 s if not killed. Breaker Agony gain (§3.2) runs during the siege. When the siege ends the breaker falls: 270 × v breaker income (§2.3), auto-collected, logged as source `breaker`. The siege clock holds while the Return freezes the world. Numbers in `region_tuning.tres`. **Replaced when real breakers exist** | §1.2, §2.3, §3.2 | No breakers exist yet. The cycle needs one per region to pace the tiers |
| 2 | **(ruled)** **Exits are sealed until the region's breaker falls.** Seals are barriers in the ridges' passages; the swarm treats them as walls. When the breaker falls they drop and the ground under them is resampled. The gated route needs both its seal and its gate open | §1.2 (v1.4 #4) | Keeps tier pacing: no walking past a breaker |
| 3 | **(ruled)** **The gate opens with banked Agony** on the between-run screen (stub cost 3 points, competing with cap raises) and stays open every later cycle. MetaState gains `aspect` and `opened_gates`. They're optional keys, so `schema_version` stays 1 and older files still load | §9, §11.5 (v1.4 #11) | Design Doc v2.0 §8 left the gate condition open. This is the stub to play against |
| 4 | **(ruled)** **Aspects in the slice: Earthshaper and Unaspected.** Both start with Breaking Stroke and Settle. Earthshaper has Anchored and Fracture; Unaspected has neither. The between-run screen picks the next cycle's Aspect (default Earthshaper). Starting skills move from `loadout_tuning` to the Aspect | §2.5 (v1.4 #1–2) | Lets the shared spine be played on the big map without Earthshaper's rhythm, and proves the pick works. P2-11 builds the real Earthshaper |
| 5 | Clarified: the flow window is 128 × 128 cells, recentering when Taln is within 24 cells of an inner edge. It's clamped onto the ground, so at the ground's edge it doesn't move. A recenter rebuilds on a tick with no simulation step, like any rebuild. On a ground no larger than the window (the 128 m gray-box station) the window is the whole ground, as before. Swarm-tier enemies beyond 70 m (XZ) of Taln are removed unrewarded; elites never are | §11.1 (v1.4 #5) | The numbers v1.4 left open. A full rebuild of the window costs ~0.4 ms in the dev build |
| 6 | Clarified: **the slice's layout.** 256 m, three regions stacked by depth: The Shelf (Tier I, the entry, south), Ninefold Descent (II) and Where He Kept the Count (III, north). They're split by 4 m ridges with 8 m passages: one from I to II; from II to III, an open route far west and a gated shortcut by the Tier II site (~115 m against ~300 m from the Tier II site to the Tier III site). The ground model's one-surface-per-cell rule (v1.4 #12) holds: plateaus, ledges, ramps and walls only. Generated by `tools/build_braize_slice.gd` | §1.1 (v1.4 #4) | "2–3 connected regions with one gate" needed a concrete shape |
| 7 | Clarified: **region flow.** A region's tier sets the station index (v, S, D, P). The clock (w) restarts at 0 on entering a deeper region and rises with no last wave (overstay slopes, §8.2). Walking back into a shallower region keeps the deeper tier. After a breaker falls the spawner runs a lull (15% budget at the current w) until Taln enters the next tier. Spawns and new Well-pool spots stay inside the region Taln stands in, and pools within 60 m of him (`max_distance_taln`). On entering a region every pool moves into it, refilled. The Tier III breaker falling ends the cycle Held at once (the stand-in has no "leaves") | §1.2, §2.3, §8.4 (v1.4 #4) | A big map needs spawns and pools to follow Taln. The seals already keep him in the region |
| 8 | Clarified: cycles load the slice (`cycle_tuning.station_scene`), and it's the main scene. The 128 m gray-box station stays for the P2-01 to P2-08 checks and the economy bot, unchanged | §13 | Keeps the earlier checks and the bot's baselines valid |
| 9 | Clarified: telemetry logs `region` (entered), `siege` and `breaker_fell` events with the region's id and tier, and the cycle header names the `map`. The report prints each region's entry, siege and breaker times | §13 step 7 | The slice's gate question is about roaming. Time to find the breaker is its first number |
| 10 | **(ruled)** **Breaker drop (encounter-drop kit, pulled forward).** A felled breaker short of the last tier offers up to 3 skills, drawn without replacement (cycle-seeded) from a placeholder pool, leaving out skills Taln owns. Taln takes one, at level 1. It opens in a full-pause menu like Invest, once play allows (not under a Welcome or Catalyze window, the Return or the Invest menu). There's no declining, and nothing is offered once every slot is taken. Logged as `kit_offer` and `kit_take`. Pulled forward from Phase 3 Special Rooms so the slice has in-run kit growth; **replaced by Special Rooms and boons** | §2.4, §2.5, Design Doc §5 | Playtest: with only the starting two skills capped at 3, a run had no progression. §2.4 already names encounter drops as a kit source |
| 11 | **(ruled)** **Placeholder kit pool** (Stoneward unless noted, levels 1–9, every number a stand-in until the Content List). **Shardfall** (Weapon): strikes the nearest enemy within 12 m, burst 1.5 m, 20 Kinetic every 1.2 s. **Tremor** (Weapon): pulses 12 Kinetic within 4.5 m of Taln every 1.6 s while an enemy is in range. **Upheave** (Surge, Blade-eligible, 30 Investiture, 6 s): 30 Kinetic within 3.5 m of a point 6 m along the aim, knockback force 14. **Stone Skin** (Perk): +10 Armor. **Second Wind** (Perk, Herald): 0.5 Health/s. None are catalysts. Their caps can be raised on the between-run screen | §2.5, §6.1 | Two Weapons, a Surge and two Perks give each drop a real choice of kind |

### v1.6 — 2026-10-17 (P2-12, the Meteor graybox)

Rows marked **(ruled)** restate the project owner's P2-12 rulings; the rest are clarifications made while building. P2-12 was built before P2-11 at the owner's call.

| # | Change | Where | Why |
|---|---|---|---|
| 1 | **(ruled)** **Meteor Aspect.** Starts with **Impact** (Weapon) and **Heave** (Surge), with no Breaking Stroke: landings are the main damage, so Meteor has to keep launching. No Anchored or Fracture. The between-run screen lists Earthshaper, Meteor and Unaspected, and can raise Impact's and Heave's caps | §2.5 (v1.4 #1) | Design Doc v2.0 §10: "crash through it" |
| 2 | **(ruled)** **Heave** (Stoneward, Cohesion, Blade-eligible): a pillar shoves up under Taln and throws him along the aim, soft-locked toward the densest cluster within its distance. **From the ground only**: refused while airborne, and an Echo that arrives mid-flight does nothing. The arc peaks `apex` up and lands `distance` out on level ground: 4.5 m / 9 m at level 1, rising to 6.5 m / 13 m at level 9. Overcharge multiplies the distance. Cooldown 1.6 s. Decided on ambiguity, **for confirmation**: **cost 0 Investiture**, because Meteor starts with no weapon and no Investiture, so a paid launch could leave it stuck. Placeholder numbers | §2.5, §5.1, §6.5 (v1.4 #3) | The ruled launch tool. "The ground launches you" |
| 3 | **(ruled)** **Impact** (Weapon): any landing at 6 m/s or faster deals Kinetic damage of 24 + 3 per m/s over 6, within 3 m + 0.2 m per m/s over 6 (capped at 7 m), knockback force 10. Level 1 numbers; damage +6 and +0.5 per m/s each level. It counts Heave landings, pad landings and ledge drops alike (a 3 m drop lands at ~11 m/s). Placeholder numbers | §2.5, §6.2 (v1.4 #3) | "Jumps and landings both deal major area damage." Making it a Weapon lets it level with Investiture like any skill |
| 4 | **(ruled)** **Air steering**: while launched, horizontal acceleration toward the input is 12 m/s² (30% of the ground's 40) with no braking. Horizontal speed can't exceed the launch's own or `move_speed`, whichever is higher. Shoulder still works in the air as before | §7.1 | "Some steering": a launch commits you, but you can adjust the landing |
| 5 | Clarified: Taln gains `launch(velocity)` and a `landed(fall_speed, at)` signal. He counts as airborne whenever he's off the ground, however he left it, and a landing reports his downward speed at touchdown. The Return clears the air state, so a reform never lands as an Impact | §7.1, §6.6 | The systems above need one landing event for every way of leaving the ground |
| 6 | Clarified: **swarm contact needs height**. Enemies push Taln and deal contact damage only within 1.6 m of his feet (`contact_height`, C++). A launched Taln passes over the swarm untouched, for every Aspect | §6.2, §11.3 | Contact was measured on XZ only, so flying over a crowd took its damage |
| 7 | Clarified: **launch pads**, the launch terrain of v1.4 #3. There are 8 in the slice, each landing inside its own region (onto plateaus and ledges, or across the region). Stepping onto one (1.5 m, on the ground, within 0.6 m of its height) throws Taln on a ballistic arc to its target, peaking at its set height. It rearms after 1 s. Pads throw every Aspect; only Impact turns the landing into damage. Numbers in `launch_tuning.tres`; targets and apexes are placed by the builder | §6.5 (v1.4 #3) | Ground-sourced air time that costs nothing and teaches routes |
| 8 | Clarified: the slice's **ridges, seals and gate are 12 m tall** (were 4 m), so no launch can clear them. The longest Heave (level 9, Overcharged) peaks at ~6.6 m | v1.5 #2, #6 | Launches would otherwise skip a breaker by flying over its seal |
| 9 | Clarified: the camera pulls out 3 m while Taln is airborne (3 m/s each way), and landings faster than 6 m/s add 0.03 trauma per m/s over that, for every Aspect. Numbers in `camera_tuning.tres` | §7.2 | "Camera at speed": the landing zone needs to stay in view, and a hard landing should be felt |
| 10 | Clarified: telemetry logs every `landing` (fall speed) and every `impact` (fall speed, hits), and the cycle summary carries `airtime`. The report prints air time as a share of play, landings, Impacts and hits per Impact | §13 step 7 | P2-12's gate question is whether traversal itself is the weapon |
| 11 | **(ruled)** **Aspect pick at launch.** When the slice is the session's first scene, its cycle waits, paused, on a start screen listing every Aspect (focus on the last chosen). Picking Taln's current Aspect begins the cycle at once. Picking another saves it and reloads the slice, because his kit comes from the Aspect. Later cycles in the session skip the screen; the between-run screen still changes the Aspect. Scenes that check and bot scripts add by hand never wait | §2.5 (v1.4 #1) | Playtest: reaching Meteor meant ending a cycle first |

---

*v1.0 approved 2026-09-25. Numeric values remain prototype starting points; the Phase 4 Balancing doc supersedes them. Copy into the repo as `docs/core-systems-spec.md` at scaffold time; after that, the repo copy is authoritative and changes are logged as revisions.*
