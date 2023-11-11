extends RigidBody3D

@export var bounds_distance: int = 100


func _ready() -> void:
	set_physics_process(Globals.is_server)
	if Globals.is_server:
		position = Vector3(4, 1, -2)


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
