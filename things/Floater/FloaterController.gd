extends RigidBody3D

@export var bounds_distance: int = 100

@export var Arms: Array[Node3D] = []

func _ready():
	set_physics_process(get_multiplayer_authority() == multiplayer.get_unique_id())

	# TODO: Figure out a way to use this without having the location hard coded ahead of time.
	if Globals.is_server:
		position = Vector3(20.269, 2.294, -3.099)
		rotation.y = -45.0

func ProcessArms(delta) -> void:
	for Arm in Arms:
		Arm.rotate_object_local(Vector3.LEFT, delta * 1)

func _physics_process(_delta):
	# Delete if it gets out of bounds
	# Whatever spawned it should track and respawn it if required
	if abs(position.x) > bounds_distance:
		get_parent().queue_free()
	if abs(position.y) > bounds_distance:
		get_parent().queue_free()
	if abs(position.z) > bounds_distance:
		get_parent().queue_free()
		
	ProcessArms(_delta)
