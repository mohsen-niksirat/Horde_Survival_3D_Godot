extends Node3D
## Hero visual: Kenney Mini Characters GLB (CC0) when available, otherwise
## the primitive hooded-mage fallback. Procedural idle/run bob + staff orb.

const HERO_SCENES := {
	"mage": "res://assets/models/heroes/hero_mage.glb",
	"paladin": "res://assets/models/heroes/hero_paladin.glb",
	"rogue": "res://assets/models/heroes/hero_rogue.glb",
}

@onready var root: Node3D = $"../Root"
@onready var robe: MeshInstance3D = $"../Root/Robe"
@onready var torso: MeshInstance3D = $"../Root/Torso"
@onready var hood: MeshInstance3D = $"../Root/Hood"
@onready var shoulder_l: MeshInstance3D = $"../Root/ShoulderL"
@onready var shoulder_r: MeshInstance3D = $"../Root/ShoulderR"
@onready var staff: Node3D = $"../Root/Staff"
@onready var orb: MeshInstance3D = $"../Root/Staff/Orb"

var _bob_time: float = 0.0
var _move_speed: float = 0.0
var _external: Node3D = null
var _external_base_y: float = 0.0

func _ready() -> void:
	# Parent Player may still be setting up children — defer the GLB attach
	_try_load_external_hero.call_deferred()

func use_external() -> bool:
	return _external != null and is_instance_valid(_external) and _external.is_inside_tree()

func _character_id() -> String:
	if GameManager != null and GameManager.selected_character_id != "":
		return GameManager.selected_character_id
	return "mage"

func _try_load_external_hero() -> void:
	if use_external():
		return
	var id := _character_id()
	var path: String = HERO_SCENES.get(id, HERO_SCENES["mage"])
	if not ResourceLoader.exists(path):
		return
	var packed = load(path)
	if packed == null:
		return
	var inst = packed.instantiate()
	if inst == null:
		return
	inst.name = "KenneyHero"
	var mesh_parent: Node3D = get_parent()
	if mesh_parent == null:
		return
	mesh_parent.add_child(inst)
	_external = inst
	_external_base_y = inst.position.y
	_scale_external_to_capsule(inst)
	_apply_tint(id, inst)
	if root != null and is_instance_valid(root):
		root.visible = false

func _scale_external_to_capsule(inst: Node3D) -> void:
	# Kenney mini characters are roughly 1u tall; capsule is ~1.8m
	inst.scale = Vector3.ONE * 1.55
	inst.position.y = 0.0

func _apply_tint(character_id: String, inst: Node3D) -> void:
	var tint := Color(0.35, 0.45, 0.8)
	match character_id:
		"paladin": tint = Color(0.85, 0.75, 0.35)
		"rogue": tint = Color(0.35, 0.55, 0.4)
		"mage": tint = Color(0.4, 0.45, 0.85)
	_iter_mesh_tint(inst, tint)

func _iter_mesh_tint(node: Node, tint: Color) -> void:
	if node is MeshInstance3D:
		var count: int = node.get_surface_override_material_count()
		for i in range(maxi(count, 1)):
			var mat = node.get_surface_override_material(i)
			if mat is StandardMaterial3D:
				var m: StandardMaterial3D = mat.duplicate()
				m.albedo_color = m.albedo_color.lerp(tint, 0.35)
				node.set_surface_override_material(i, m)
	for c in node.get_children():
		_iter_mesh_tint(c, tint)

func set_character_tint(character_id: String) -> void:
	if use_external():
		_apply_tint(character_id, _external)

## Called every frame by the player with its current planar speed.
func animate(delta: float, speed: float) -> void:
	_move_speed = speed
	if use_external():
		_animate_external(delta, speed)
		return
	if root == null or staff == null or orb == null:
		return
	if speed > 0.5:
		_bob_time += delta * speed * 1.5
		var bob := absf(sin(_bob_time)) * 0.09
		root.position.y = bob
		root.rotation.x = lerpf(root.rotation.x, 0.1, 8.0 * delta)
		staff.rotation.z = lerpf(staff.rotation.z, -0.35 + sin(_bob_time * 2.0) * 0.12, 8.0 * delta)
	else:
		_bob_time += delta * 2.0
		root.position.y = sin(_bob_time) * 0.03
		root.rotation.x = lerpf(root.rotation.x, 0.0, 6.0 * delta)
		staff.rotation.z = lerpf(staff.rotation.z, -0.3 + sin(_bob_time * 0.7) * 0.06, 4.0 * delta)
	var pulse := 1.0 + sin(_bob_time * 2.5) * 0.08
	orb.scale = Vector3(pulse, pulse, pulse)

func _animate_external(delta: float, speed: float) -> void:
	if _external == null or not is_instance_valid(_external):
		return
	if speed > 0.5:
		_bob_time += delta * speed * 1.6
		var bob := absf(sin(_bob_time)) * 0.07
		_external.position.y = _external_base_y + bob
		_external.rotation.x = lerpf(_external.rotation.x, 0.08, 8.0 * delta)
	else:
		_bob_time += delta * 2.0
		_external.position.y = _external_base_y + sin(_bob_time) * 0.025
		_external.rotation.x = lerpf(_external.rotation.x, 0.0, 6.0 * delta)
