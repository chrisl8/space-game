extends Node3D


func _on_static_body_3d_input_event(
	_camera: Node,
	event: InputEvent,
	_position: Vector3,
	_normal: Vector3,
	_shape_idx: int,
	button_index: int
) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed == true:
			print("Left Mouse Button Clicked on Button ", button_index)
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed == false:
			print("Left Mouse Button Released on Button ", button_index)
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed == true:
			print("Right Mouse Button Clicked on Button ", button_index)
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed == false:
			print("Right Mouse Button Released on Button ", button_index)
		if event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed == true:
			print("Middle Mouse Button Clicked on Button ", button_index)
		if event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed == false:
			print("Middle Mouse Button Released on Button ", button_index)
		if event.button_index == MOUSE_BUTTON_LEFT and event.double_click == true:
			print("Left Mouse Button Double Clicked on Button ", button_index)
