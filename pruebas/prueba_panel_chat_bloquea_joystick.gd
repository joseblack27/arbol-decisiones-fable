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
#   3. Bug real reportado (1 sep 2026): con el chat abierto, abrir y cerrar
#      el panel OS encima no debe reactivar el joystick — GestorUI.
#      cerrar_os() forzaba JUEGO a ciegas sin saber que venía de CHAT.
#   godot --headless --path . --script res://pruebas/prueba_panel_chat_bloquea_joystick.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _gestor_ui
var _control_juego
var _boton_chat

var _abrir_bloquea_ok := false
var _cerrar_desbloquea_ok := false
var _os_no_pisa_chat_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas == 1:
		_montar()
		return false
	if _fotogramas == 2:
		_probar_os_no_pisa_chat()
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


## Bug real reportado: "abro el chat, abro y cierro el panel OS, y el
## joystick que queda detrás del chat vuelve a recibir el click" — con el
## chat todavía abierto, GestorUI.cerrar_os() forzaba JUEGO sin importar
## que venía de CHAT. Sigue del estado que deja _montar() (chat cerrado,
## modo JUEGO) — lo vuelve a abrir para esta prueba puntual.
func _probar_os_no_pisa_chat() -> void:
	_boton_chat.pressed.emit()  # reabre el chat.
	_gestor_ui.abrir_os()
	_gestor_ui.cerrar_os()
	var modo_tras_cerrar_os: int = _gestor_ui.modo_actual
	var proceso_tras_cerrar_os: int = _control_juego.process_mode
	_os_no_pisa_chat_ok = modo_tras_cerrar_os == _gestor_ui.Modo.CHAT \
		and proceso_tras_cerrar_os == Node.PROCESS_MODE_DISABLED
	print("Con el chat abierto, abrir y cerrar OS no reactiva el joystick (esperado true): %s" \
		% _os_no_pisa_chat_ok)


func _informar() -> bool:
	var exito := _abrir_bloquea_ok and _cerrar_desbloquea_ok and _os_no_pisa_chat_ok
	print("PRUEBA PANEL CHAT BLOQUEA JOYSTICK %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
