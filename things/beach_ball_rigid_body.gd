extends RigidBody3D

@export var max_linear_velocity = 20
@export var bounds_distance = 100
var lienar_velocity_x_abs = 0
var lienar_velocity_y_abs = 0
var lienar_velocity_z_abs = 0


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(_delta):
	# Only the server should act on this object, as the server owns it,
	# especially the delete part.
	if User.is_server:
		# Delete if it gets out of bounds
		if abs(position.x) > bounds_distance:
			get_parent().queue_free()
		if abs(position.y) > bounds_distance:
			get_parent().queue_free()
		if abs(position.z) > bounds_distance:
			get_parent().queue_free()

		# Clamp maximum velocity
		if linear_velocity.x > max_linear_velocity:
			linear_velocity.x = max_linear_velocity
		if linear_velocity.x < -max_linear_velocity:
			linear_velocity.x = -max_linear_velocity

		if linear_velocity.y > max_linear_velocity:
			linear_velocity.y = max_linear_velocity
		if linear_velocity.y < -max_linear_velocity:
			linear_velocity.y = -max_linear_velocity

		if linear_velocity.z > max_linear_velocity:
			linear_velocity.z = max_linear_velocity
		if linear_velocity.z < -max_linear_velocity:
			linear_velocity.z = -max_linear_velocity
