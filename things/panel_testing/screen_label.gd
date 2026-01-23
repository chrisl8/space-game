extends Label3D

func _ready() -> void:
    var screen_label: String = Globals.remote_admin_screen_strings["panel_testing"]["title"]
    text = screen_label

func _process(_delta: float) -> void:
    # TODO: Should this be an RPC instead?
    var screen_label: String = Globals.remote_admin_screen_strings["panel_testing"]["title"]
    text = screen_label