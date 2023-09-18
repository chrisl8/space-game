extends RigidBody3D

# The entire Rigidbody based Character Controller here is based on code found at https://github.com/FreeFlyFall/RigidBodyController

# Set by the authority, synchronized on spawn.
@export var player: int = -1

### Use the GodotPhysics physics engine

### Global
@export var debug: bool
var is_grounded: bool  # Whether the player is considered to be touching a walkable slope
@onready var capsule: Shape3D = $Collision.shape  # Capsule collision shape of the player
@onready var head: Node3D = $Head  # y-axis rotation node (look left and right)
@onready var camera: Node = get_node("./Head/Camera3D")  # Camera3D node
@onready var head_mesh: Node = get_node("./Head/HeadMesh")  # x-axis rotation node (look up and down)
@onready var character_meshes: Node3D = $Character

### Input vars

### Integrate forces vars
@export var accel: int  # Player acceleration force
@export var jump: int  # Jump force multiplier
@export var air_control: int  # Air control multiplier
@export var turning_scale: float  # How quickly to scale movement towards a turning direction. Lower is more. # (float, 15, 120, 1)
@export var mouse_sensitivity: float = 0.05  # 0.05
@export var walkable_normal: float  # 0.35 # Walkable slope. Lower is steeper # (float, 0, 1, 0.01)
@export var speed_to_crouch: int  # Speed to move in/out of crouching position at. # Too high causes physics glitches currently. # (int, 2, 20)
@export var speed_limit: float  # 8 # Default speed limit of the player
@export var crouching_speed_limit: float  # 4 # Speed to move at while crouching
@export var sprinting_speed_limit: float  # 12 # Speed to move at while sprinting
@export var danger_speed_limit: float  # Maximum speed limit
@export var friction_divider: int = 6  # Amount to divide the friction by when not grounded (prevents sticking to walls from air control)
var upper_slope_normal: Vector3  # Stores the lowest (steepest) slope normal
var lower_slope_normal: Vector3  # Stores the highest (flattest) slope normal
var slope_normal: Vector3  # Stores normals of contact points for iteration
var contacted_body: RigidBody3D  # Rigid body the player is currently contacting, if there is one
var player_physics_material: Resource = load("res://Physics/player.tres")
var local_friction = player_physics_material.friction  # Editor friction value
var is_landing: bool = true  # Whether the player has jumped and let go of jump
var is_jumping: bool = false  # Whether the player has jumped
@export var JUMP_THROTTLE: float  # 0.1 # Stores preference for time before the player can jump again # (float,0.01,1,0.01)
var jump_throttle: float  # Variable used with jump throttling calculations
@export var landing_assist: float  # 1.5 # Downward force to apply when letting go of space while jumping
@export var anti_slide_force: float  # 3 # Amount of force to stop sliding with # (float,0.1,100,0.1)

### Physics process vars
var original_height: float
var crouching_height: float
var current_speed_limit: float  # Current speed limit to use. For standing or crouching.
var posture  # Current posture state
enum { WALKING, CROUCHING, SPRINTING }  # Possible values for posture

### Misc
var ld: Node2D = preload("res://Scripts//DrawLine3D.gd").new()

var cam: Camera3D


### Godot notification functions ###
func _ready():
	cam = camera
	if Globals.is_server:
		# Ensure server has no player cameras
		cam.clear_current()
	elif player == multiplayer.get_unique_id():
		cam.make_current()

	# Get capsule variables
	original_height = capsule.height
	crouching_height = capsule.height / 2
	add_child(ld)  # Add line drawer


func _input(event):
	# Player look
	if (
		Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
		and event is InputEventMouseMotion
		and get_multiplayer_authority() == multiplayer.get_unique_id()
	):
		# Rotate entire head on y axis
		head.rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
		var camera_head_x_rotation: float = deg_to_rad(-event.relative.y * mouse_sensitivity)
		# Rotate camera on x axis
		# Limit to prevent flipping camera/head
		camera.rotate_x(camera_head_x_rotation)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-50), deg_to_rad(50))
		# Also rotate head on x axis for visual
		# Limit so head doesn't clip into body
		head_mesh.rotate_x(camera_head_x_rotation)
		head_mesh.rotation.x = clamp(head_mesh.rotation.x, deg_to_rad(-25), deg_to_rad(25))
	# Capture and release mouse
	# This is already done at the scene level, although maybe we could move it here?
	# if event.is_action_pressed("ui_cancel"):
	# 	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
	# 		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)  # Free the mouse
	# 	else:
	# 		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


