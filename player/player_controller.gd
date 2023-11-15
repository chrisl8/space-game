extends RigidBody3D

# The entire Rigidbody based Character Controller here is based on code found at https://github.com/FreeFlyFall/RigidBodyController

enum { TIPTOEING, WALKING, SPRINTING }  # Possible values for posture

# Set the player ID, which is only used in _ready(),
# and perhaps by others via the MultiplayerSynchronizer, but I'm not sure on that.
@export var player: int = -1
@export var accel: int  # Player acceleration force
@export var jump: int  # Jump force multiplier
@export var air_control: int  # Air control multiplier
@export var turning_scale: float  # How quickly to scale movement towards a turning direction. Lower is more. # (float, 15, 120, 1)
@export var mouse_sensitivity: float = 0.05  # 0.05
@export var walkable_normal: float  # 0.35 # Walkable slope. Lower is steeper # (float, 0, 1, 0.01)
@export var height_adjust_speed: float
@export var speed_limit: float  # 8 # Default speed limit of the player
@export var sprinting_speed_limit: float  # 12 # Speed to move at while sprinting
@export var danger_speed_limit: float  # Maximum speed limit
@export var friction_divider: int = 6  # Amount to divide the friction by when not grounded (prevents sticking to walls from air control)
@export var jump_throttle: float = 0.1  # 0.1 # Stores preference for time before the player can jump again # (float,0.01,1,0.01)
@export var landing_assist: float  # 1.5 # Downward force to apply when letting go of space while jumping
@export var anti_slide_force: float  # 3 # Amount of force to stop sliding with # (float,0.1,100,0.1)
@export var player_spawn_point: Vector3 = Vector3(4, 1.5, -4)
@export var bounds_distance: int = 100

var Chair: Resource = preload("res://things/held/chair/chair.tscn")

var is_grounded: bool  # Whether the player is considered to be touching a walkable slope

var upper_slope_normal: Vector3  # Stores the lowest (steepest) slope normal
var lower_slope_normal: Vector3  # Stores the highest (flattest) slope normal
var slope_normal: Vector3  # Stores normals of contact points for iteration
var contacted_body: RigidBody3D  # Rigid body the player is currently contacting, if there is one
var player_physics_material: Resource = load("res://Physics/player.tres")
var is_landing: bool = true  # Whether the player has jumped and let go of jump
var is_jumping: bool = false  # Whether the player has jumped
var current_jump_throttle: float  # Variable used with jump throttling calculations

### Physics process vars
var original_player_collider_height: float
var original_head_position_y: float
var original_foot_position_y: float
var minimum_player_collider_height: float = 1.0
var maximum_player_collider_height: float = 3.0
var current_speed_limit: float
var posture: int  # Current posture state

## Object Interaction vars
var is_interacting: bool = false

var character_trimmed: bool = false
var selected_node: Node3D
var held_item: Node

@onready var player_collider: Shape3D = $Collision.shape  # Capsule collision shape of the player
@onready var head: Node3D = $Head  # y-axis rotation node (look left and right)
@onready var camera: Node = get_node("./Head/Camera3D")  # Camera3D node
@onready var head_mesh: Node = get_node("./Head/HeadMesh")  # x-axis rotation node (look up and down)
@onready var character_meshes: Node3D = $Character
@onready var original_friction: float = player_physics_material.friction  # Editor friction value
@onready var original_linear_damp: float = linear_damp
@onready var original_accel: int = accel
@onready var holding_things_joint: Node = get_node("./Joint")


func _ready() -> void:
	# NOTE: At this point this player is still under server authority, because the server cannot give the remote game
	# authority quite yet. That happens in the function _on_players_spawner_spawned() in startup.gd
	# This means that you cannot rely on get_multiplayer_authority() yet!
	# Otherwise, this might be the ONLY place that we need to use the player variable, although this also allows
	# us to pass it to other players via MultiplayerSynchronizer although I also don't know if that is required?
	if player == multiplayer.get_unique_id():
		camera.make_current()

	# Set capsule variables for use later
	original_player_collider_height = player_collider.height
	original_head_position_y = head.position.y
	original_foot_position_y = $Character.get_node("Foot").position.y


