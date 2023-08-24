extends RigidBody3D

@export var bounds_distance = 100

# Called when the node enters the scene tree for the first time.
func _ready():
	set_physics_process(User.is_server)
	if User.is_server:
		position = Vector3(8,1,-8)
		rotation.y = -45.0

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

func select(other_name):
	print(other_name, " bumped into ", get_parent().name)
	$SpotLight3D.visible = true

func unselect(other_name):
	print(other_name, " left ", get_parent().name)
	$SpotLight3D.visible = false
