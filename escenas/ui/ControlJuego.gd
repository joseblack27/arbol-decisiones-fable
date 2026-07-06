extends Control

func _ready():
	GestorUI.modo_cambiado.connect(_on_modo_cambiado)

func _on_modo_cambiado(modo: int) -> void:
	if modo == GestorUI.Modo.JUEGO:
		process_mode = Node.PROCESS_MODE_INHERIT
	else:
		process_mode = Node.PROCESS_MODE_DISABLED