func _input(event: InputEvent) -> void:
	# Player look
	if (
		Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
		and event is InputEventMouseMotion
		and get_multiplayer_authority() == multiplayer.get_unique_id()
	):
		# Rotate entire head on y axis
		apply_torque(Vector3(0, -event.relative.x * mouse_sensitivity * 10, 0))
		var camera_head_x_rotation: float = deg_to_rad(-event.relative.y * mouse_sensitivity)
		# Rotate camera on x axis
		# Limit to prevent flipping camera/head
		camera.rotate_x(camera_head_x_rotation)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-60), deg_to_rad(50))
		# Also rotate head on x axis for visual
		# Limit more strictly so head doesn't clip into body
		head_mesh.rotate_x(camera_head_x_rotation)
		head_mesh.rotation.x = clamp(head_mesh.rotation.x, deg_to_rad(-25), deg_to_rad(25))


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

	if (
		get_multiplayer_authority() == multiplayer.get_unique_id()
		and Input.is_action_just_pressed(&"interact")
	):
		is_interacting = true

	# Grabbing Things
	if is_interacting:
		_grab_or_drop()
	is_interacting = false


func _physics_process(delta: float) -> void:
	### Player posture FSM
	if Input.is_action_pressed("sprint"):
		posture = SPRINTING
	elif Input.is_action_pressed("tiptoe"):
		posture = TIPTOEING
	else:
		posture = WALKING

	### Groundedness raycasts
	# Define raycast info used with detecting groundedness
	var raycast_list: Array = Array()  # List of raycasts used with detecting groundedness
	var bottom: float = 0.1  # Distance down from start to fire the raycast to
	var start: float = (player_collider.height / 2 + player_collider.radius) - 0.05  # Start point down from the center of the player to start the raycast
	var cv_dist: float = player_collider.radius - 0.1  # Cardinal vector distance.
	var ov_dist: float = cv_dist / sqrt(2)  # Ordinal vector distance. Added to 2 cardinal vectors to result in a diagonal with the same magnitude of the cardinal vectors
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
		var loc2: Vector3 = loc
		loc2.y -= bottom
		var debug_color: Color = Color.BLUE
		if i > 3:
			debug_color = Color.RED
		# Add the two points for this iteration to the list for the raycast
		raycast_list.append([loc, loc2, debug_color])
	# Check each raycast for collision, ignoring the capsule itself
	for array: Array in raycast_list:
		var params: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
		params.from = array[0]
		params.to = array[1]
		params.exclude = [self]
		var collision: Dictionary = direct_state.intersect_ray(params)
		# The player is grounded if any of the raycasts hit
		if collision and is_walkable(collision.normal.y):
			is_grounded = true
		# NOTICE: See Readme.MD about obtaining DebugDraw if you want to use it.
		#DebugDraw3D.draw_line(params.from, params.to, array[2])  #$"Lines/2".global_transform.origin,  #target.global_transform.origin,

	### Sprinting & Tiptoeing
	match posture:
		SPRINTING:
			accel = original_accel
			linear_damp = original_linear_damp
			current_speed_limit = sprinting_speed_limit
		TIPTOEING:
			accel = original_accel / 2
			linear_damp = original_linear_damp * 10
			current_speed_limit = speed_limit / 2
		WALKING:
			accel = original_accel
			linear_damp = original_linear_damp
			current_speed_limit = speed_limit

	adjust_player_height(delta)

	# Setup jump throttle for integrate_forces
	if is_jumping or is_landing:
		current_jump_throttle -= delta
	else:
		current_jump_throttle = jump_throttle


