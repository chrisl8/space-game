extends Node2D

var IsLocal: bool = false


func Initialize(Local: bool):
	IsLocal = Local
	set_process(IsLocal)
	
	#
	set_process(IsLocal)
	set_process_input(IsLocal)
	set_process_internal(IsLocal)
	set_process_unhandled_input(IsLocal)
	set_process_unhandled_key_input(IsLocal)
	set_physics_process(IsLocal)
	set_physics_process_internal(IsLocal)
	#

func _process(_delta: float) -> void:
	if (
		Input.is_action_just_pressed(&"interact")
	):
		Globals.WorldMap.ModifyCell(Vector2i(randi_range(-50,50),randi_range(0,-50)), Vector2i(1,1))

const mouse_sensitivity = 10
func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == 1 and event.is_pressed():
			if(!mouse_left_down):
				LeftMouseClicked()
			mouse_left_down = true
		elif event.button_index == 1 and not event.is_pressed():
			mouse_left_down = false
		elif event.button_index == 2 and event.is_pressed():
			RightMouseClicked()
	
	if (event is InputEventMouseMotion):
		MousePosition = event.position

var mouse_left_down: bool
var MousePosition: Vector2
func LeftMouseClicked():
	Globals.WorldMap.MineCellAtPosition(get_global_mouse_position())
	pass
func RightMouseClicked():
	Globals.WorldMap.PlaceCellAtPosition(get_global_mouse_position())
	pass
