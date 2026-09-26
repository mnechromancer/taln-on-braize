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
| Repo + Godot project + GDExtension scaffold | Setup | ⬜ Not Started |
| Gray-box arena | Feature | 🔶 In Progress — P2-01: arena + movement/camera/stance |
| Player movement + one Stoneward ability | Feature | ⬜ Not Started |
| Basic enemy spawner | Feature | ⬜ Not Started |
| Agony meter + "Welcome the Agony" prompt (no real Cataclysm payoff yet) | Feature | ⬜ Not Started |

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

*Current position: Phase 2 open. Core Systems Spec v1.0 approved. Next up: repo + Godot project + GDExtension scaffold (outside OneDrive), the handoff point to Claude Code in VS Code; then gray-box per spec §13 build order. Project files: unbroken-design-doc-draft.md, claude/unbroken-narrative-bible.md, claude/unbroken-art-direction.md (live Art Direction doc, authoritative: https://claude.ai/code/artifact/a2b626e6-f594-4f80-a75f-ca3a70e59fec), claude/unbroken-core-systems-spec.md.*