func get_new_spawn_position() -> Vector3:
	var pos: Vector2 = Vector2.from_angle(randf() * 2 * PI)
	const SPAWN_RANDOM: float = 2.0
	return Vector3(
		player_spawn_point.x + (pos.x * SPAWN_RANDOM * randf()),
		player_spawn_point.y,
		player_spawn_point.z + (pos.y * SPAWN_RANDOM * randf())
	)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	# If we "fall out of the world" reset to spawn area
	if (
		abs(position.x) > bounds_distance
		or abs(position.y) > bounds_distance
		or abs(position.z) > bounds_distance
	):
		# Just in case player was shrinking or growing
		$Collision.shape.height = original_player_collider_height
		head.position.y = original_head_position_y
		update_player_collider_height.rpc($Collision.shape.height)

		# state.transform.origin appears to be the correct way
		# to teleport a rigidbody in _integrate_forces()
		state.transform.origin = get_new_spawn_position()
		return

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
				var contact_position: Vector3 = state.get_contact_collider_position(0)  # coords of the contact point from center of contacted body
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
		and current_jump_throttle < 0
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
	var move: Vector3 = relative_input()  # Get movement vector relative to player orientation
	var move2: Vector2 = Vector2(move.x, move.z)  # Convert movement for Vector2 methods

	# set_friction(move)

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
	var nvel: Vector3 = vel.normalized()
	var nvel2: Vector2 = Vector2(nvel.x, nvel.z)  # 2D velocity vector to use with angle_to and dot methods

	## If below the speed limit, or above the limit but facing away from the velocity,
	## move the player, adding an assisting force if turning. If above the speed limit,
	## and facing the velocity, add a force perpendicular to the velocity and scale
	## it based on where the player is moving in relation to the velocity.
	##
	# Get the angle between the velocity and current movement vector and convert it to degrees
	var angle: float = nvel2.angle_to(move2)
	var theta: float = rad_to_deg(angle)  # Angle between 2D look and velocity vectors
	var is_below_speed_limit: bool = is_player_below_speed_limit(nvel, vel)
	var is_below_danger_speed_limit: bool = is_player_below_danger_speed_limit(vel)
	if is_below_danger_speed_limit:
		var is_facing_velocity: bool = nvel2.dot(move2) >= 0
		var direction: Vector3  # vector to be set 90 degrees either to the left or right of the velocity
		var move_scale: float  # Scaled from 0 to 1. Used for both turn assist interpolation and vector scaling
		# If the angle is to the right of the velocity
		if theta > 0 and theta < 90:
			direction = nvel.cross(transform.basis.y)  # Vecor 90 degrees to the right of velocity
			move_scale = clamp(theta / turning_scale, 0, 1)  # Turn assist scale
		# If the angle is to the left of the velocity
		elif theta < 0 and theta > -90:
			direction = transform.basis.y.cross(nvel)  # Vecor 90 degrees to the left of velocity
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
) -> Vector3:
	# Global coordinates of contacted body
	var body_position: Vector3 = input_contacted_body.transform.origin
	# Global coordinates of the point of contact between the player and contacted body
	var global_contact_position: Vector3 = body_position + contact_position
	# Calculate local velocity at point (cross product of angular velocity and contact position vectors)
	var local_vel_at_point: Vector3 = input_contacted_body.get_angular_velocity().cross(
		global_contact_position - body_position
	)
	# Add the current velocity of the contacted body to the velocity at the contacted point
	return input_contacted_body.get_linear_velocity() + local_vel_at_point


# Return 4 cross products of b with a
func cross4(a: Vector3, b: Vector3) -> Vector3:
	return a.cross(b).cross(b).cross(b).cross(b)


# Whether a slope is walkable
func is_walkable(normal: float) -> bool:
	return normal >= walkable_normal  # Lower normal means steeper slope


# Whether the player is below the speed limit in the direction they're traveling
func is_player_below_speed_limit(nvel: Vector3, vel: Vector3) -> bool:
	return (
		(nvel.x >= 0 and vel.x < nvel.x * current_speed_limit)
		or (nvel.x <= 0 and vel.x > nvel.x * current_speed_limit)
		or (nvel.z >= 0 and vel.z < nvel.z * current_speed_limit)
		or (nvel.z <= 0 and vel.z > nvel.z * current_speed_limit)
		or (nvel.x == 0 or nvel.z == 0)
	)


func is_player_below_danger_speed_limit(vel: Vector3) -> bool:
	return (
		abs(vel.x) < danger_speed_limit
		and abs(vel.y) < danger_speed_limit
		and abs(vel.z) < danger_speed_limit
	)


# Move the player
func move_player(move: Vector3, state: PhysicsDirectBodyState3D) -> void:
	if is_grounded:
		var direct_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state

		# Raycast to get slope
		# Start at the edge of the cylinder of the capsule in the movement direction
		var start: Vector3 = (
			(self.position - Vector3(0, player_collider.height / 2, 0))
			+ (move * player_collider.radius)
		)
		var end: Vector3 = start + Vector3.DOWN * 200
		# Some Godot 3 to 4 conversion information can be found at:
		# https://www.reddit.com/r/godot/comments/u0fboh/comment/idtoz30/?utm_source=share&utm_medium=web2x&context=3
		var params: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
		params.from = start
		params.to = end
		params.exclude = [self]
		var hit: Dictionary = direct_state.intersect_ray(params)
		# NOTICE: See Readme.MD about obtaining DebugDraw if you want to use it.
		#DebugDraw3D.draw_line(params.from, params.to, Color.GREEN)  #$"Lines/2".global_transform.origin,  #target.global_transform.origin,
		var use_normal: Vector3
		# If the slope in front of the player movement direction is steeper than the
		# shallowest contact, use the steepest contact normal to calculate the movement slope
		if hit and hit.normal.y < lower_slope_normal.y:
			use_normal = upper_slope_normal
		else:
			use_normal = lower_slope_normal

		move = cross4(move, use_normal)  # Get slope to move along based on contact
		state.apply_central_force(move * accel)
		# Account for equal and opposite reaction when accelerating on ground
		if contacted_body != null:
			contacted_body.apply_force(state.get_contact_collider_position(0), move * -accel)
	else:
		state.apply_central_force(move * air_control)


