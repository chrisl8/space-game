extends Node3D


func _ready() -> void:
	# Commenting these out during Godot 4.1 to 4.2 conversion testing
	# as these meshes don't exist in the old 4.1 scenes.
#	var test_node: Node3D = get_node("./root/Left Panel016/Left Panel011")
#	var original_button_position: Vector3 = test_node.position
#	get_node("./root/Left Panel016/Left Panel011/StaticBody3D").input_event.connect(
#		_on_static_body_3d_input_event.bind(1, test_node.get_path(), original_button_position)
#	)
#	get_node("./root/Left Panel016/Left Panel006/StaticBody3D").input_event.connect(
#		_on_static_body_3d_input_event.bind(2)
#	)
	get_node("./root/Left Panel016/Left Panel001/StaticBody3D").input_event.connect(
		_on_static_body_3d_input_event.bind(15)
	)


func _on_static_body_3d_input_event(
	_camera: Node,
	event: InputEvent,
	_position: Vector3,
	_normal: Vector3,
	_shape_idx: int,
	button_index: int,
	button_node_path: NodePath,
	original_button_position: Vector3
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
		var button_node: Node = get_node_or_null(button_node_path)
		if button_node:
			button_node.position.z = original_button_position.z - 0.01
