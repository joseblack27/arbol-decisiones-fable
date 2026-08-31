# =============================================================================
# PanelChat — Feature B del plan MMO. Verifica el lado CLIENTE (recibir un
# mensaje ya validado por el servidor y reflejarlo en el log):
#   1. Mensajes normales aparecen en el texto del log.
#   2. Un mensaje con BBCode crudo (ej. alguien escribe "[img]...") se
#      escapa ([lb]) antes de agregarse al RichTextLabel — sin esto,
#      cualquier jugador podría inyectar formato/imágenes en el chat de
#      todos con solo escribir corchetes.
#   3. El botón de alternar muestra/oculta el panel expandido.
#   godot --headless --path . --script res://pruebas/prueba_panel_chat_ui.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _panel
var _gestor_chat
var _texto: RichTextLabel
var _boton: Button

var _mensaje_normal_visible_ok := false
var _bbcode_escapado_ok := false
var _alternar_panel_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas == 1:
		_montar()
		return false
	if _fotogramas == 2:
		return _informar()
	return false


func _montar() -> void:
	_gestor_chat = root.get_node("/root/GestorChat")
	_panel = (load("res://escenas/ui/panel_chat/PanelChat.tscn") as PackedScene).instantiate()
	root.add_child(_panel)
	_texto = _panel.get_node("Panel/VBox/Scroll/Texto")
	_boton = _panel.get_node("BotonToggle")

	# Simula lo que haría _recibir_mensaje_red al llegar por RPC real.
	_gestor_chat._recibir_mensaje_red("Fulano", "hola a todos", false)
	_gestor_chat._recibir_mensaje_red("Atacante", "[img]x[/img] intento de inyección", false)


func _informar() -> bool:
	_mensaje_normal_visible_ok = _texto.text.find("hola a todos") != -1
	var no_contiene_bbcode_crudo := _texto.text.find("[img]") == -1
	var contiene_escapado := _texto.text.find("[lb]img]") != -1
	_bbcode_escapado_ok = no_contiene_bbcode_crudo and contiene_escapado
	print("Mensaje normal visible en el log (esperado true): %s" % _mensaje_normal_visible_ok)
	print("BBCode crudo del remitente queda escapado, no interpretado (esperado true): %s" % _bbcode_escapado_ok)

	var panel_expandido := _panel.get_node("Panel") as PanelContainer
	var visible_inicial := panel_expandido.visible
	_boton.pressed.emit()
	var visible_tras_un_toque := panel_expandido.visible
	_boton.pressed.emit()
	var visible_tras_dos_toques := panel_expandido.visible
	_alternar_panel_ok = not visible_inicial and visible_tras_un_toque and not visible_tras_dos_toques
	print("El botón alterna mostrar/ocultar el panel (esperado true): %s" % _alternar_panel_ok)

	var exito := _mensaje_normal_visible_ok and _bbcode_escapado_ok and _alternar_panel_ok
	print("PRUEBA PANEL CHAT UI %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