# Set player friction
func set_friction(_move: Vector3) -> void:
	player_physics_material.friction = original_friction
	# If moving or not grounded, reduce friction
	if not is_grounded:
		player_physics_material.friction = original_friction / friction_divider


# Get movement vector based on input, relative to the player's head transform
func relative_input() -> Vector3:
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
		move += input.z * -transform.basis.z
		move += input.x * transform.basis.x
	# Normalize to prevent stronger diagonal forces
	return move.normalized()


@rpc() func update_player_collider_height(height: float) -> void:
	if get_multiplayer_authority() == multiplayer.get_remote_sender_id():
		$Collision.shape.height = height


func adjust_player_height(delta: float) -> void:
	if get_multiplayer_authority() == multiplayer.get_unique_id():
		var height_scale: float = delta * height_adjust_speed  # Amount to change capsule height up or down
		if Input.is_action_pressed("grow"):
			#Helpers.log_print("GROW")
			# TODO: Account for local ceiling height and do not allow growing into it
			if player_collider.height < maximum_player_collider_height:
				$Collision.shape.height += height_scale
				# Head moves half the rate of the total growth,
				# because growth happens at both ends.
				head.position.y += height_scale / 2
				$Character.get_node("Foot").position.y -= height_scale / 2
				update_player_collider_height.rpc($Collision.shape.height)
		elif Input.is_action_pressed("shrink"):
			#Helpers.log_print("SHRINK")
			if player_collider.height > minimum_player_collider_height:
				$Collision.shape.height -= height_scale
				# Head moves half the rate of the total growth,
				# because growth happens at both ends.
				head.position.y -= height_scale / 2
				$Character.get_node("Foot").position.y += height_scale / 2
				update_player_collider_height.rpc($Collision.shape.height)
		elif Input.is_action_just_pressed("reset_player_height"):
			if player_collider.height != original_player_collider_height:
				#player_collider.height = original_player_collider_height
				$Collision.shape.height = original_player_collider_height
				head.position.y = original_head_position_y
				$Character.get_node("Foot").position.y = original_foot_position_y
				update_player_collider_height.rpc($Collision.shape.height)


func _on_personal_space_body_entered(body: Node3D) -> void:
	if body.has_method("select"):
		selected_node = body
		if get_multiplayer_authority() == multiplayer.get_unique_id():
			body.select(name)


func _on_personal_space_body_exited(body: Node3D) -> void:
	if body.has_method("unselect"):
		selected_node = null
		if get_multiplayer_authority() == multiplayer.get_unique_id():
			body.unselect(name)


# Spawning and dropping the "thing" must be an RPC because all "copies" of the player
# must do this to sync the view of them holding/not holding the thing across players views
# of this player.

@rpc("call_local") func _spawn_me_a_thing(grabbed_item_name: String) -> void:
	var parsed_thing_name: Dictionary = Helpers.parse_thing_name(grabbed_item_name)
	Helpers.log_print(
		str(
			parsed_thing_name.name,
			" ",
			parsed_thing_name.id,
			" picked up by ",
			multiplayer.get_remote_sender_id()
		),
		"Cornflowerblue"
	)
	# Spawn a local version for myself
	# This is similar to the thing spawning code in spawner()
	match parsed_thing_name.name:
		"Chair":
			held_item = Chair.instantiate()
		_:
			printerr(
				"Invalid thing to spawn name into player held position: ", parsed_thing_name.name
			)
			return
	held_item.name = grabbed_item_name
	holding_things_joint.add_child(held_item)
	holding_things_joint.node_a = NodePath("..")
	holding_things_joint.node_b = held_item.get_path()


@rpc("call_local") func _drop_held_thing() -> void:
	Helpers.log_print(
		str(held_item.name, " dropped by ", multiplayer.get_remote_sender_id()), "Cornflowerblue"
	)
	holding_things_joint.node_a = NodePath("")
	holding_things_joint.node_b = NodePath("")
	held_item.queue_free()
	held_item = null


func _grab_or_drop() -> void:
	if selected_node and not held_item and selected_node.has_method("grab"):
		Helpers.log_print(str("I picked up ", selected_node.name), "Cornflowerblue")
		# Tell the server version to delete itself
		var grabbed_item_name: String = selected_node.name

		selected_node.grab.rpc_id(1)
		# Spawn a held version in my hands
		_spawn_me_a_thing.rpc(grabbed_item_name)
	elif held_item:
		Helpers.log_print(str("I dropped ", held_item.name), "Cornflowerblue")
		# Let Go
		var held_item_name: String = held_item.name
		var held_item_global_position: Vector3 = held_item.global_position
		_drop_held_thing.rpc()
		Spawner.place_thing.rpc_id(1, held_item_name, held_item_global_position)