var is_done_shrinking: bool  # temporary # Whether the player is currently shrinking towards being crouched

var character_trimmed: bool = false


func _process(_delta: float) -> void:
	# Hide body and head from local player, foot remains
	if (
		not Globals.is_server
		and not character_trimmed
		and get_multiplayer_authority() == multiplayer.get_unique_id()
	):
		character_trimmed = true
		get_node("./Head/HeadMesh").visible = false  # Only make invisible so that we can rotate it and sync to other players
		get_node("./Character/Body").queue_free()
	# Synchronize Character rotation with head (camera) rotation
	character_meshes.rotation.y = head.rotation.y


func _physics_process(delta):
	### Player posture FSM
	if Input.is_action_pressed("crouch"):
		posture = CROUCHING
	elif Input.is_action_pressed("sprint"):
		posture = SPRINTING
	else:
		posture = WALKING

	### Groundedness raycasts
	# Define raycast info used with detecting groundedness
	var raycast_list: Array = Array()  # List of raycasts used with detecting groundedness
	var bottom: float = 0.1  # Distance down from start to fire the raycast to
	var start = (capsule.height / 2 + capsule.radius) - 0.05  # Start point down from the center of the player to start the raycast
	var cv_dist = capsule.radius - 0.1  # Cardinal vector distance.
	var ov_dist = cv_dist / sqrt(2)  # Ordinal vector distance. Added to 2 cardinal vectors to result in a diagonal with the same magnitude of the cardinal vectors
	# Get world state for collisions
	var direct_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	raycast_list.clear()
	is_grounded = false
	# Create 9 raycasts around the player capsule.
	# They begin towards the edge of the radius and shoot from just
	# below the capsule, to just below the bottom bound of the capsule,
	# with one raycast down from the center.
	for i in 9:
		# Get the starting location
		var loc: Vector3 = self.position
		# subtract a distance to get below the capsule
		loc.y -= start
		# Create the distance from the capsule center in a certain direction
		match i:
			# Cardinal vectors
			0:
				loc.z -= cv_dist  # N
			1:
				loc.z += cv_dist  # S
			2:
				loc.x += cv_dist  # E
			3:
				loc.x -= cv_dist  # W
			# Ordinal vectors
			4:
				loc.z -= ov_dist  # NE
				loc.x += ov_dist
			5:
				loc.z += ov_dist  # SE
				loc.x += ov_dist
			6:
				loc.z -= ov_dist  # NW
				loc.x -= ov_dist
			7:
				loc.z += ov_dist  # SW
				loc.x -= ov_dist
		# Copy the current location below the capsule and subtract from it
		var loc2 = loc
		loc2.y -= bottom
		# Add the two points for this iteration to the list for the raycast
		raycast_list.append([loc, loc2])
	# Check each raycast for collision, ignoring the capsule itself
	for array in raycast_list:
		# Some Godot 3 to 4 conversion information can be found at:
		# https://www.reddit.com/r/godot/comments/u0fboh/comment/idtoz30/?utm_source=share&utm_medium=web2x&context=3
		var params: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
		params.from = array[0]
		params.to = array[1]
		params.exclude = [self]
		var collision = direct_state.intersect_ray(params)
		# The player is grounded if any of the raycasts hit
		if collision and is_walkable(collision.normal.y):
			is_grounded = true

	### Sprinting & Crouching
	var crouch_scale = delta * speed_to_crouch  # Amount to change capsule height up or down
	var move_camera = delta / 2 * speed_to_crouch  # Amount to move camera while crouching
	match posture:
		SPRINTING:
			current_speed_limit = sprinting_speed_limit
			grow_capsule(is_done_shrinking, crouch_scale, move_camera)
		CROUCHING:  # Shrink
			current_speed_limit = crouching_speed_limit
			if capsule.height > crouching_height:
				capsule.height -= crouch_scale
				camera.position.y -= move_camera
			## Adding a force to work around some physics glitches for the moment
			elif is_done_shrinking == false:
				var look_direction: Vector3 = head.transform.basis.z
				self.apply_central_force(look_direction * mass * 100)
				is_done_shrinking = true
		WALKING:  # Grow
			current_speed_limit = speed_limit
			grow_capsule(is_done_shrinking, crouch_scale, move_camera)

	# Setup jump throttle for integrate_forces
	if is_jumping or is_landing:
		jump_throttle -= delta
	else:
		jump_throttle = JUMP_THROTTLE


