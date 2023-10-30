extends Node3D

var button_panel_labels: Dictionary = {
	"Left Panel001": {"id": 15},
	"Left Panel002": {"id": 5},
	"Left Panel003": {"id": 11},
	"Left Panel004": {"id": 13},
	"Left Panel005": {"id": 4},
	"Left Panel006": {"id": 2},
	"Left Panel007": {"id": 10},
	"Left Panel008": {"id": 7},
	"Left Panel009": {"id": 6},
	"Left Panel010": {"id": 8},
	"Left Panel011": {"id": 1},
	"Left Panel012": {"id": 14},
	"Left Panel013": {"id": 3},
	"Left Panel014": {"id": 9},
	"Left Panel015": {"id": 12},
}


func _ready() -> void:
	set_screen_text("Enter Code\nto\nVEND\nstuff")
	var button_nodes: Array = get_node("./root/Left Panel016/").get_children()
	for button_node: Node3D in button_nodes:
		if button_panel_labels.has(button_node.name) and button_node.has_node("StaticBody3D"):
			var button_static_body_node: Node3D = button_node.get_node("StaticBody3D")
			# Inset all activated buttons slightly to start with.
			button_node.position.z = button_node.position.z - 0.01
			button_panel_labels[button_node.name].original_button_position = (
				button_static_body_node.position
			)
			(
				button_static_body_node
				. input_event
				. connect(
					(
						_on_static_body_3d_input_event
						. bind(
							button_node.name,
							button_panel_labels[button_node.name].id,
							button_node.get_path(),
						)
					)
				)
			)


@rpc() func depress_button(button_node_name: String, button_node_path: NodePath) -> void:
	var button_node: Node = get_node_or_null(button_node_path)
	if button_node:
		# TODO: this should happen on the server which means:
		# RPC calls
		# Server controls position and position is synced
		# Server does the needful in response to the button input
		button_node.position.z = (
			button_panel_labels[button_node_name].original_button_position.z - 0.02
		)
		await get_tree().create_timer(0.25).timeout
		button_node.position.z = (
			button_panel_labels[button_node_name].original_button_position.z - 0.01
		)


@rpc("any_peer") func server_button_clicked(
	button_node_name: String, button_index: int, button_node_path: NodePath
) -> void:
	if Globals.is_server:
		depress_button.rpc(button_node_name, button_node_path)
		set_screen_text.rpc(str(button_index))


func _on_static_body_3d_input_event(
	_camera: Node,
	event: InputEvent,
	_position: Vector3,
	_normal: Vector3,
	_shape_idx: int,
	button_node_name: String,
	button_index: int,
	button_node_path: NodePath,
) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed == true:
			server_button_clicked.rpc(button_node_name, button_index, button_node_path)


@rpc() func set_screen_text(text: String) -> void:
	var screen: Node3D = get_node("./root/Left Panel016/Screen/Screen Text")
	screen.text = text
