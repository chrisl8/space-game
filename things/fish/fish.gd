extends RigidBody3D

@export var bounds_distance: int = 100
@export var spawn_position: Vector3


func _ready() -> void:
	set_physics_process(Globals.is_server)
	if Globals.is_server and spawn_position:
		position = spawn_position


func _physics_process(_delta: float) -> void:
	# Only the server should act on this object, as the server owns it,
	# especially the delete part.
	# Delete if it gets out of bounds
	if abs(position.x) > bounds_distance:
		queue_free()
	if abs(position.y) > bounds_distance:
		queue_free()
	if abs(position.z) > bounds_distance:
		queue_free()
