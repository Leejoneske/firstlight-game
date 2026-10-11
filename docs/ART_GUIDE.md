# Art Guide: making models in Blender

The game works without any art files: every character, creature and object is built from simple shapes in code. When you add a model file to the `models/` folder, the game uses it instead automatically. Anything without a model keeps its placeholder, so you can replace things one at a time.

## Quick start

1. Make the model in Blender (free from blender.org).
2. **File → Export → glTF 2.0 (.glb)**, using the settings below.
3. Save it in the project's `models/` folder with the exact name from the table.
4. Open the project in Godot. It imports the file in a few seconds. Press F5.

Use **.glb** rather than saving `.blend` files into the project. Godot can read `.blend` directly, but only on a computer with Blender installed, and the automatic APK build doesn't have Blender.

## Model names

| File | What it replaces | Animations it can have |
|---|---|---|
| `krag.glb` | Krag (dad) | `idle`, `walk`, `run`, `attack` or `gather`, `down` |
| `zee.glb` | Zee (teen daughter) | same as Krag |
| `boarcupine.glb` | The spiky boar | `idle`, `walk`, `alert`, `charge` or `run`, `dizzy` |
| `berry_bush.glb` | Berry bush | none |
| `tree.glb` | Dry tree (sticks) | none |
| `tall_tree.glb` | Tall fruit tree (Zee climbs) | none |
| `rock.glb` | Small rock (stones) | none |
| `boulder.glb` | Boulder (Krag smashes) | none |
| `cave.glb` | The family cave | none |

New family members use their name in lowercase, e.g. `ama.glb`.

Missing animations are fine: the game uses the next one in the list, or skips it. If there's no `down` animation, a knocked-out character is tipped over on their side.

## Size, direction and origin

- **Units:** 1 Blender unit = 1 metre. An adult is about **1.7 m** tall; the game makes Krag 15% bigger and Zee 8% smaller on its own.
- **Facing:** the character faces **Blender's front view** (numpad 1), the usual way. The game turns it the right way round.
- **Origin:** at the **feet**, in the middle, at ground level (the 3D cursor at 0,0,0).
- **Apply transforms** before exporting (Ctrl+A → All Transforms).

Collision is handled by the game, so you don't need to model it. Stay roughly within the placeholder's size so characters don't sink into rocks.

## Faces

Faces are what players look at most, so keep them clear:

- **Big eyes** with a white, a coloured iris, a dark pupil and a small highlight.
- **Strong brows**: they carry most of the expression.
- **A visible mouth.** Keep beards and fringes from covering the eyes and mouth.
- **Blinking (optional):** add a shape key named **`blink`** that closes the eyelids. The game blinks it every few seconds.

The placeholder characters in the game show the proportions and colours to aim for: big heads, chunky bodies, big hands, fur tunics with jagged hems.

## Low-poly and phone-friendly

The game targets mid-range phones, so keep models light:

| Thing | Triangles (rough limit) |
|---|---|
| Family member | 3,000–6,000 |
| Boarcupine | 2,000–4,000 |
| Bush, rock, tree | 300–1,500 |
| Cave | 2,000–5,000 |

- **Colours:** plain material colours or a small texture (512×512 or 1024×1024).
- **One material per model** if you can (fewer draw calls).
- **Rigging:** an armature with up to ~40 bones is plenty. Name the animations (Actions) exactly as in the table.

## glTF export settings

In **File → Export → glTF 2.0**:

- Format: **glTF Binary (.glb)**
- Include: **Selected Objects** (select the model and its armature)
- Transform: **+Y Up** ✔ (the default)
- Data → Mesh: **Apply Modifiers** ✔
- Data → Shape Keys ✔ (for `blink`)
- Animation: ✔, with **Group by NLA Track** off, so each Action becomes an animation

## Checking your model

Run the game (F5) and look at it from all three camera views (press V). If something looks wrong:

- **Lying down or sideways:** apply rotation (Ctrl+A) and make sure it stands along Blender's Z axis.
- **Facing backwards:** the character should face Blender's front view (numpad 1).
- **Floating or sunk into the ground:** move the origin to the feet.
- **Huge or tiny:** apply scale (Ctrl+A → Scale) and check the height in metres.
