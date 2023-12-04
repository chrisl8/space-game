extends Node3D

var button_panel_labels: Dictionary = {
	"Button01": {"id": 1},
	"Button02": {"id": 2},
	"Button03": {"id": 3},
	"Button04": {"id": 4},
	"Button05": {"id": 5},
	"Button06": {"id": 6},
	"Button07": {"id": 7},
	"Button08": {"id": 8},
	"Button09": {"id": 9},
	"Button10": {"id": 10},
	"Button11": {"id": 11},
	"Button12": {"id": 12},
	"Button13": {"id": 13},
	"Button14": {"id": 14},
	"Button15": {"id": 15},
}

@onready var things_spawning_node: Node = get_node("/root/Main/Things")


func _ready() -> void:
	set_screen_text("Enter Code\nto\nVEND\nstuff")
	var button_nodes: Array = get_node("Mesh/VendingMachineMesh/Left Panel").get_children()
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


@rpc()
func depress_button(button_node_name: String, button_node_path: NodePath) -> void:
	var button_node: Node = get_node_or_null(button_node_path)
	if button_node:
		button_node.position.z = (
			button_panel_labels[button_node_name].original_button_position.z - 0.02
		)
		await get_tree().create_timer(0.25).timeout
		button_node.position.z = (
			button_panel_labels[button_node_name].original_button_position.z - 0.01
		)


@rpc("any_peer")
func server_button_clicked(
	button_node_name: String, button_index: int, button_node_path: NodePath
) -> void:
	if Globals.is_server:
		depress_button.rpc(button_node_name, button_node_path)
		var thing_name_to_vend: String = ""
		match button_index:
			1:
				thing_name_to_vend = "Fish"
			2:
				thing_name_to_vend = "Ball"
			3:
				thing_name_to_vend = "Chair"
		if thing_name_to_vend != "":
			# Item vending test
			var thing_id_to_vend: int = 0
			for thing: int in range(1, 10):
				var existing_thing: Node = things_spawning_node.get_node_or_null(
					str(thing_name_to_vend, "-", thing)
				)
				if !existing_thing:
					thing_id_to_vend = thing
					continue
			if thing_id_to_vend > 0:
				set_screen_text.rpc(str(thing_name_to_vend, "!"))
				Helpers.log_print(str(thing_name_to_vend, "!"))
				Spawner.place_thing(
					str(thing_name_to_vend, "-", thing_id_to_vend), Vector3(17.5, 3.0, -13.7)
				)
			else:
				set_screen_text.rpc(str("No ", thing_name_to_vend, "! =("))
			# TODO: Clear screen after a delay.
		else:
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
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Prevent startup.gd _unhandled_input from responding to this click.
			# _unhandled_input fires BEFORE Collider inputs
			# https://docs.godotengine.org/en/stable/tutorials/inputs/inputevent.html#how-does-it-work
			Globals.last_click_handled_time = int(Time.get_unix_time_from_system())
			server_button_clicked.rpc(button_node_name, button_index, button_node_path)


@rpc()
func set_screen_text(text: String) -> void:
	var screen: Node3D = get_node_or_null("Screen Text")
	screen.text = text
