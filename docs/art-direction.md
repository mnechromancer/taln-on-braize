# Unbroken: Taln on Braize — Art Direction v1.1

*v1.0 approved 2026-09-25; v1.1 is a conformance revision to Narrative Bible v1.0. Live doc: https://claude.ai/code/artifact/a2b626e6-f594-4f80-a75f-ca3a70e59fec — that version is authoritative if the two differ.*

## Purpose & scope

This doc fixes how Unbroken looks: environment, palette, silhouettes, character, VFX, UI and the technical limits on all of them. It builds on Design Doc v1.0 without changing any system in it, and conforms to Narrative Bible v1.0, which governs fiction.

Governing rule: **the environment is quiet so the signals can be loud.** Braize is desaturated and low-contrast; saturated color and bright value are reserved for things the player must read in a dense swarm.

Out of scope: final asset lists (Full Content List, Phase 4), HUD layout (UI/UX wireframes, Phase 3), exact engine settings (Core Systems Spec, Phase 2).

## Visual pillars

| Design pillar | Visual rule | Practical test |
| --- | --- | --- |
| Endurance, not victory | Wear accumulates and only resets on death: Taln's armor and the arena floor degrade as the cycle goes on | A screenshot at minute 30 is distinguishable from minute 2 without the HUD |
| Ground, not sky | Power lives on the ground plane. Stoneward effects deform, crack, raise and settle terrain; nothing of Taln's floats decoratively | Every Stoneward VFX has a ground-contact component |
| Death is a beat | Death and return are a staged, repeatable sequence with fixed timing | Reads the same every time; skippable after first viewing |
| Agony as fuel | Agony is visible on Taln's body, not only in a bar | At 75%+ Agony the player sees it without the HUD |
| Small pool, dense synergy | Every item has one owned color/shape signature; combinations visibly mix signatures | Two combined catalysts identifiable from the effect alone |

Readability (pillar 5) wins conflicts.

## Braize environment

No storms, no color, no life, no sun. Every light on Braize is Invested: magic, hostile, or Taln himself. Nothing ambient, and nothing warm that isn't his.

**Lighting**
- No sun and no directional light. Sky is flat black at all times; horizon fades into same-black fog, so the arena feels bounded without walls.
- **The Well** is the base light layer: Investiture pooled faintly in seams, pits and fractures. Ground is lit from below and inside, never from above; cold, dim, in the environment value range.
- **Taln is a light source.** Agony cracks, the gem's molten facets and the Honorblade cast local light. The screen is brightest where he is; dark closes in behind him.
- Enemy light is hostile light: threat-hue eyes, telegraphs and enemy Voidlight light the ground around them.
- Characters need a rim or emissive edge; rim light comes from the nearest Invested source, not a global key.

**Geometry**
- "Wrong" comes from proportion, not ornament: angles a few degrees off vertical, steps too tall to climb, surfaces too smooth to be natural and too irregular to be built.
- Repetition with drift: near-identical repeated forms (pillars, ridges, pits).
- No vegetation, water or recognisable architecture.
- **Accretion**: some crags were things once; half-legible shapes of what the core pulled in, never nameable.
- **The Nine**: nonagonal plans, ninefold repetitions, groups of nine. The place counts wrong, never explained.

**Hostile, reactive terrain**
- Ground darkens or fractures around Taln over time; stillness is punished visually before mechanically.
- Arena wear persists through a run until the area changes.
- Area variation from ground material, landform and Well pattern, not new palettes. Swarm-dominant areas open and flat; boss-leaning areas enclosed and vertical.

## Palette system

Environment uses a narrow near-neutral range; six signal hues are reserved for gameplay and never appear in environment art. Hex values are final; changes require a revision.

**Environment range**

| Role | Hex | Notes |
| --- | --- | --- |
| Sky / deep shadow | #0B0B0E | Flat, no gradient |
| Ground base | #2A2825 | Neutral ash |
| Ground mid | #5A564F | Faces lit by a nearby Invested source |
| Bone highlight | #A69E8F | Brightest environment value; edges catching Well glow or Taln's light only |
| Well glow | #6F7486 | Pooled Investiture in seams and pits; cold, dim, from below; never a signal |

**Signal hues**

| Signal | Hex | Meaning | Surface quality |
| --- | --- | --- | --- |
| Honor / Herald | #CFE8FF | Honorblade, Herald tree, Investiture pickups | Clean steady glow; the only "safe" light |
| Stoneward | #8C6A43 → #D9A55B | Stoneward tree; gem's molten facets at rest | Mostly non-emissive; glow only at fracture lines |
| Taln's Voidlight (peakspren) | #6B3FA0 core, #7FE3D6 rim | Voidlight-powered Stoneward skills | Unstable: flicker, inverted glow |
| Ashynite | #9FCB3A | Ashynite tree, afflictions | Bioluminescent, patient; ordered colonies that pool and linger |
| Agony | #E0581F → #FF8A3D | Agony meter, body cracks, Catalyze UI | Ember glowing from inside cracks |
| Enemy threat | #C2185B | Enemy projectiles, telegraphs, hazards, enemy Voidlight | High saturation, hard edges |

