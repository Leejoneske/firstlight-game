# Firstlight

*Working title.* A 3D prehistoric family survival game. The ground is breaking apart, and a cave family must leave everything they know and follow a light on the horizon. Built with **Godot 4.7**, designed for phones first, then PC.

See the full plan in [`docs/DESIGN.md`](docs/DESIGN.md).

## Status: M1, first playable (3D)

What's in this build:
- **A 3D low-poly world:** rolling badlands ringed by mountains, a sky with the sun moving across it, shadows and fog
- **Three camera views** (press **V**): third person over the shoulder, first person through their eyes, and a high overview
- **Two family members you can switch between:**
  - **Krag** (dad): strong and slow, smashes boulders, hits hard
  - **Zee** (teen daughter): fast and fragile, climbs tall trees for fruit
- **Gathering:** berry bushes, trees (sticks), rocks (stones), boulders (Krag only), tall fruit trees (Zee only)
- **A hidden grove** full of food, sealed off behind a boulder only Krag can smash
- **Hunger and health.** Eat from the family's shared supplies. Rest at the cave to heal.
- **Day and night.** Nights are dark, and creatures spot you from farther away.
- **The Boarcupine:** a spiky boar that charges in a straight line. Dodge so it rams something, then hit it while it's dizzy for meat. Hitting it when it isn't dizzy hurts!
- **Knockouts:** a downed member can be helped up by the other one. If everyone goes down, the family wakes up at the cave next morning and loses half their supplies.
- **Touch controls** (joystick plus buttons), **keyboard** and **gamepad**

All models are placeholders built from simple shapes in code. To replace any of them with your own Blender model, drop a `.glb` file into `models/`. See **[docs/ART_GUIDE.md](docs/ART_GUIDE.md)** for names, sizes and export settings.

Also included: a title screen, and a pause menu with settings that are saved: which side the movement stick is on, look speed, and graphics quality (*Smooth* for older phones).

## Play it on your computer

1. Download **Godot 4.7** (standard version, not .NET) from https://godotengine.org/download
2. Open Godot, click **Import**, and pick the `project.godot` file in this folder.
3. Press **F5** (or the ▶ Play button at the top right).

The first time you open the project, Godot spends a few seconds importing. That's normal.

### Controls

| Action | Keyboard & mouse | Gamepad | Phone |
|---|---|---|---|
| Move | WASD / arrow keys | Left stick / D-pad | Drag on the left side of the screen (can be swapped in the pause menu) |
| Look around | Move the mouse (click the game first) | Right stick | Drag on the other side of the screen |
| Gather / attack / help up | Space, E or left click | A | **ACT** button |
| Eat | F | X | **EAT** button |
| Switch member | 1, 2 or Tab | Right shoulder | **SWAP** button or tap a portrait |
| Change camera view | V | Y | **VIEW** button |
| Zoom (third person) | Mouse wheel | | |
| Pause and settings | Esc or P | Start | **II** button |
| Test touch controls on PC | F2 (then use the mouse) | | |

## Play it on an Android phone

One-time setup (about 20 minutes):
1. In Godot: **Editor → Manage Export Templates → Download and Install**.
2. Install **OpenJDK 17** and the **Android SDK** (the easiest way is to install Android Studio).
3. In Godot: **Editor → Editor Settings → Export → Android** and set the Java SDK and Android SDK paths.
4. **Project → Export → Add… → Android**, then click **Export Project** and save an `.apk`.
5. Copy the `.apk` to your phone and open it. You'll need to allow "install from unknown sources".

Official guide: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html

## Run the automated test

```
godot --headless --path . --import
godot --headless --path . res://tests/smoke_test.tscn
```

It plays through gathering, talents, switching, eating, hunting and the knockout retreat, then prints `SMOKE TEST: PASSED`.

## Project layout

```
project.godot        Godot project settings
scenes/main.tscn     The game scene (it builds the world in code)
scripts/
  main.gd            World building, game loop, actions, lighting and day/night
  game_state.gd      Shared supplies, messages, input map (autoload)
  camera_rig.gd      Third-person, first-person and overview cameras
  terrain.gd         Low-poly hills, mountains and ground collision
  family_member.gd   Family members: model, walking, following, health, hunger
  boarcupine.gd      The charging spiky boar
  resource_node.gd   Bushes, trees, rocks, boulders, tall trees
  camp.gd            The family cave and the safe area
  rock_wall.gd       The ridge around the hidden grove
  hud.gd             Interface: cards, supplies, hints, touch buttons
  member_card.gd     A family member's portrait card
  touch_stick.gd     Touch joystick (move)
  touch_look.gd      Touch look pad (camera)
  scenery.gd         Rock spires, arch, grass, bones, clouds, the far Firstlight peak
  model_library.gd   Loads Blender models from models/ when they exist
  mesh_util.gd, floating_text.gd
tests/               Automated smoke test
docs/DESIGN.md       Game design plan
docs/ART_GUIDE.md    How to make models in Blender for the game
```
