# =============================================================================
# Prueba de MovimientoComponente.aplicar_empuje() (knockback) — mecanismo
# nuevo, no existía ningún empuje/impulso externo en el proyecto antes
# (agregado para la habilidad Onda de Choque).
#
# Verifica:
#   1. El empuje TOMA el control del movimiento por encima de un comando
#      de dirección en curso (velocidad del empuje, no la del comando).
#   2. Al vencer la duración del empuje, el comando original se retoma
#      solo, sin tener que reconectarlo a mano.
#   godot --headless --path . --script res://pruebas/prueba_movimiento_empuje.gd
# =============================================================================
extends SceneTree

var _jugador: CharacterBody2D
var _mov
var _fotogramas := 0

var _empuje_anula_comando := false
var _vuelve_al_comando_original := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			_mov.comandar_direccion(Vector2.RIGHT, 100.0)
		5:
			_mov.aplicar_empuje(Vector2.UP, 900.0, 0.1)
		6:
			_empuje_anula_comando = _jugador.velocity.y < -100.0
			print("El empuje pisa el comando en curso (esperado true, velocity=%s): %s" % [
				_jugador.velocity, _empuje_anula_comando])
		20:
			# duracion=0.1s (~6 fotogramas físicos) desde el frame 5 -> ya
			# venció de sobra; debería volver a moverse según el comando
			# original (derecha), sin que nadie lo vuelva a pedir a mano.
			_vuelve_al_comando_original = _jugador.velocity.x > 50.0
			print("Vuelve al comando original tras vencer el empuje (esperado true, velocity=%s): %s" % [
				_jugador.velocity, _vuelve_al_comando_original])
			return _informar()
	return false


func _montar() -> void:
	_jugador = CharacterBody2D.new()
	root.add_child(_jugador)
	var forma := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 8.0
	forma.shape = circ
	_jugador.add_child(forma)

	_mov = (load("res://componentes/MovimientoComponente.gd") as GDScript).new()
	_mov.name = "MovimientoComponente"
	_mov.jugador = _jugador
	_mov.velocidad_base = 100.0
	_jugador.add_child(_mov)


func _informar() -> bool:
	var exito := _empuje_anula_comando and _vuelve_al_comando_original
	print("PRUEBA MOVIMIENTO EMPUJE %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
