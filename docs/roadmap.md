# Unbroken: Taln on Braize — Development Roadmap

*Living document. Update status as work completes; do not renumber phases once started.*

**Status key**: ✅ Done · 🔶 In Progress · ⬜ Not Started

---

## Phase 1 — Concept / Pre-Production ✅ Complete

| Item | Type | Status |
|---|---|---|
| Initial Design Doc | Doc | ✅ Done — approved (v1.1 conformance edit to Narrative Bible, 2026-09-25) |
| Narrative Bible (Taln, Sja-Anat, Braize, Ashynite lore consolidated) | Doc | ✅ Done — approved (v1.1, peakspren name added 2026-09-25) |
| Art Direction doc (palette, silhouette language, Stoneward vs. Ashynite contrast) | Doc | ✅ Done — approved (v1.1, 2026-09-25) |

**Phase complete when**: all three docs exist and are approved.

---

## Phase 2 — Prototype

| Item | Type | Status |
|---|---|---|
| Peakspren name (deferred from Narrative Bible §5.2) | Decision | ✅ Done — Toa'uma (2026-09-25) |
| Core Systems Spec (Agony/Investiture math, catalyst cost curves, movement/camera values, damage/health model) | Doc | ✅ Done — approved v1.0, all 12 decisions ruled (2026-09-25) |
| Repo + Godot project + GDExtension scaffold | Setup | ✅ Done — Godot 4.7 project, godot-cpp, swarm GDExtension (2026-09-25) |
| Gray-box arena | Feature | ✅ Done — P2-01: arena + movement/camera/stance, branch `phase-2` (2026-09-26) |
| Player movement + one Stoneward ability | Feature | ✅ Done — movement in P2-01; Breaking Stroke weapon + Settle Surge routed through Toa'uma with Strain in P2-03 (2026-09-26) |
| Basic enemy spawner | Feature | ✅ Done — P2-02: SwarmServer v0 (C++) + SpawnDirector; Notice hunter packs in P2-03 (2026-09-26) |
| Flow-field pathing (spec §11.1) | Feature | ✅ Done — P2-04: C++ Dijkstra field in SwarmServer; swarm and hunters route around walls, cliffs and ramps (2026-09-26) |
| Investiture loop + leveling + placeholder HUD + economy bot (spec §2, §13 step 4) | Feature | ✅ Done — P2-05: station value, C++ motes, the Well and pools, Invest menu with C(n), MetaState, HUD, KiteBot economy runs (2026-09-26) |
| Agony meter + Welcome the Agony + Catalyze with placeholder Cataclysms + Bearer of Agonies (spec §3–4). Pulled forward: working Cataclysm payoff, so the gate can judge the Welcome/Bank choice | Feature | ✅ Done — P2-06: Agony meter and gains, Case A auto-bank, Welcome/Catalyze state machine and UI, Settle and Breaking Stroke Cataclysms, Bearer of Agonies, Agony on Taln's body (2026-09-27) |
| Return + cycle structure + between-run cap spending (spec §1.3, §6.6, §9). Pulled forward from Phase 4: 3-station stand-in cycle on the gray-box map and meta cap spending, so the gate can judge the full loop | Feature | ✅ Done — P2-07: CycleDirector and seeded cycles, 3-station stand-in with lulls, the Return and ninth-Return close, between-run screen with cap spending (2026-09-27) |
| Telemetry + report tool + gate build (spec §13 step 7) | Feature | ✅ Done — P2-08: TelemetryRecorder (JSON Lines per cycle), tools/telemetry_report.gd, bot gate runs on 5 seeds; the go/no-go call is the user's (2026-09-27) |
| Phase 2 gate playtest (first pass) | Decision | ✅ Done — go on direction, but the loop goes much further: the gate loop (Anchored / Well pools / Fracture) is one playstyle, not the base loop. Four playstyles as Aspects on one persistent, interconnected Braize (2026-10-17) |
| P2-09: Direction docs for the playstyles rework (Design Doc v2.0 draft, Narrative Bible v1.2 clarifications, spec v1.4 rows, this roadmap) | Doc | ✅ Done — Design Doc v2.0 approved; Narrative Bible v1.2 clarifications and spec v1.4 rows with it (2026-10-17) |
| P2-10: Braize slice, the shared base (2–3 connected graybox regions with one meta gate stub, windowed flow field, region transitions, difficulty clock, Aspect scaffold and pick, Anchored/Fracture behind an Aspect flag). Branch `graybox/base`. Pulls the Phase 4 "areas blocked in" work forward for one slice | Feature | ✅ Done — on `graybox/base`: 256 m three-region slice, windowed flow field (C++), sealed exits, siege breaker stand-in, the shortcut gate (banked Agony), Earthshaper and Unaspected Aspects; after the first playtest, a breaker drop (1 of 3 skills from a 5-skill placeholder pool) pulled forward from Phase 3 so runs have kit growth. the between-run screen scrolls. P2-10 checks pass; playtested (2026-10-17) |
| P2-11: Earthshaper graybox (Cohesion towers and walls, one construct with a rally point, the Settle / Anchored / Fracture rhythm). Branch `graybox/earthshaper` | Feature | ✅ Done — on `graybox/meteor` (one branch for every Aspect, so the launch pick offers them all): Bulwark walls (ground rebuilt around them), Sentinel towers and the Warden construct with a free rally order; structures as lures the swarm attacks (C++); Settle to the breaker pool. P2-11 checks pass; playtested 2026-10-28: kept |
| P2-12: Meteor graybox (ground launch sources, airborne state, landing damage by fall speed, camera at speed). Branch `graybox/meteor`. Built before P2-11 at your call | Feature | ✅ Done — on `graybox/meteor`: the Meteor Aspect (Impact + Heave), launch/landing and air steering, 8 launch pads, 12 m ridges, swarm contact height (C++), camera pull-out and landing shake, air telemetry, the Aspect pick at launch; then mass from Impact's levels (spec v1.7 #1). P2-12 checks pass; playtested (2026-10-22) |
| P2-13: Awareness + commander elites (known-position targeting in SwarmServer, spotters, noise; commanders buff and spot). Shared, on `graybox/base`, merged forward into the playstyle branches | Feature | ✅ Done — on `graybox/meteor`: Awareness (known-position hunting, close sight, spotters with line of sight, noise, memory, wandering; C++ + GDScript), the ash commander elite (aura buff, spotter, regional spawning with escorts), the HUD's Seen/Unseen line and commander arrow. P2-13 checks pass; playtested 2026-10-28: kept |
| P2-14: Doomhunter graybox (commander hunting; stealth and tank approaches). Branch `graybox/doomhunter` | Feature | ✅ Done — on `graybox/meteor`: Doomhunter (Shade) and (Bastion) Aspects, Rend (elite-first Weapon) and Lunge (a leap at the nearest commander). P2-14 checks pass; playtested 2026-10-28: kept |
| P2-15: Ashynite disease core + Plaguebringer graybox (Blight, spread by density, infected enemies, evasion; 800-alive stretch). Branch `graybox/plaguebringer`. Pulls the Ashynite core forward from the Design Doc §9 backlog and Phase 7 | Feature | ✅ Done — on `graybox/meteor`: the disease core in SwarmServer (infection buff, incubation, Blight damage, density spread, rewarded disease kills), Plaguebringer with Culture, Spore Burst and Fade. The 800-alive stretch is not attempted. P2-15 checks pass; playtested 2026-10-28: kept |
| P2-16: Boons as Sja-Anat's residue (Toa'uma and culture bargains, pick 1 of 3) as drift between Aspects. Starts once at least two playstyles are kept. Branch `graybox/boons` | Feature | 🔶 In Progress — on `graybox/boons`: BoonDef data, 8 bargains (4 Toa'uma, 4 culture with banes), offers of 1 of 3 on commander kills, the offer menu, effect hooks across Surges, Draw, Awareness, Health, structures and the swarm (C++), HUD line, telemetry. P2-16 checks pass; awaiting your playtest (2026-10-28) |
| Playstyle gate: keep / rework / cut each Aspect on its own playtest; kept branches merge into `phase-2` | Decision | ✅ Done — all four kept as proofs of concept (2026-10-28); `graybox/meteor` merged into `phase-2`. The three open spec calls (v1.7 #2, #9, #13) confirmed |

**Phase complete when**: the core loop is provably fun with placeholder art — this is the internal go/no-go gate. *(2026-10-17: that now means the Braize slice plus at least two Aspects are provably fun.)*

---

## Phase 3 — Vertical Slice

| Item | Type | Status |
|---|---|---|
| Content Pipeline doc (data format for authoring new weapons/skills/rooms) | Doc | ⬜ Not Started |
| UI/UX wireframes (HUD, level-up screen, Catalyze UI) | Doc | ⬜ Not Started |
| Enemy Design doc (first roster + attack patterns) | Doc | ⬜ Not Started |
| One fully realized region of the persistent map (swarm + commanders/minibosses + 3 Special Rooms + 1 breaker + its gates) | Feature | ⬜ Not Started |
| Real art pass on that area | Feature | ⬜ Not Started |
| Real audio pass on that area | Feature | ⬜ Not Started |
| One Aspect (playstyle) at real fidelity, kit drawn from all three trees (Stoneward / Herald / Ashynite) | Feature | ⬜ Not Started |

**Phase complete when**: the full loop feels good end-to-end at real fidelity — the milestone to show test players or collaborators.

---

## Phase 4 — Production / Alpha

| Item | Type | Status |
|---|---|---|
| Full Content List (every catalyst, skill, enemy, room type, area) | Doc | ⬜ Not Started |
| Meta-Progression Spec (per-skill Agony-cost curve, unlock ordering) | Doc | ⬜ Not Started |
| Balancing doc (living spreadsheet) | Doc | ⬜ Not Started |
| All areas blocked in | Feature | ⬜ Not Started |
| All planned content implemented (rough-but-functional) | Feature | ⬜ Not Started |
| Full run completable start to finish | Feature | ⬜ Not Started |

**Phase complete when**: content-complete at rough quality, one full playthrough possible.

---

## Phase 5 — Beta

| Item | Type | Status |
|---|---|---|
| Test Plan / Known Issues tracker | Doc | ⬜ Not Started |
| Balance Pass log | Doc | ⬜ Not Started |
| Content-complete, feature-complete build | Feature | ⬜ Not Started |

**Phase complete when**: no new systems being added — only balance and bugs.

---

## Phase 6 — Polish / Release Candidate

| Item | Type | Status |
|---|---|---|
| Release Checklist (platform/export requirements) | Doc | ⬜ Not Started |
| Credits/Legal doc (fan-inspired original IP boundary, Stormlight Archive attribution) | Doc | ⬜ Not Started |
| Juice pass (screen shake, hit-stop, VFX timing) | Feature | ⬜ Not Started |
| Performance optimization | Feature | ⬜ Not Started |
| Final audio mix | Feature | ⬜ Not Started |
| Tutorial / onboarding | Feature | ⬜ Not Started |

**Phase complete when**: build is shippable.

---

## Phase 7 — Post-Launch

| Item | Type | Status |
|---|---|---|
| Patch Notes template | Doc | ⬜ Not Started |
| Roadmap doc (continued support) | Doc | ⬜ Not Started |
| Bug-fix patches | Feature | ⬜ Not Started |
| Remaining Ashynite tree content (from Design Doc backlog; the disease core moved to P2-15) | Feature | ⬜ Not Started |
| Any content cut for scope | Feature | ⬜ Not Started |

---

*Current position: Phase 2 open. Core Systems Spec v1.8 (revisions in §15). P2-01 to P2-08 done on branch `phase-2`. The first gate playtest (2026-10-17) set a new direction: four playstyles as Aspects (Earthshaper, Meteor, Doomhunter, Plaguebringer) on one persistent, interconnected Braize, with boons as Sja-Anat's residue. P2-09 wrote the docs for it (Design Doc v2.0 approved). P2-10, the shared Braize slice, is done on branch `graybox/base`. P2-12 Meteor is done. All four playstyles are now built on `graybox/meteor` as one branch (P2-11 Earthshaper, P2-13 Awareness and commanders, P2-14 Doomhunter, P2-15 the disease core and Plaguebringer; spec v1.7) all playtested 2026-10-28 and kept; merged into `phase-2`. P2-16 boons are built on `graybox/boons` (spec v1.8) and await your playtest; after it, the Phase 2 gate itself. The roadmap and spec are living docs, expanded as the work needs (see CLAUDE.md). Manual checks are tested together via rendered recordings (see CLAUDE.md). Work is built in Claude Code from step-by-step handoffs given in chat (no handoff files in the repo). Project files: unbroken-design-doc-draft.md, claude/unbroken-narrative-bible.md, claude/unbroken-art-direction.md (live Art Direction doc, authoritative: https://claude.ai/code/artifact/a2b626e6-f594-4f80-a75f-ca3a70e59fec), claude/unbroken-core-systems-spec.md.*
