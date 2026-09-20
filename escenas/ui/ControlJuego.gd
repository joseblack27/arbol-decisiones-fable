extends Control

func _ready():
	GestorUI.modo_cambiado.connect(_on_modo_cambiado)

func _on_modo_cambiado(modo: int) -> void:
	if modo == GestorUI.Modo.JUEGO:
		process_mode = Node.PROCESS_MODE_INHERIT
	else:
		# Reportado en celular real (19 sep 2026): si el dedo seguía
		# arrastrando el joystick justo cuando se abre un diálogo/panel OS/
		# chat (típico: caminar hacia un NPC/cofre hasta que el auto-trigger
		# abre su panel), desactivar el subárbol ACÁ ABAJO apaga _input()
		# antes de que llegue el "soltado" real -- el jugador se quedaba
		# moviendo solo para siempre. Soltar primero (ver Joystick.
		# forzar_suelta) evita que quede pegado.
		for hijo in find_children("*", "", true, false):
			if hijo.has_method("forzar_suelta"):
				hijo.forzar_suelta()
		process_mode = Node.PROCESS_MODE_DISABLED
