extends RigidBody3D

@export var bounds_distance: int = 100

@export var push_factor: float = 0.05


func _ready():
	set_physics_process(Globals.is_server)
	if Globals.is_server:
		position = Vector3(4, 1, -2)


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
	$AudioStreamPlayer3D.play()
	self.apply_central_impulse(-collision_get_normal * velocity_length * push_factor)
