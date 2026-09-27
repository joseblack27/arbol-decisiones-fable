# =============================================================================
# Regresión (reportado en juego real, 26 sep 2026, confirmado jugando SOLO
# -- descarta que sea el desface de red que ya cubre Jugador._verificar_
# joystick_soltado): "volvió el tema del joystick... el personaje se sigue
# moviendo... en la última dirección hecha". Root cause real: si el evento
# de touch_finalizado se pierde (Android reutiliza el id de puntero del
# toque anterior para el siguiente), Joystick.index queda pegado en un
# valor real -- y la versión vieja de _on_touch_iniciado exigía
# "index == -1" a secas, así que el joystick quedaba sin responder para
# SIEMPRE a partir de ahí: ni un toque nuevo lo re-armaba.
#
# Confirma:
#   1. Sin soltar (index sigue en el valor viejo), un touch_iniciado NUEVO
#      que reutiliza el MISMO índice SÍ re-arma el joystick (posición y
#      dirección actualizadas), simulando el soltado perdido + toque nuevo.
#   2. Un touch_iniciado con un índice DISTINTO mientras uno ya está
#      sostenido sigue sin poder secuestrarlo (no cambia nada) -- esto NO
#      debe romperse con el fix de arriba.
#   godot --headless --path . --script res://pruebas/prueba_joystick_reusa_indice_tras_soltado_perdido.gd
# =============================================================================
extends SceneTree

var _f := 0
var _joystick

var _reusa_mismo_indice_ok := false
var _no_secuestra_con_otro_indice_ok := false


func _process(_delta: float) -> bool:
	_f += 1
	match _f:
		1:
			_montar()
		3:
			_probar_reusa_mismo_indice()
		5:
			_probar_no_secuestra_con_otro_indice()
			return _informar()
	return false


func _montar() -> void:
	var escena := Node2D.new()
	root.add_child(escena)
	current_scene = escena

	_joystick = (load("res://escenas/ui/joystick/joystick.tscn") as PackedScene).instantiate()
	escena.add_child(_joystick)


func _probar_reusa_mismo_indice() -> void:
	# Toque inicial normal: índice 0, empujado a la derecha.
	_joystick._on_touch_iniciado(0, _joystick.global_position + Vector2(20, 0))
	# El "soltado" real (touch_finalizado) se PIERDE -- index sigue en 0 acá,
	# simulando exactamente el bug reportado. Un toque NUEVO reutiliza el
	# mismo índice (típico en Android), esta vez hacia abajo.
	_joystick._on_touch_iniciado(0, _joystick.global_position + Vector2(0, 20))
	_reusa_mismo_indice_ok = _joystick.index == 0 \
		and _joystick.direccion.normalized().is_equal_approx(Vector2.DOWN)
	print("Reusar el mismo índice sin soltar antes re-arma el joystick (esperado true): %s (index=%s direccion=%s)" % [
		_reusa_mismo_indice_ok, _joystick.index, _joystick.direccion
	])


func _probar_no_secuestra_con_otro_indice() -> void:
	# _joystick sigue sosteniendo índice 0 (hacia abajo) de la fase anterior.
	# Un índice DISTINTO (otro dedo real, en otro control) no debe tocar nada.
	_joystick._on_touch_iniciado(1, _joystick.global_position + Vector2(20, 0))
	_no_secuestra_con_otro_indice_ok = _joystick.index == 0 \
		and _joystick.direccion.normalized().is_equal_approx(Vector2.DOWN)
	print("Un índice distinto mientras uno ya está sostenido no lo secuestra (esperado true): %s (index=%s direccion=%s)" % [
		_no_secuestra_con_otro_indice_ok, _joystick.index, _joystick.direccion
	])


func _informar() -> bool:
	var exito := _reusa_mismo_indice_ok and _no_secuestra_con_otro_indice_ok
	print("PRUEBA JOYSTICK REUSA INDICE TRAS SOLTADO PERDIDO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
