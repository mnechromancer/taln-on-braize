# Unbroken: Taln on Braize
### Core Systems Spec — v1.1 (Approved)

*Phase 2 deliverable. Parent documents: Design Doc v1.1 (governs mechanics intent), Narrative Bible v1.1 (governs fiction), Art Direction v1.1 (governs visuals). This document turns their intent into numbers, state machines and system boundaries that the prototype can be built against. Every number here is a **starting value for the prototype**, not a balance commitment; the Phase 4 Balancing doc supersedes them.*

*Tags: **[DD]** restates a Design Doc rule (do not change here) · **[PROPOSED]** originated in this spec (all approved in v1.0; see §14) · **[NINE]** a place where Braize's nine-centricity (Narrative Bible §3.3, decision 4) is carried structurally.*

---

## 0. Scope

**In scope:** run structure and pacing; Investiture economy and leveling curve; Agony meter, Welcome the Agony, catalyst costs and Catalyze flow; Toa'uma (peakspren) risk model; health, damage, mitigation and Return (death); movement, stance and camera values; enemy scaling and spawn budget; technical architecture boundaries (Godot / GDScript / C++); performance and light budgets.

**Out of scope (owned elsewhere):** individual skill/weapon/catalyst content and Cataclysm effects (Phase 4 Full Content List); final meta cap-raise curve (Phase 4 Meta-Progression Spec — §9 here is provisional); enemy roster and attack patterns (Phase 3 Enemy Design doc); data authoring format (Phase 3 Content Pipeline doc — §11.4 here defines only the fields systems depend on); Ashynite mechanics (Design Doc §9 backlog).

**Units:** distance in meters (1 Godot unit = 1 m), time in seconds, speeds in m/s, rates per second unless stated.

---

## 1. Run Structure and Pacing

### 1.1 Hierarchy [PROPOSED]

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
| Misfire | 2 | The Surge fires at a random direction within 90° of aim |
| Lurch | 2 | Local gravity spike: Taln and enemies within 6 m slowed 40% for 2 s |
| Echo | 1 | The Surge fires again 1.0 s later at no cost |
| Speaks | 2 | A Toa'uma line; no mechanical effect |

**Escalating risk** — carried by `p` rising with Strain.

**Drawing attention** — at Strain **3, 6 and 9**, a **Notice** event: an elite hunter pack (Enemy Design doc defines them) spawns on the arena edge and targets Taln directly. At Strain 9, the hunters persist until killed and Voidlight side-effect weights shift toward Burn and Misfire.

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
- **Surges:** aim at the mouse ground-point (KB+M). Gamepad: camera-forward projected on the ground with a **30° soft-lock cone** to the densest cluster within the Surge's range.

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
| 9 | Mobility | No jump; Shoulder is base mobility | §6.5 |
| 10 | Stance rhythm | Anchored bonus + Fracture punishment | §6.3–6.4 |
| 11 | Heraldic cost-reduction skill name | "Bearer of Agonies" as working name; final name open for Content List | §4.4 |
| 12 | Tech stack | Godot 4.7.x, Forward+, GDScript + C++ (GDExtension) boundary as specified | §11 |

---|---|---|
| 1 | Cycle = 3 of 9 stations, tiered | Yes (§1.1) |
| 2 | Cycle ends Held or Closed (ninth Return); no fail state | Yes (§1.3) |
| 3 | Leveling is player-triggered, not auto | Yes (§2.4) |
| 4 | Nine slots, no per-tree limit | Yes; revisit after pool size is known |
| 5 | Welcome/Catalyze use 0.1× time dilation, not full pause | Yes, with full-pause accessibility option (§3.4) |
| 6 | Unspent ninths discarded on Catalyze | Yes (§3.4) |
| 7 | Catalysis unlocks on first banked point | Yes (§4.2) |
| 8 | Honorblade removes Strain from Cohesion/Tension Surges | Yes (§5.1) |
| 9 | No jump; Shoulder is base mobility | Yes (§6.5) |
| 10 | Anchored bonus + Fracture punishment as the stance rhythm | Yes (§6.3–6.4) |
| 11 | Heraldic skill working name "Bearer of Agonies" | Placeholder |
| 12 | Godot 4.7 / Forward+ / GDScript + C++ boundary as §11 | Yes |

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

---

*v1.0 approved 2026-09-25. Numeric values remain prototype starting points; the Phase 4 Balancing doc supersedes them. Copy into the repo as `docs/core-systems-spec.md` at scaffold time; after that, the repo copy is authoritative and changes are logged as revisions.*
