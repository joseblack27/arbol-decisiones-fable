# =============================================================================
# Regresión (pedido explícito del usuario, 21 sep 2026): "cuando hay
# subida de ping es cuando se queda el joystick como pegado y el jugador
# se queda moviendo ... parece que la variable de dirección en este caso
# es la que no se actualiza a 0". Red de seguridad adicional: cada
# fotograma físico, si "direccion" no es cero, se consulta el estado REAL
# del joystick (Joystick.esta_presionado(), no una inferencia por falta
# de movimiento) -- si el joystick ya no está presionado de verdad,
# corrige "direccion" a cero sin esperar un toque nuevo.
#
# Confirma:
#   1. direccion != ZERO pero el joystick YA NO está presionado (index=-1)
#      -- se corrige sola a ZERO en el siguiente _physics_process.
#   2. direccion != ZERO CON el joystick realmente presionado -- no se
#      toca (no debilita el movimiento normal).
#   godot --headless --path . --script res://pruebas/prueba_joystick_soltado_real_corrige_direccion.gd
# =============================================================================
extends SceneTree

var _f := 0
var _jugador
var _joystick

var _corrige_si_no_esta_presionado_ok := false
var _no_toca_si_si_esta_presionado_ok := false


func _process(_delta: float) -> bool:
	_f += 1
	match _f:
		1:
			_montar()
		3:
			_probar_no_presionado_corrige()
		5:
			_probar_presionado_no_toca()
			return _informar()
	return false


func _montar() -> void:
	var escena := Node2D.new()
	root.add_child(escena)
	current_scene = escena

	# Jugador.tscn PRIMERO -- fuerza que los autoloads que usan las
	# habilidades ya estén resueltos (ver memoria del proyecto).
	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	escena.add_child(_jugador)

	_joystick = (load("res://escenas/ui/joystick/joystick.tscn") as PackedScene).instantiate()
	escena.add_child(_joystick)


func _probar_no_presionado_corrige() -> void:
	# "direccion" quedó pegada en un valor no-cero, pero el dedo ya no está
	# (index=-1, default) -- exactamente el escenario reportado.
	_jugador.direccion = Vector2.RIGHT
	_jugador._verificar_joystick_soltado()
	_corrige_si_no_esta_presionado_ok = _jugador.direccion == Vector2.ZERO
	print("Con el joystick sin presionar de verdad, direccion se corrige a cero (esperado true): %s" % \
		_corrige_si_no_esta_presionado_ok)


func _probar_presionado_no_toca() -> void:
	_joystick._on_touch_iniciado(0, _joystick.global_position + Vector2(10, 0))
	_jugador.direccion = Vector2.RIGHT
	_jugador._verificar_joystick_soltado()
	_no_toca_si_si_esta_presionado_ok = _jugador.direccion == Vector2.RIGHT
	print("Con el joystick SÍ presionado de verdad, direccion NO se toca (esperado true): %s" % \
		_no_toca_si_si_esta_presionado_ok)


func _informar() -> bool:
	var exito := _corrige_si_no_esta_presionado_ok and _no_toca_si_si_esta_presionado_ok
	print("PRUEBA JOYSTICK SOLTADO REAL CORRIGE DIRECCION %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
