# =============================================================================
# Prueba de que el cartel "Has muerto" queda REALMENTE centrado en pantalla
# (antes usaba Control.PRESET_CENTER en el label, que solo ancla su
# esquina SUPERIOR IZQUIERDA al centro — el texto quedaba corrido hacia
# abajo/derecha, no centrado de verdad) y que tiene outline — pedido del
# usuario.
#   godot --headless --path . --script res://pruebas/prueba_aviso_muerte_centrado.gd
# =============================================================================
extends SceneTree

var _jugador
var _fotogramas := 0

var _envuelto_en_center_container := false
var _center_container_ocupa_toda_la_pantalla := false
var _no_roba_el_toque := false
var _tiene_outline := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
			_jugador._mostrar_aviso_muerte()
		2:
			_verificar()
			return _informar()
	return false


func _montar() -> void:
	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(_jugador)


func _verificar() -> void:
	var label: Label = _jugador._aviso_muerte
	var contenedor := label.get_parent() as CenterContainer
	_envuelto_en_center_container = contenedor != null
	print("El label está envuelto en un CenterContainer (esperado true): %s" % _envuelto_en_center_container)

	if contenedor:
		_center_container_ocupa_toda_la_pantalla = is_equal_approx(contenedor.anchor_left, 0.0) \
			and is_equal_approx(contenedor.anchor_top, 0.0) \
			and is_equal_approx(contenedor.anchor_right, 1.0) \
			and is_equal_approx(contenedor.anchor_bottom, 1.0)
		print("El CenterContainer ocupa toda la pantalla, PRESET_FULL_RECT (esperado true): %s" % _center_container_ocupa_toda_la_pantalla)

		_no_roba_el_toque = contenedor.mouse_filter == Control.MOUSE_FILTER_IGNORE \
			and label.mouse_filter == Control.MOUSE_FILTER_IGNORE
		print("No le roba el toque al joystick/botones (esperado true): %s" % _no_roba_el_toque)

	var color_outline: Color = label.get_theme_color("font_outline_color")
	var tamano_outline: int = label.get_theme_constant("outline_size")
	_tiene_outline = color_outline == Color.BLACK and tamano_outline > 0
	print("Tiene outline (esperado true, negro y > 0px): %s (color=%s, tamaño=%d)" % [
		_tiene_outline, color_outline, tamano_outline])


func _informar() -> bool:
	var exito := _envuelto_en_center_container and _center_container_ocupa_toda_la_pantalla \
		and _no_roba_el_toque and _tiene_outline
	print("PRUEBA AVISO MUERTE CENTRADO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
