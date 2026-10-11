# Firstlight — Game Design Plan (v0.1)

*Working title. A prehistoric family survival game inspired by the spirit of cave-family adventure films, with an original world, cast and creatures so it can ship on app stores.*

## 1. The pitch
The ground is breaking apart. A cave family that has always survived by hiding must now leave everything they know and follow a strange light on the horizon, crossing lands that grow stranger and more dangerous, using each family member's talents to survive.

**Theme:** fear vs. curiosity. Hiding keeps you alive tonight; exploring is the only way to have a tomorrow.

## 2. Key decisions

| Topic | Decision | Why |
|---|---|---|
| Characters | **Switch between family members**, each with a special talent | Fits the family theme; turns puzzles into "who's the right person for this?" |
| Goal | **Both:** a **Journey** mode across lands to Firstlight Peak, plus an **Endless** survival mode | Journey gives a story and an ending; Endless keeps people playing |
| Losing | **Forgiving by default:** a downed member is *knocked out* and must be carried back to camp to recover. If the whole family goes down, you wake at the last camp and drop what you carried. Optional **Hardcore** mode with permanent loss. | Broad audience, less frustration on mobile |
| World | **Movable camps:** build a camp in each land; earthquakes eventually force you onward. Fire and tool knowledge carry over. | Mixes base building with the pressure to keep moving |
| Tone | **Funny and colourful**, with real danger | Matches the inspiration; stands out from grim survival games |
| Camera | **3D, low-poly**, with three views: **third person** (default), **first person** and a high **overview** | More immersive; the overview keeps the top-down feel for planning. Low-poly keeps art affordable and phones fast |
| Audience | **Everyone (10+)**, cartoon peril, no gore | Widest store reach |
| Engine | **Godot 4 (latest stable)** | Free, exports to Android, iOS, PC and web from one project |
| Platforms | Android → PC (itch.io/Steam) → iOS | Cheapest and fastest path to real players |

## 3. The family (original cast)

| Name | Role | Talent | Weakness |
|---|---|---|---|
| **Krag** | Dad | **Strong:** lifts boulders, breaks rocks, best fighter, carries a knocked-out member fast | Slow; fear rises fastest in new places |
| **Ama** | Mom | **Provider:** gathers more, cooks better food, heals at camp | Average fighter |
| **Zee** | Teen daughter | **Scout:** fastest, climbs cliffs and trees, sees farther | Fragile; gets hungry quickly |
| **Tok** | Son | **Gentle giant:** calms and tames small creatures, carries heavy loads | Clumsy: loud footsteps wake creatures |
| **Nana Ruk** | Grandma | **Tough as stone:** resists poison and fear, shouts that scare predators off | Slow, can't climb |
| **Ollo** | The outsider (joins in Land 2) | **Inventor:** unlocks fire mastery, traps and advanced crafting | Weak; terrible at hunting |

Switching is instant (tap a portrait). Members you aren't controlling follow you, or stay at camp doing a job you set (gathering, guarding, tending the fire).

## 4. Survival meters
- **Health:** lost to creatures, falls and hazards.
- **Hunger:** drains over time; at zero, health drains.
- **Fear:** rises at night, in the dark, near predators and in unexplored places. High fear makes you slower and clumsy. Fire, family nearby and a full belly bring it down.
- **Day/night:** days are for gathering and travelling; nights are dangerous, so get back to the fire.

## 5. Journey mode: the lands

| # | Land | Feel | New threat | New resource / unlock |
|---|---|---|---|---|
| 1 | **Cracked Badlands** | Dry rock, the family cave, scarce food | Rockfalls, Boarcupines | Stone tools, the first quake |
| 2 | **Glowroot Jungle** | Lush, colourful, glowing plants at night | Snapgeese, Tigerbats | **Fire** (Ollo joins), fruit, vines |
| 3 | **Tar Marsh** | Bubbling tar pits, fog | Hippofrogs, sinking tar | Rafts, tar torches |
| 4 | **Ash Mountains** | Volcanic slopes, ash storms | Lava flows, Thunderhogs | Shelters, warm furs |
| 5 | **Firstlight Peak** | The destination, above the clouds | Everything at once | The ending |

Each land loop: arrive → set up camp → explore and gather → survive nights → tremors build → the big quake → pack up and travel to the next land.

**Endless mode:** a randomly generated, never-ending land with quakes every few days; score = days survived.

## 6. Creatures (original hybrids)
- **Boarcupine:** a spiky boar; charges in a straight line, so sidestep it. Food and quills.
- **Snapgoose:** a goose with a crocodile snout; travels in honking flocks.
- **Tigerbat:** a striped flying predator that hunts at night; scared of fire.
- **Hippofrog:** lurks in the marsh and tongue-grabs you from a distance.
- **Thunderhog:** a huge armoured beast; avoid it or outsmart it, don't fight it.
- **Fuzzbugs:** small, harmless glowing critters Tok can tame as lanterns.

## 7. Crafting (first set)
Stone axe · Spear · Basket (more carrying space) · Torch · Campfire · Lean-to shelter · Bone club · Vine rope · Raft · Snare trap

## 8. Controls
- **Phone:** virtual joystick (left thumb), action button + 2 context buttons (right thumb), tap portraits to switch.
- **PC:** WASD/arrows, mouse or Space to act, number keys 1–6 to switch, full gamepad support.

## 9. Build milestones

| Milestone | What's in it | Playable on |
|---|---|---|
| **M1: First playable** ✅ (now in 3D) | One small land, 2 family members (Krag, Zee) with switching, gathering, hunger, day/night, one creature (Boarcupine), touch + keyboard controls | PC + Android APK |
| **M2: Survival core** | Fear meter, campfire, crafting (first 5 items), knockout/carry-back, saving | PC + Android |
| **M3: Land 1 complete** | All 5 family members, the quake event, travelling to Land 2 | PC + Android |
| **M4: Land 2 + fire** | Glowroot Jungle, Ollo joins, night creatures | PC + Android |
| **M5: Endless mode** | Random map generation, scoring | PC + Android |
| **M6+** | Lands 3–5, real art and sound, store release | Android → PC → iOS |

## 10. Art and sound plan
- **Now:** simple placeholder shapes and free asset packs (e.g. Kenney.nl) so the gameplay can be tested.
- **Later:** a consistent cartoon art style (hand-drawn by you, a bought pack, or a commissioned artist), music and sound effects.

## 11. Open questions (decide as we go)
- Final game name
- Should family members talk (voice or text bubbles)?
- Monetisation: paid, free with ads, or free plus a one-time unlock?