func _integrate_forces(state):
	upper_slope_normal = Vector3(0, 1, 0)
	lower_slope_normal = Vector3(0, -1, 0)
	contacted_body = null  # Rigidbody
	# Velocity of the Rigidbody the player is contacting
	var contacted_body_vel_at_point: Vector3 = Vector3()

	### Grounding, slopes, & rigidbody contact point
	# If the player body is contacting something
	var shallowest_contact_index: int = -1
	if state.get_contact_count() > 0:
		# Iterate over the capsule contact points and get the steepest/shallowest slopes
		for i in state.get_contact_count():
			slope_normal = state.get_contact_local_normal(i)
			if slope_normal.y < upper_slope_normal.y:  # Lower normal means steeper slope
				upper_slope_normal = slope_normal
			if slope_normal.y > lower_slope_normal.y:
				lower_slope_normal = slope_normal
				shallowest_contact_index = i
		# If the steepest slope contacted is more shallow than the walkable_normal, the player is grounded
		if is_walkable(upper_slope_normal.y):
			is_grounded = true
			# If the shallowest contact index exists, get the velocity of the body at the contacted point
			if shallowest_contact_index >= 0:
				var contact_position = state.get_contact_collider_position(0)  # coords of the contact point from center of contacted body
				var collisions: Array[Node3D] = get_colliding_bodies()
				if collisions.size() > 0 and collisions[0].get_class() == "RigidBody3D":
					contacted_body = collisions[0]
					contacted_body_vel_at_point = get_contacted_body_velocity_at_point(
						contacted_body, contact_position
					)
					#print(contacted_body_vel_at_point)
		# Else if the shallowest slope normal is not walkable, the player is not grounded
		elif !is_walkable(lower_slope_normal.y):
			is_grounded = false

	### Jumping: Should allow the player to jump, and hold jump to jump again if they become grounded after a throttling period
	var has_walkable_contact: bool = (
		state.get_contact_count() > 0 and is_walkable(lower_slope_normal.y)
	)  # Different from is_grounded
	# If the player is trying to jump, the throttle expired, the player is grounded, and they're not already jumping, jump
	# Check for is_jumping is because contact still exists at the beginning of a jump for more than one physics frame
	if (
		Input.is_action_pressed("jump")
		and jump_throttle < 0
		and has_walkable_contact
		and not is_jumping
	):
		state.apply_central_impulse(Vector3(0, 1, 0) * jump)
		is_jumping = true
		is_landing = false
	# Apply a downward force once if the player lets go of jump to assist with landing
	if Input.is_action_just_released("jump"):
		if is_landing == false:  # Only apply the landing assist force once
			is_landing = true
			if not has_walkable_contact:
				state.apply_central_impulse(Vector3(0, -1, 0) * landing_assist)
	# If the player becomes grounded, they're no longer considered to be jumping
	if has_walkable_contact:
		is_jumping = false

	### Movement
	var move = relative_input()  # Get movement vector relative to player orientation
	var move2: Vector2 = Vector2(move.x, move.z)  # Convert movement for Vector2 methods

	set_friction(move)

	# Get the player velocity, relative to the contacting body if there is one
	var vel: Vector3 = Vector3()
	if is_grounded:
		## Keep vertical velocity if grounded. vel will be normalized below
		## accounting for the y value, preventing faster movement on slopes.
		vel = state.get_linear_velocity()
		vel -= contacted_body_vel_at_point
	else:
		## Remove y value of velocity so only horizontal speed is checked in the air.
		## Without this, the normalized vel causes the speed limit check to
		## progressively limit the player from moving horizontally in relation to vertical speed.
		vel = Vector3(state.get_linear_velocity().x, 0, state.get_linear_velocity().z)
		vel -= Vector3(contacted_body_vel_at_point.x, 0, contacted_body_vel_at_point.z)
	# Get a normalized player velocity
	var nvel = vel.normalized()
	var nvel2: Vector2 = Vector2(nvel.x, nvel.z)  # 2D velocity vector to use with angle_to and dot methods

	## If below the speed limit, or above the limit but facing away from the velocity,
	## move the player, adding an assisting force if turning. If above the speed limit,
	## and facing the velocity, add a force perpendicular to the velocity and scale
	## it based on where the player is moving in relation to the velocity.
	##
	# Get the angle between the velocity and current movement vector and convert it to degrees
	var angle = nvel2.angle_to(move2)
	var theta: float = rad_to_deg(angle)  # Angle between 2D look and velocity vectors
	var is_below_speed_limit: bool = is_player_below_speed_limit(nvel, vel)
	var is_below_danger_speed_limit: bool = is_player_below_danger_speed_limit(vel)
	if is_below_danger_speed_limit:
		var is_facing_velocity: bool = nvel2.dot(move2) >= 0
		var direction: Vector3  # vector to be set 90 degrees either to the left or right of the velocity
		var move_scale: float  # Scaled from 0 to 1. Used for both turn assist interpolation and vector scaling
		# If the angle is to the right of the velocity
		if theta > 0 and theta < 90:
			direction = nvel.cross(head.transform.basis.y)  # Vecor 90 degrees to the right of velocity
			move_scale = clamp(theta / turning_scale, 0, 1)  # Turn assist scale
		# If the angle is to the left of the velocity
		elif theta < 0 and theta > -90:
			direction = head.transform.basis.y.cross(nvel)  # Vecor 90 degrees to the left of velocity
			move_scale = clamp(-theta / turning_scale, 0, 1)
		# Prevent continuous sliding down steep walkable slopes when the player isn't moving. Could be made better with
		# debouncing because too high of a force also affects stopping distance noticeably when not on a slope.
		if move == Vector3(0, 0, 0) and is_grounded:
			move = -vel / (mass * 100 / anti_slide_force)
			move_player(move, state)
		# If not pushing into an unwalkable slope
		elif upper_slope_normal.y > walkable_normal:
			# If the player is below the speed limit, or is above it, but facing away from the velocity
			if is_below_speed_limit or not is_facing_velocity:
				# Interpolate between the movement and velocity vectors, scaling with turn assist sensitivity
				move = move.lerp(direction, move_scale)
			# If the player is above the speed limit, and looking within 90 degrees of the velocity
			else:
				move = direction  # Set the move vector 90 to the right or left of the velocity vector
				move *= move_scale  # Scale the vector. 0 if looking at velocity, up to full magnitude if looking 90 degrees to the side.
			move_player(move, state)
		# If pushing into an unwalkable slope, move with unscaled movement vector. Prevents turn assist from pushing the player into the wall.
		elif is_below_speed_limit:
			move_player(move, state)
		### End movement

		# Shotgun jump test
		if Input.is_action_just_pressed("fire"):
			var dir: Vector3 = camera.global_transform.basis.z  # Opposite of look direction
			state.apply_central_force(dir * 2700)


