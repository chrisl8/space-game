extends RigidBody3D

@export var bounds_distance = 100

# Called when the node enters the scene tree for the first time.
func _ready():
	set_physics_process(User.is_server)
	if User.is_server:
		position = Vector3(2.274 + RandomNumberGenerator.new().randf_range(-1.0, 1.0),0.5,-17.702 + RandomNumberGenerator.new().randf_range(-1.0, 1.0))
		rotation.y = RandomNumberGenerator.new().randf_range(-180.0, 180.0)
		print("A")

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
