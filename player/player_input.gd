extends MultiplayerSynchronizer

@export var input_axis := Vector2()

# Set via RPC to simulate is_action_just_pressed.
@export var jumping := false

func _ready():
	# Only process for the local player
	set_process(get_multiplayer_authority() == multiplayer.get_unique_id())

@rpc("call_local")
func jump():
	jumping = true

func _process(_delta):
	input_axis = Input.get_vector(&"move_back", &"move_forward",
	&"move_left", &"move_right")

	if Input.is_action_just_pressed(&"jump"):
		jump.rpc()
