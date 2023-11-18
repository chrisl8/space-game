extends RigidBody3D

@export var bounds_distance: int = 100
@export var leafs: Array[Node3D] = []
@export var push_factor: float = 0.8

var leaf_states: Array[bool] = []


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_physics_process(Globals.is_server)
	if Globals.is_server:
		position = Vector3(
			2.274 + RandomNumberGenerator.new().randf_range(-1.0, 1.0),
			0.5,
			-17.702 + RandomNumberGenerator.new().randf_range(-1.0, 1.0)
		)
		rotation.y = RandomNumberGenerator.new().randf_range(-180.0, 180.0)

	for leaf: Node3D in leafs:
		if RandomNumberGenerator.new().randi_range(0, 1) == 1:
			leaf_states.append(false)
		else:
			leaf_states.append(true)


func _process(delta: float) -> void:
	process_leaves(delta)


func process_leaves(delta: float) -> void:
	var count: int = 0
	for leaf: Node3D in leafs:
		var rot_val: float = 0.03 * RandomNumberGenerator.new().randf_range(0.5, 1.5)
		if leaf_states[count]:
			rot_val *= -1

		var variance: float = 0.99

		if (
			leaf.get_rotation().z * 180 / 3.14 > 75
			|| RandomNumberGenerator.new().randf_range(0, 1) > variance
		):
			leaf_states[count] = false
		if (
			leaf.get_rotation().z * 180 / 3.14 < 55
			|| RandomNumberGenerator.new().randf_range(0, 1) > variance
		):
			leaf_states[count] = true

		leaf.rotate_object_local(Vector3.FORWARD, delta * rot_val)

		count += 1


func _physics_process(_delta: float) -> void:
	# Only the server should act on this object, as the server owns it,
	# especially the delete part.
	# Delete if it gets out of bounds
	if abs(position.x) > bounds_distance:
		get_parent().queue_free()
	if abs(position.y) > bounds_distance:
		get_parent().queue_free()
	if abs(position.z) > bounds_distance:
		get_parent().queue_free()