**Rules**
1. Environment within ~5–45% value; signals above 60%. Grayscale screenshot check: every hazard must read.
2. Enemy threat is the only magenta-red on screen; no player effect uses it.
3. Taln's Voidlight and enemy Voidlight never share a hue. Enemy Voidlight uses threat hue; Taln's carries the teal rim (Sja-Anat's mark).
4. Colorblind: threat vs Agony vs Ashynite also differ in shape and motion.
5. Warmth belongs to Taln: Agony ember, Stoneward ochre, the gem's molten facets. No environment or enemy element uses the orange-ochre range.

## Silhouette language

| Tier | Shape language | Scale vs Taln | Read test |
| --- | --- | --- | --- |
| Taln | Wide base, low center of gravity, squared shoulders; planted triangle | 1.0 | Findable in a full swarm within 0.5 s |
| Swarm | Narrow, vertical, spindly or hunched; reaching/crawling limbs | 0.5–0.9 | Reads as texture in groups of 50+ |
| Miniboss | One exaggerated feature per variant; asymmetric | 1.5–2.5 | Type identifiable from footprint alone |
| Breaker | Unique architectural silhouette per breaker | 3.0+ | Recognisable in thumbnail; no shared base shape |

- Invented Fused only; no canon reskins. Family-level shared DNA allowed.
- Invented Fused roster organized in **nine families**, each owning one ground decal shape that is also its telegraph language; the nine shapes are set in the Enemy Design doc.
- **Nine breakers** in the rotating cast, named for the pressure they apply.
- **Voidspren read as staff, not wildlife**: uniform, regimented motion. Spindly reaching shapes belong to the Fused swarm.
- Every character gets a rim or emissive edge. Telegraphs are ground-plane decals.

## Taln character art

Functional, heavy, patched, never polished; repaired thousands of times by himself.

- Heavy infantry kit: thick torso/shoulder plates, lighter joints. Weight shows in animation.
- Visible repair history: mismatched plates, bindings, scars; asymmetrical.
- Agony shows as ember cracks through armor and skin, scaling with the meter.
- Aura, scars and armor wear accumulate as he survives and all reset on death; nothing visual carries across deaths or into meta-progression.

| Object | Placement | Visual state |
| --- | --- | --- |
| Peakspren gem | Chest plate or left gauntlet | At rest: the peakspren's molten cracks run through the facets, warm and dim. Used: Voidlight flicker. Erratic pulse as in-cycle risk escalates; pulses with its voice when it speaks. No visual presence outside the gem |
| Ashynite vessel | Hip, strapped and sealed | His grandmother's: ceramic or glass, Ashynite-made, rounded and finished like nothing Rosharan or Braizean. The only object that looks like it came from a living civilization. Faint green seep at seams; brightens when Ashynite skills fire |
| Honorblade | Absent at run start; on the back once acquired | Steady Honor-light edge glow |

Animation: stance over flourish; short, committed, heavy attacks; no spins or flips. Idle is a braced ready stance.

## Tree visual identities

| Axis | Stoneward | Herald | Ashynite |
| --- | --- | --- | --- |
| Material | Stone, dust, metal; matte | Light; clean emissive | Cultured growth: glassy, translucent, bioluminescent |
| Motion | Slam, crack, settle | Linear, precise, instant | Creep, pulse, spread, linger |
| Shape | Angular, faceted, grid-aligned | Lines, arcs, rings | Ordered colonies, radial symmetry, branching veins |
| Ground contact | Always; deforms terrain | Rarely; marks only | Persistent pools and stains |
| Sound cue | Low impact, grinding | High, clear, ringing | Wet, hissing, breathing |
| Emotional read | Endurance, weight | Duty, discipline | A bargain; medical, patient, tended |

Ashynite is never body horror for its own sake: effects look cultivated and kept, like specimens.

Peakspren Voidlight belongs to the Stoneward tree: Voidlight-powered Stoneward skills keep Stoneward material, motion and ground contact, but fracture glow renders in Voidlight (dark core, teal rim) with flicker and glitch-frames. Honorblade-powered Stoneward skills use steady ochre glow.

## VFX language

Priority (lower culls first when busy): 1 enemy telegraphs/projectiles · 2 Taln position/health · 3 Cataclysms and Welcome the Agony prompt · 4 Taln abilities · 5 Investiture pickups · 6 hit feedback, death bursts, ambient.

| Agony | Visual |
| --- | --- |
| 0–24% | None |
| 25–49% | Faint ember seams at joints |
| 50–74% | Cracks spread; slow pulse |
| 75–99% | Bright cracks, heat shimmer, shed embers |
| 100% | Full-body ember glow; Agony-hue edge vignette; world desaturates further |

- Each catalyst owns one signature in its tree's material/shape; combined Cataclysms layer signatures.
- Accept "Welcome the Agony": short consistent charge-up. Decline: brief inward pull of ember.
- Cataclysms may not hide enemy telegraphs for more than a moment.
- Death: time slows, cracks flare, Taln breaks into ash along crack lines, screen drains to black. Return: ash reassembles, cracks close, scars and wear reset, one breath, control resumes. Fixed timing, skippable after first viewing.

## UI/HUD visual direction

- Material: flat dark stone or worn metal at low opacity; no gradients, glass or bevels.
- Type: one condensed heavy display face; one plain sans for numbers/body.
- Iconography: original glyph set, one silhouette per item, tree frames (faceted / ring / organic). No canon Stormlight glyphs.
- Color: HUD uses world signal hues only; Investiture in Honor hue.
- Catalyze UI: hold-and-click on the catalyst icon, which fills with Agony hue; cost as notches on the 100% meter.
- Between-run screen framed as Taln's memory.
- Agony-visions and Herald memories: 2D illustrated panels; flat shapes, hard shadows, environment palette plus one signal hue per panel; original Herald depictions. Sja-Anat only ever in reflection (gem facet, wet stone, blade flat).

## Technical art constraints

Flat-shaded low poly, flat-color materials (color + roughness, no texture maps); detail from faceted edges catching local Invested light.

| Asset | Triangle target (provisional) | Notes |
| --- | --- | --- |
| Swarm enemy | ≤ 1,500 | Instanced; shared material; shader animation |
| Miniboss | ≤ 10,000 | Skeletal |
| Breaker | ≤ 30,000 | One on screen |
| Taln | ≤ 20,000 | Highest animation fidelity |
| Arena module | Modular kit | Material swaps across areas |

- Swarm via MultiMesh instancing with shader animation.
- Telegraphs and stains via decals/projected shaders.
- One shared swarm rig; minibosses may have unique rigs.
- No directional light: emissive materials plus a small set of dynamic local lights; per-frame light budget lives in the Core Systems Spec.

## IP boundary

All visual assets original. No reproduction or tracing of covers, interior art, chapter icons, glyphs, maps or licensed art; no canon Fused types or official character designs. Canon art on reference boards for tone only.

## Reference board (16)

- Environment: Giorgio de Chirico (illogical shadows from off-frame sources, empty architecture; not his daylight); Zdzisław Beksiński (doomsday ruins); Fumito Ueda / Shadow of the Colossus (design by subtraction); Death's Door (low-poly mood via lighting).
- Taln: Dendra panoply; lorica segmentata; Mike Mignola (blocky shadow shapes, mass).
- Enemies: H. R. Giger (Fused carapace only, never Ashynite); Scorn (breakers as structures, accreted terrain); Beksiński figures (spindly swarm); Shadow of the Colossus (creature-as-landmark breakers).
- VFX/UI/panels: Hades (per-source color coding; Hades II overload as counter-lesson); Megabonk (low-poly swarm readability); Death's Door death screen; Mignola covers (Agony-vision panels); Ernst Haeckel, Kunstformen der Natur (Ashynite register: ordered, curated, specimen-like).

## Decisions log

| Version | Question | Decision |
| --- | --- | --- |
| v1.1 | Light on Braize | No sun, no directional light; every light Invested: the Well, Taln, hostile sources. Warmth belongs to Taln |
| v1.1 | Nine-centricity | Structural: nine-based geometry, nine Fused families and decal shapes, nine breakers |
| v1.1 | Ashynite vessel | His grandmother's; only object from a living civilization |
| v1.1 | Ashynite tone | Medical, patient, tended; never body horror for its own sake |
| v1.1 | Sja-Anat depiction | Reflection only |
| v1.0 | Stylization | Flat-shaded low poly, no texture maps |
| v1.0 | Peakspren Voidlight | Part of the Stoneward tree |
| v1.0 | Peakspren presence | Voice-only, in the gem |
| v1.0 | Appearance progression | Accumulates while surviving, resets on death |
| v1.0 | Agony-visions | 2D illustrated panels |
| v1.0 | Signal hexes | Locked; v1.1 replaced Sun with Well glow |
