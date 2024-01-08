extends Node2D

var IsLocal: bool = false

@export var Arm: Node2D

var CurrentTool: int = 1

const InteractRange: float = 200.0

@export var DebugObject: Resource = preload("res://player/Debug Object.tscn")

@export var MiningParticles: GPUParticles2D

@export var IsMining: bool = false

@export var MiningDistance: float = 0.0:
	set(new_value):
		MiningDistance = new_value
		UpdateMiningParticleLength()

var SpawnedDebugObject: Node2D


func UpdateMiningParticleLength():
	var Extents: Vector3 = MiningParticles.process_material.get("emission_box_extents")
	Extents.x = MiningDistance

	MiningParticles.process_material.set("emission_box_extents", Extents)
	MiningParticles.process_material.set("emission_shape_offset", Vector3(MiningDistance, 0.0, 0.0))
	MiningParticles.look_at(MousePosition)


@export var HeadTarget: Node


func Initialize(Local: bool):
	IsLocal = Local
	#set_process(IsLocal)

	#
	set_process_input(IsLocal)
	set_process_internal(IsLocal)
	set_process_unhandled_input(IsLocal)
	set_process_unhandled_key_input(IsLocal)
	set_physics_process(IsLocal)
	set_physics_process_internal(IsLocal)
	#

	SpawnedDebugObject = DebugObject.instantiate()
	get_node("/root").add_child(SpawnedDebugObject)


func _process(_delta: float) -> void:
	if IsLocal:
		MousePosition = get_global_mouse_position()
		if Input.is_action_just_pressed(&"interact"):
			Globals.WorldMap.ModifyCell(
				Vector2i(randi_range(-50, 50), randi_range(0, -50)), Vector2i(1, 1)
			)

		Arm.look_at(MousePosition)
		ArmDirection = Vector2(0, 1).rotated(Arm.global_rotation)

		CurrentMiningTime = clamp(CurrentMiningTime + _delta, 0.0, 100.0)
		if mouse_left_down:
			MineRaycast()
		IsMining = mouse_left_down
	else:
		#Yes need this twice till refactor
		Arm.look_at(MousePosition)
		if !Globals.is_server:
			#Arm.global_position = MousePosition
			SpawnedDebugObject.global_position = MousePosition

	if IsMining:
		MiningParticles.look_at(MousePosition)

	#HeadTarget.global_position = MousePosition
	MiningParticles.emitting = IsMining

	TestArmIKTargetDeleteLater.global_position = MousePosition
	SpawnedDebugObject.global_position = MousePosition


@export var TestArmIKTargetDeleteLater: Node2D

const mouse_sensitivity = 10


func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == 1 and event.is_pressed():
			if !mouse_left_down:
				LeftMouseClicked()
			mouse_left_down = true
		elif event.button_index == 1 and not event.is_pressed():
			mouse_left_down = false
		elif event.button_index == 2 and event.is_pressed():
			RightMouseClicked()


var mouse_left_down: bool
@export var MousePosition: Vector2

var MineCast: RayCast2D
var ArmDirection: Vector2

var MiningSpeed: float = 0.1
var CurrentMiningTime = 100


func LeftMouseClicked():
	if CurrentTool == 1:
		pass
	pass


func MineRaycast():
	if CurrentMiningTime > MiningSpeed:
		CurrentMiningTime = 0.0
		var space_state = get_world_2d().direct_space_state

		#var SpawnedDebugObject = DebugObject.instantiate()
		#get_node("/root").add_child(SpawnedDebugObject)
		#SpawnedDebugObject.global_position = Arm.global_position

		var MiningParticleDistance = InteractRange / 2.0
		var ArmPosition = Arm.global_position
		var query = PhysicsRayQueryParameters2D.create(
			ArmPosition, ArmPosition + Arm.global_transform.x * InteractRange
		)
		query.exclude = [self]
		var result = space_state.intersect_ray(query)
		if len(result) > 0:
			var HitPoint = result["position"]
			if result["collider"] is TileMap:
				Globals.WorldMap.MineCellAtPosition(HitPoint - result["normal"] * 0.001)
			MiningParticleDistance = MiningParticles.global_position.distance_to(HitPoint) / 2.0

		MiningDistance = MiningParticleDistance


func RightMouseClicked():
	Globals.WorldMap.PlaceCellAtPosition(get_global_mouse_position())
	pass
