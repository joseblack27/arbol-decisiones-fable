# =============================================================================
# Bug real reportado: "el nombre que aparece en atributos, debería ser el
# mismo nombre de la cuenta" — PanelTablero._conectar_jugador() leía
# "datos_jugador.nombre", una propiedad que Jugador.gd NUNCA tiene (ese
# "if" nunca corría), así que el Label se quedaba con el placeholder
# hardcodeado del .tscn ("Rikapolo") para siempre, sin importar qué cuenta
# estuviera jugando. Ahora usa Utils.nombre_visible(jugador) — el mismo
# helper que ya usa HudJugador.gd correctamente, que lee Jugador.
# nombre_visible (el nombre de cuenta real, replicado a todos los peers).
#   godot --headless --path . --script res://pruebas/prueba_panel_tablero_nombre_cuenta.gd
# =============================================================================
extends SceneTree

var _jugador
var _panel

var _muestra_el_nombre_de_cuenta_ok := false


func _process(_delta: float) -> bool:
	_montar()
	_probar_muestra_el_nombre_de_cuenta()
	return _informar()


func _montar() -> void:
	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(_jugador)
	# Pisa lo que _ready() haya resuelto de Utils.nombre_jugador_local()
	# (depende del entorno donde corra la prueba) — acá lo que importa es
	# que el panel muestre ESTO, no de dónde salió originalmente.
	_jugador.nombre_visible = "CuentaDePrueba"

	_panel = (load("res://escenas/ui/panel_os/paneles/tablero/PanelTablero.tscn") as PackedScene).instantiate()
	root.add_child(_panel)


func _probar_muestra_el_nombre_de_cuenta() -> void:
	print("El nombre en atributos coincide con el nombre de cuenta (esperado 'CuentaDePrueba'): %s" % \
		_panel._lbl_nombre.text)
	_muestra_el_nombre_de_cuenta_ok = _panel._lbl_nombre.text == "CuentaDePrueba"


func _informar() -> bool:
	var exito := _muestra_el_nombre_de_cuenta_ok
	print("PRUEBA PANEL TABLERO NOMBRE CUENTA %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
