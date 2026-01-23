extends Node3D

var button_panel_labels: Dictionary = {
	"Key_000": {"id": 1},
	"Key_001": {"id": 2},
	"Key_002": {"id": 3},
	"Key_003": {"id": 4},
	"Key_004": {"id": 5},
	"Key_005": {"id": 6},
	"Key_006": {"id": 7},
	"Key_007": {"id": 8},
	"Key_008": {"id": 9},
	"Key_009": {"id": 10},
	"Key_010": {"id": 11},
	"Key_011": {"id": 12},
	"Key_012": {"id": 13},
	"Key_013": {"id": 14},
	"Key_014": {"id": 15},
	"Key_015": {"id": 16},
	"Key_016": {"id": 17},
	"Key_017": {"id": 18},
	"Key_018": {"id": 19},
	"Key_019": {"id": 20},
	"Key_020": {"id": 21},
	"Key_021": {"id": 22},
	"Key_022": {"id": 23},
	"Key_023": {"id": 24},
	"Key_024": {"id": 25},
	"Key_025": {"id": 26},
	"Key_026": {"id": 27},
	"Key_027": {"id": 28},
	"Key_028": {"id": 29},
	"Key_029": {"id": 30},
	"Key_030": {"id": 31},
	"Key_031": {"id": 32},
	"Key_032": {"id": 33},
	"Key_033": {"id": 34},
	"Key_034": {"id": 35},
	"Key_035": {"id": 36},
	"Key_036": {"id": 37},
	"Key_037": {"id": 38},
	"Key_038": {"id": 39},
	"Key_039": {"id": 40},
	"Key_040": {"id": 41},
	"Key_041": {"id": 42},
	"Key_042": {"id": 43},
	"Key_043": {"id": 44},
	"Key_044": {"id": 45},
	"Key_045": {"id": 46},
	"Key_046": {"id": 47},
	"Key_047": {"id": 48},
	"Key_048": {"id": 49},
	"Key_049": {"id": 50},
	"Key_050": {"id": 51},
	"Key_051": {"id": 52},
}

@onready var things_spawning_node: Node = get_node("/root/Main/Things")

var starting_position: float = 0.0 # Sometimes you want to button to start out offset from what was in the mesh, so you can offset it here.
var pushed_position: float = 0.02 # How far the button is pushed down when pressed.

# Note that depending on the mesh, you may need to change `.y` to `.z` or `.x` throughout this file.


func _ready() -> void:
	# set_screen_text("Enter Code\nto\nVEND\nstuff")
	var button_nodes: Array = get_node("mesh/Scene Collection/Collection/Keys").get_children()
	for button_node: Node3D in button_nodes:
		if button_panel_labels.has(button_node.name) and button_node.has_node("StaticBody3D"):
			var button_static_body_node: Node3D = button_node.get_node("StaticBody3D")
			# Inset all activated buttons slightly to start with.
			button_node.position.y = button_node.position.y - starting_position
			button_panel_labels[button_node.name].original_button_position = (
				button_static_body_node.position
			)
			(
				button_static_body_node
				.input_event
				.connect(
					(
						_on_static_body_3d_input_event
						.bind(
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
		button_node.position.y = (
			button_panel_labels[button_node_name].original_button_position.y - pushed_position
		)
		await get_tree().create_timer(0.25).timeout
		button_node.position.y = (
			button_panel_labels[button_node_name].original_button_position.y - starting_position
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
				# set_screen_text.rpc(str(thing_name_to_vend, "!"))
				Helpers.log_print(str(thing_name_to_vend, "!"))
				# Spawner.place_thing(
				# 	str(thing_name_to_vend, "-", thing_id_to_vend), Vector3(17.5, 3.0, -13.7)
				# )
			# else:
				# set_screen_text.rpc(str("No ", thing_name_to_vend, "! =("))
			# TODO: Clear screen after a delay.
		# else:
			# set_screen_text.rpc(str(button_index))


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
	screen = get_node_or_null("PanelTesting/PanelTestingScreen/SubViewport/Control/RichTextLabel")
	Helpers.log_print("screen_text: " + text + " screen: " + str(screen))
	screen.text = text
