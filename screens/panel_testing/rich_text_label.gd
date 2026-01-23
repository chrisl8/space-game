extends RichTextLabel

func _ready() -> void:
    var screen_text: String = Globals.remote_admin_screen_strings["panel_testing"]["screen_text"]
    text = screen_text

func _process(_delta: float) -> void:
    # TODO: Should this be an RPC instead?
    var screen_text: String = Globals.remote_admin_screen_strings["panel_testing"]["screen_text"]
    text = screen_text