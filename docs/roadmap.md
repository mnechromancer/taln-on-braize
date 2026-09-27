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
| Return + cycle structure + between-run cap spending (spec §1.3, §6.6, §9). Pulled forward from Phase 4: 3-station stand-in cycle on the gray-box map and meta cap spending, so the gate can judge the full loop | Feature | ⬜ Not Started — P2-07 |
| Telemetry + report tool + gate build (spec §13 step 7) | Feature | ⬜ Not Started — P2-08 |

**Phase complete when**: the core loop is provably fun with placeholder art — this is the internal go/no-go gate.

---

## Phase 3 — Vertical Slice

| Item | Type | Status |
|---|---|---|
| Content Pipeline doc (data format for authoring new weapons/skills/rooms) | Doc | ⬜ Not Started |
| UI/UX wireframes (HUD, level-up screen, Catalyze UI) | Doc | ⬜ Not Started |
| Enemy Design doc (first roster + attack patterns) | Doc | ⬜ Not Started |
| One fully realized area (swarm + minibosses + 3 Special Rooms + 1 breaker) | Feature | ⬜ Not Started |
| Real art pass on that area | Feature | ⬜ Not Started |
| Real audio pass on that area | Feature | ⬜ Not Started |
| One full skill per tree (Stoneward / Herald / Ashynite) at real fidelity | Feature | ⬜ Not Started |

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
| Ashynite tree full content pass (from Design Doc backlog) | Feature | ⬜ Not Started |
| Any content cut for scope | Feature | ⬜ Not Started |

---

*Current position: Phase 2 open. Core Systems Spec v1.3 (revisions in §15). Repo + Godot project + GDExtension scaffold done; gray-box arena (P2-01), SwarmServer v0 + spawner (P2-02), and weapon + Stoneward Surge + Toa'uma/Strain (P2-03) done on branch `phase-2`; flow field (P2-04), the Investiture loop (P2-05) and Agony/Catalyze (P2-06) done. Next up: P2-07 and P2-08 (Return + cycle + between-run, telemetry + gate build), then the Phase 2 go/no-go gate. The roadmap and spec are living docs, expanded as the work needs (see CLAUDE.md). Manual checks are tested together via rendered recordings (see CLAUDE.md). Work is built in Claude Code from step-by-step handoffs given in chat (no handoff files in the repo). Project files: unbroken-design-doc-draft.md, claude/unbroken-narrative-bible.md, claude/unbroken-art-direction.md (live Art Direction doc, authoritative: https://claude.ai/code/artifact/a2b626e6-f594-4f80-a75f-ca3a70e59fec), claude/unbroken-core-systems-spec.md.*
