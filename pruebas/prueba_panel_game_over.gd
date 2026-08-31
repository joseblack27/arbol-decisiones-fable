# =============================================================================
# PanelGameOver — antes morir solo mostraba un Label armado por código
# (Jugador._mostrar_aviso_muerte, ya eliminado); ahora es una escena real
# (pedido explícito: "crea todos los nodos, no quiero que generes nodos
# por código") que reacciona a BusEventos.jugador_murio/jugador_reaparecio
# — dos señales que ya estaban declaradas pero nunca se habían emitido.
#
# Verifica:
#   1. Oculto por defecto.
#   2. jugador_murio(tiempo) lo muestra con la cuenta regresiva inicial.
#   3. El Timer real (no un temporizador armado por código) hace bajar la
#      cuenta un número por segundo.
#   4. jugador_reaparecio lo oculta y para el Timer.
#   godot --headless --path . --script res://pruebas/prueba_panel_game_over.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _panel
var _bus

var _oculto_por_defecto_ok := false
var _muestra_cuenta_inicial_ok := false
var _cuenta_baja_con_el_tiempo_ok := false
var _reaparecer_oculta_y_para_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			_probar_estado_inicial()
			_bus.jugador_murio.emit(5.0)
			_probar_muestra_cuenta_inicial()
		# El Timer real tiene wait_time=1.0 — a ~60 físicas/seg, 70 fotogramas
		# de sobra para que dispare al menos una vez.
		70:
			_probar_cuenta_bajo()
			_bus.jugador_reaparecio.emit(Vector2.ZERO)
			return _informar()
	return false


func _montar() -> void:
	_bus = root.get_node("/root/BusEventos")
	_panel = (load("res://escenas/ui/panel_game_over/PanelGameOver.tscn") as PackedScene).instantiate()
	root.add_child(_panel)


func _probar_estado_inicial() -> void:
	_oculto_por_defecto_ok = not _panel.visible
	print("Oculto por defecto (esperado true): %s" % _oculto_por_defecto_ok)


func _probar_muestra_cuenta_inicial() -> void:
	var subtitulo: Label = _panel.get_node("CenterContainer/VBox/Subtitulo")
	_muestra_cuenta_inicial_ok = _panel.visible and subtitulo.text.find("5") != -1
	print("jugador_murio(5.0) muestra el panel con la cuenta inicial (esperado true): %s (texto: '%s')" \
		% [_muestra_cuenta_inicial_ok, subtitulo.text])


func _probar_cuenta_bajo() -> void:
	var subtitulo: Label = _panel.get_node("CenterContainer/VBox/Subtitulo")
	_cuenta_baja_con_el_tiempo_ok = subtitulo.text.find("5") == -1
	print("La cuenta regresiva bajó de 5 tras ~1s de Timer real (esperado true): %s (texto: '%s')" \
		% [_cuenta_baja_con_el_tiempo_ok, subtitulo.text])


func _informar() -> bool:
	_reaparecer_oculta_y_para_ok = not _panel.visible \
		and not _panel.get_node("Temporizador").time_left > 0.0
	print("jugador_reaparecio oculta el panel y para el Timer (esperado true): %s" \
		% _reaparecer_oculta_y_para_ok)

	var exito := _oculto_por_defecto_ok and _muestra_cuenta_inicial_ok \
		and _cuenta_baja_con_el_tiempo_ok and _reaparecer_oculta_y_para_ok
	print("PRUEBA PANEL GAME OVER %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
