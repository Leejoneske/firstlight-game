class_name ModelLibrary
## Finds artist-made models in res://models/. When a model file exists (for example
## models/krag.glb), the game uses it instead of the built-in placeholder shapes.
## See docs/ART_GUIDE.md for how to make models in Blender.

const FOLDER := "res://models/"
const EXTENSIONS := ["glb", "gltf", "blend", "tscn"]


## Returns a new instance of the named model, or null if there is none.
## Models are made facing Blender's front view; they are turned to face the game's forward.
static func instantiate(model_name: String) -> Node3D:
	for extension: String in EXTENSIONS:
		var path := FOLDER + model_name + "." + extension
		if ResourceLoader.exists(path):
			var scene := load(path) as PackedScene
			if scene:
				var model := scene.instantiate() as Node3D
				if model:
					model.rotate_y(PI)
					return model
	return null


static func find_animation_player(root: Node) -> AnimationPlayer:
	var players := root.find_children("*", "AnimationPlayer", true, false)
	return players[0] as AnimationPlayer if not players.is_empty() else null


## Plays the first of `names` the model has (e.g. ["run", "walk"]). Returns true if one played.
static func play(player: AnimationPlayer, names: Array, speed := 1.0) -> bool:
	if player == null:
		return false
	for animation_name: String in names:
		if player.has_animation(animation_name):
			if player.current_animation != animation_name:
				player.play(animation_name, 0.2)
			player.speed_scale = speed
			return true
	return false


## Meshes with a "blink" blend shape (shape key in Blender), so eyes can blink.
static func find_blink_meshes(root: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh and mesh_instance.find_blend_shape_by_name("blink") >= 0:
			result.append(mesh_instance)
	return result