### Functions ###
# Gets the velocity of a contacted rigidbody at the point of contact with the player capsule
func get_contacted_body_velocity_at_point(
	input_contacted_body: RigidBody3D, contact_position: Vector3
):
	# Global coordinates of contacted body
	var body_position = input_contacted_body.transform.origin
	# Global coordinates of the point of contact between the player and contacted body
	var global_contact_position = body_position + contact_position
	# Calculate local velocity at point (cross product of angular velocity and contact position vectors)
	var local_vel_at_point = input_contacted_body.get_angular_velocity().cross(
		global_contact_position - body_position
	)
	# Add the current velocity of the contacted body to the velocity at the contacted point
	return input_contacted_body.get_linear_velocity() + local_vel_at_point


# Return 4 cross products of b with a
func cross4(a, b):
	return a.cross(b).cross(b).cross(b).cross(b)


# Whether a slope is walkable
func is_walkable(normal):
	return normal >= walkable_normal  # Lower normal means steeper slope


# Whether the player is below the speed limit in the direction they're traveling
func is_player_below_speed_limit(nvel, vel) -> bool:
	return (
		(nvel.x >= 0 and vel.x < nvel.x * current_speed_limit)
		or (nvel.x <= 0 and vel.x > nvel.x * current_speed_limit)
		or (nvel.z >= 0 and vel.z < nvel.z * current_speed_limit)
		or (nvel.z <= 0 and vel.z > nvel.z * current_speed_limit)
		or (nvel.x == 0 or nvel.z == 0)
	)


