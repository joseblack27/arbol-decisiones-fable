# =============================================================================
# Regresión (relacionado con el bug real "el joystick queda moviendo
# solo", ver Joystick.forzar_suelta/ControlJuego._on_modo_cambiado, y
# reportado de nuevo el 20 sep 2026 insistiendo en el caso puntual de
# abrir un diálogo/panel a mitad de un arrastre): Jugador._joystick_
# movimiento() cortaba TODA actualización, incluida la de "ya solté el
# joystick" (dirección CERO), mientras el jugador tuviera el control
# bloqueado por CUALQUIER motivo (aturdido, canal de Ráfaga/Lanzallamas
# en curso, ver _bloqueos_control) -- si el "soltado" real llegaba
# justo en esa ventana, se perdía igual y "direccion" quedaba pegada en
# su último valor no-cero hasta que algo más la pisara.
#
# Confirma:
#   1. Bloqueado, un intento de ARRANCAR movimiento nuevo (dirección no
#      cero) se sigue ignorando -- no debilita la protección real de
#      "no te podés mover mientras estás aturdido".
#   2. Bloqueado, un SOLTAR (dirección cero) SÍ se respeta -- ya no queda
#      pegada la dirección vieja.
#   godot --headless --path . --script res://pruebas/prueba_joystick_soltar_con_control_bloqueado.gd
# =============================================================================
extends SceneTree

var _jugador

var _bloqueado_ignora_nuevo_movimiento_ok := false
var _bloqueado_igual_respeta_soltar_ok := false


func _process(_delta: float) -> bool:
	var escena := Node2D.new()
	root.add_child(escena)
	current_scene = escena

	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	escena.add_child(_jugador)

	# Simula "aturdido" (o cualquier otro bloqueo de control real) sin
	# necesitar el efecto real de por medio.
	_jugador.bloquear_control()

	_jugador.direccion = Vector2.RIGHT  # Dirección previa, como si venía moviéndose.
	_jugador._joystick_movimiento(Vector2.UP)
	_bloqueado_ignora_nuevo_movimiento_ok = _jugador.direccion == Vector2.RIGHT
	print("Bloqueado, un movimiento NUEVO se sigue ignorando (esperado true, direccion=%s): %s" % [
		_jugador.direccion, _bloqueado_ignora_nuevo_movimiento_ok])

	_jugador._joystick_movimiento(Vector2.ZERO)
	_bloqueado_igual_respeta_soltar_ok = _jugador.direccion == Vector2.ZERO
	print("Bloqueado, SOLTAR (dirección cero) SÍ se respeta (esperado true, direccion=%s): %s" % [
		_jugador.direccion, _bloqueado_igual_respeta_soltar_ok])

	return _informar()


func _informar() -> bool:
	var exito := _bloqueado_ignora_nuevo_movimiento_ok and _bloqueado_igual_respeta_soltar_ok
	print("PRUEBA JOYSTICK SOLTAR CON CONTROL BLOQUEADO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
