extends Control

func _ready():
	GestorUI.modo_cambiado.connect(_on_modo_cambiado)

func _on_modo_cambiado(modo: int) -> void:
	if modo == GestorUI.Modo.JUEGO:
		process_mode = Node.PROCESS_MODE_INHERIT
	else:
		# Si el dedo sigue arrastrando el joystick justo cuando se abre un
		# diálogo, el panel OS o el chat (típico: caminar hacia un NPC hasta que
		# se abre su panel), desactivar el subárbol acá abajo apaga _input()
		# antes del "soltado" real y el jugador seguiría moviéndose solo.
		# Soltar primero (ver Joystick.forzar_suelta) evita que quede pegado.
		for hijo in find_children("*", "", true, false):
			if hijo.has_method("forzar_suelta"):
				hijo.forzar_suelta()
		process_mode = Node.PROCESS_MODE_DISABLED
