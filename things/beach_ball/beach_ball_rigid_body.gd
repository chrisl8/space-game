extends RigidBody3D

@export var bounds_distance: int = 100
@export var push_factor: float = 0.05
@export var spawn_position: Vector3


func _ready() -> void:
	set_physics_process(Globals.is_server)
	if Globals.is_server and spawn_position:
		position = spawn_position

	# Remember to turn on "Contact Monitor"
	# and set the "Max Contacts Reported" to be more than 0
	# 1 seems to always work for me
	body_entered.connect(_on_Area_body_entered)


func _on_Area_body_entered(body: Node) -> void:
	if body.is_in_group("players"):
		$AudioStreamPlayer3D.play()


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
