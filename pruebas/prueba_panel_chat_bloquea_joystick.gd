# =============================================================================
# Bug reportado: "al abrir el chat, el joystick de atrás también recibe el
# click" — ComponenteToque escucha _input() global SIN mirar qué UI está
# encima (ver ese script), así que el único freno real del proyecto es
# GestorUI.modo_actual + ControlJuego (desactiva el subárbol del
# joystick/slots de habilidad mientras el modo no sea JUEGO) — el mismo
# mecanismo que ya usan Diálogo/OS. PanelChat no lo usaba.
#
# Verifica, con un Control real corriendo ControlJuego.gd (mismo script que
# envuelve al joystick en Mundo.tscn) al lado del PanelChat real:
#   1. Expandir el chat pone a GestorUI en modo CHAT y desactiva
#      (PROCESS_MODE_DISABLED) el subárbol de ControlJuego.
#   2. Colapsar el chat de nuevo vuelve a JUEGO y reactiva ese subárbol.
#   godot --headless --path . --script res://pruebas/prueba_panel_chat_bloquea_joystick.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _gestor_ui
var _control_juego
var _boton_chat

var _abrir_bloquea_ok := false
var _cerrar_desbloquea_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas == 1:
		_montar()
		return false
	if _fotogramas == 2:
		return _informar()
	return false


func _montar() -> void:
	_gestor_ui = root.get_node("/root/GestorUI")

	_control_juego = Control.new()
	_control_juego.set_script(load("res://escenas/ui/ControlJuego.gd"))
	root.add_child(_control_juego)

	var panel_chat = (load("res://escenas/ui/panel_chat/PanelChat.tscn") as PackedScene).instantiate()
	root.add_child(panel_chat)
	_boton_chat = panel_chat.get_node("BotonToggle")

	# Abrir: el chat expandido tiene que bloquear el joystick/slots.
	_boton_chat.pressed.emit()
	var modo_al_abrir: int = _gestor_ui.modo_actual
	var proceso_al_abrir: int = _control_juego.process_mode
	_abrir_bloquea_ok = modo_al_abrir == _gestor_ui.Modo.CHAT \
		and proceso_al_abrir == Node.PROCESS_MODE_DISABLED
	print("Abrir el chat pone a GestorUI en modo CHAT y desactiva ControlJuego (esperado true): %s" \
		% _abrir_bloquea_ok)

	# Cerrar: tiene que soltar el bloqueo.
	_boton_chat.pressed.emit()
	var modo_al_cerrar: int = _gestor_ui.modo_actual
	var proceso_al_cerrar: int = _control_juego.process_mode
	_cerrar_desbloquea_ok = modo_al_cerrar == _gestor_ui.Modo.JUEGO \
		and proceso_al_cerrar == Node.PROCESS_MODE_INHERIT
	print("Cerrar el chat vuelve a JUEGO y reactiva ControlJuego (esperado true): %s" \
		% _cerrar_desbloquea_ok)


func _informar() -> bool:
	var exito := _abrir_bloquea_ok and _cerrar_desbloquea_ok
	print("PRUEBA PANEL CHAT BLOQUEA JOYSTICK %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
