extends Button

func _ready():
	pressed.connect(_on_pressed)

func _on_pressed():
	# Sin este guard, el jugador podía abrir el panel OS ENCIMA de un
	# diálogo activo — GestorUI.modo_actual pisado a OS sin que PanelDialogo
	# se enterara, y el diálogo quedaba huérfano (pedido: el diálogo es
	# obligatorio mientras dura).
	if GestorUI.modo_actual == GestorUI.Modo.DIALOGO:
		return
	var main_os = get_tree().get_root().find_child("OsPrincipal", true, false)
	if main_os:
		main_os._on_shortcut_os()
