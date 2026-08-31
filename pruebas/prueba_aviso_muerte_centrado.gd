# =============================================================================
# Prueba de que el cartel de Game Over queda REALMENTE centrado en pantalla
# (bug histórico: Control.PRESET_CENTER en un label solo ancla su esquina
# SUPERIOR IZQUIERDA al centro — el texto quedaba corrido hacia
# abajo/derecha, no centrado de verdad), tiene outline, y no le roba el
# toque al joystick/botones de abajo.
#
# Actualizada tras reemplazar el Label armado por código
# (Jugador._mostrar_aviso_muerte, eliminado) por la escena real
# PanelGameOver.tscn (pedido explícito del usuario: "crea todos los nodos,
# no quiero que generes nodos por código") — mismas propiedades, ahora
# sobre la escena nueva en vez del Label ad-hoc.
#   godot --headless --path . --script res://pruebas/prueba_aviso_muerte_centrado.gd
# =============================================================================
extends SceneTree

var _panel

var _envuelto_en_center_container_ok := false
var _center_container_ocupa_toda_la_pantalla_ok := false
var _no_roba_el_toque_ok := false
var _tiene_outline_ok := false


func _process(_delta: float) -> bool:
	_montar()
	_verificar()
	return _informar()


func _montar() -> void:
	_panel = (load("res://escenas/ui/panel_game_over/PanelGameOver.tscn") as PackedScene).instantiate()
	root.add_child(_panel)


func _verificar() -> void:
	var titulo: Label = _panel.get_node("CenterContainer/VBox/Titulo")
	var contenedor := _panel.get_node_or_null("CenterContainer") as CenterContainer

	_envuelto_en_center_container_ok = contenedor != null
	print("El título está envuelto en un CenterContainer (esperado true): %s" % _envuelto_en_center_container_ok)

	if contenedor:
		_center_container_ocupa_toda_la_pantalla_ok = is_equal_approx(contenedor.anchor_left, 0.0) \
			and is_equal_approx(contenedor.anchor_top, 0.0) \
			and is_equal_approx(contenedor.anchor_right, 1.0) \
			and is_equal_approx(contenedor.anchor_bottom, 1.0)
		print("El CenterContainer ocupa toda la pantalla, PRESET_FULL_RECT (esperado true): %s" \
			% _center_container_ocupa_toda_la_pantalla_ok)

		_no_roba_el_toque_ok = _panel.mouse_filter == Control.MOUSE_FILTER_IGNORE \
			and contenedor.mouse_filter == Control.MOUSE_FILTER_IGNORE \
			and titulo.mouse_filter == Control.MOUSE_FILTER_IGNORE
		print("No le roba el toque al joystick/botones (esperado true): %s" % _no_roba_el_toque_ok)

	var color_outline: Color = titulo.get_theme_color("font_outline_color")
	var tamano_outline: int = titulo.get_theme_constant("outline_size")
	_tiene_outline_ok = color_outline == Color.BLACK and tamano_outline > 0
	print("Tiene outline (esperado true, negro y > 0px): %s (color=%s, tamaño=%d)" % [
		_tiene_outline_ok, color_outline, tamano_outline])


func _informar() -> bool:
	var exito := _envuelto_en_center_container_ok and _center_container_ocupa_toda_la_pantalla_ok \
		and _no_roba_el_toque_ok and _tiene_outline_ok
	print("PRUEBA AVISO MUERTE CENTRADO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