func is_player_below_danger_speed_limit(vel) -> bool:
	return (
		abs(vel.x) < danger_speed_limit
		and abs(vel.y) < danger_speed_limit
		and abs(vel.z) < danger_speed_limit
	)


# Move the player
func move_player(move, state):
	var draw_start = self.position - Vector3(0, capsule.height / 2, 0) + move  # debug
	if is_grounded:
		var direct_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state

		# Raycast to get slope
		# Start at the edge of the cylinder of the capsule in the movement direction
		var start = (self.position - Vector3(0, capsule.height / 2, 0)) + (move * capsule.radius)
		var end = start + Vector3.DOWN * 200
		# Some Godot 3 to 4 conversion information can be found at:
		# https://www.reddit.com/r/godot/comments/u0fboh/comment/idtoz30/?utm_source=share&utm_medium=web2x&context=3
		var params: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
		params.from = start
		params.to = end
		params.exclude = [self]
		var hit = direct_state.intersect_ray(params)
		var use_normal: Vector3
		# If the slope in front of the player movement direction is steeper than the
		# shallowest contact, use the steepest contact normal to calculate the movement slope
		if hit and hit.normal.y < lower_slope_normal.y:
			use_normal = upper_slope_normal
		else:
			use_normal = lower_slope_normal

		move = cross4(move, use_normal)  # Get slope to move along based on contact
		if debug:
			ld.DrawLine(draw_start, draw_start + move * capsule.radius, Color(1, 0, 0), 2)  # debug
		state.apply_central_force(move * accel)
		# Account for equal and opposite reaction when accelerating on ground
		if contacted_body != null:
			contacted_body.apply_force(state.get_contact_collider_position(0), move * -accel)
	else:
		if debug:
			ld.DrawLine(draw_start, draw_start + move * capsule.radius, Color(0, 0, 1), 2)  # debug
		state.apply_central_force(move * air_control)


# Set player friction
func set_friction(_move):
	player_physics_material.friction = local_friction
	# If moving or not grounded, reduce friction
	if not is_grounded:
		player_physics_material.friction = local_friction / friction_divider


# Get movement vector based on input, relative to the player's head transform
func relative_input():
	# Initialize the movement vector
	var move: Vector3 = Vector3()
	# Get cumulative input on axes
	var input: Vector3 = Vector3()
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		input.z += int(Input.is_action_pressed("move_forward"))
		input.z -= int(Input.is_action_pressed("move_backward"))
		input.x += int(Input.is_action_pressed("move_right"))
		input.x -= int(Input.is_action_pressed("move_left"))
		# Add input vectors to movement relative to the direction the head is facing
		move += input.z * -head.transform.basis.z
		move += input.x * head.transform.basis.x
	# Normalize to prevent stronger diagonal forces
	return move.normalized()


#
func grow_capsule(_is_done_shrinking, player_scale, move_camera):
	_is_done_shrinking = false
	if capsule.height < original_height:
		capsule.height += player_scale
		camera.position.y += move_camera
