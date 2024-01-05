extends Node2D

var IsLocal: bool = false

@export var Arm: Node2D

@export var ArmRotation: float

var CurrentTool: int = 1

const InteractRange: float = 200.0

@export var DebugObject: Resource = preload("res://player/Debug Object.tscn")

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

	DebugObject.instantiate()

func _process(_delta: float) -> void:
	#Need to confirm this works across computers
	if(IsLocal):
		MousePosition = get_global_mouse_position()
		if Input.is_action_just_pressed(&"interact"):
			Globals.WorldMap.ModifyCell(
				Vector2i(randi_range(-50, 50), randi_range(0, -50)), Vector2i(1, 1)
			)
		Arm.look_at(MousePosition)
		ArmRotation = Arm.rotation
		ArmDirection = Vector2(0, 1).rotated(Arm.global_rotation)
		#print(ArmDirection)
		CurrentMiningTime = clamp(CurrentMiningTime+_delta, 0.0, 100.0)
		if(mouse_left_down):
			MineRaycast()
	else:
		Arm.rotation = ArmRotation


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

	if event is InputEventMouseMotion:
		MousePosition = event.position


var mouse_left_down: bool
var MousePosition: Vector2
var MineCast: RayCast2D
var ArmDirection: Vector2

var MiningSpeed: float = 0.1
var CurrentMiningTime = 100

func LeftMouseClicked():
	if(CurrentTool == 1):
		pass
	pass

func MineRaycast():
	if(CurrentMiningTime > MiningSpeed):
		CurrentMiningTime = 0.0
		var space_state = get_world_2d().direct_space_state
		
		
		#var Object = DebugObject.instantiate()
		#get_node("/root").add_child(Object)
		#Object.global_position = Arm.global_position


		


		var query = PhysicsRayQueryParameters2D.create(Arm.global_position, Arm.global_position + Arm.global_transform.x*InteractRange)
		query.exclude = [self]
		var result = space_state.intersect_ray(query)
		if(len(result) > 0):
			if(result["collider"] is TileMap):
				Globals.WorldMap.MineCellAtPosition(result["position"] - result["normal"]*0.001)

func RightMouseClicked():
	Globals.WorldMap.PlaceCellAtPosition(get_global_mouse_position())
	pass
