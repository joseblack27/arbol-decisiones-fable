extends Button

func _ready():
	pressed.connect(_on_pressed)

func _on_pressed():
	var main_os = get_tree().get_root().find_child("OsPrincipal", true, false)
	if main_os:
		main_os._on_shortcut_os()
