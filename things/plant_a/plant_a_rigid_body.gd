extends RigidBody3D

@export var bounds_distance: int = 100
@export var Leafs: Array[Node3D] = []

@export var push_factor: float = 0.8


# Called when the node enters the scene tree for the first time.
func _ready():
	set_physics_process(Globals.is_server)
	if Globals.is_server:
		position = Vector3(
			2.274 + RandomNumberGenerator.new().randf_range(-1.0, 1.0),
			0.5,
			-17.702 + RandomNumberGenerator.new().randf_range(-1.0, 1.0)
		)
		rotation.y = RandomNumberGenerator.new().randf_range(-180.0, 180.0)

	for Leaf in Leafs:
		if RandomNumberGenerator.new().randi_range(0, 1) == 1:
			LeafStates.append(false)
		else:
			LeafStates.append(true)


func _process(delta):
	ProcessLeaves(delta)


var LeafStates: Array[bool] = []


func ProcessLeaves(delta) -> void:
	var Count: int = 0
	for Leaf in Leafs:
		var RotVal = 0.03 * RandomNumberGenerator.new().randf_range(0.5, 1.5)
		if LeafStates[Count]:
			RotVal *= -1

		var Variance: float = 0.99

		if (
			Leaf.get_rotation().z * 180 / 3.14 > 75
			|| RandomNumberGenerator.new().randf_range(0, 1) > Variance
		):
			LeafStates[Count] = false
		if (
			Leaf.get_rotation().z * 180 / 3.14 < 55
			|| RandomNumberGenerator.new().randf_range(0, 1) > Variance
		):
			LeafStates[Count] = true

		Leaf.rotate_object_local(Vector3.FORWARD, delta * RotVal)

		Count += 1
	return


func _physics_process(_delta):
	# Only the server should act on this object, as the server owns it,
	# especially the delete part.
	# Delete if it gets out of bounds
	if abs(position.x) > bounds_distance:
		get_parent().queue_free()
	if abs(position.y) > bounds_distance:
		get_parent().queue_free()
	if abs(position.z) > bounds_distance:
		get_parent().queue_free()
