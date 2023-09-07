extends RigidBody3D

@export var bounds_distance = 100
@export var Leafs: Array[Node3D] = []

@export var push_factor = 0.8


# Called when the node enters the scene tree for the first time.
func _ready():
	set_physics_process(User.is_server)
	if User.is_server:
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


func ProcessLeaves(delta):
	var Count = 0
	for Leaf in Leafs:
		var RotVal = 0.03 * RandomNumberGenerator.new().randf_range(0.5, 1.5)
		if LeafStates[Count]:
			RotVal *= -1

		var Variance = 0.99

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


# Apply impulses to rigid bodies that we encounter to make them move.
# https://kidscancode.org/godot_recipes/3.x/physics/kinematic_to_rigidbody/index.html
# https://github.com/godotengine/godot/issues/74804
# There are other ways, but that results in pushing these things
# through walls, so this is the way.
# NOTE: Do call this in the character/player's script BEFORE move_and_slide()
# or else your velocity may be 0 at this moment (because you bumped into the thing) and hence no
# impulse will be telegraphed.
func push(collision_get_normal, velocity_length):
	self.apply_central_impulse(-collision_get_normal * velocity_length * push_factor)
