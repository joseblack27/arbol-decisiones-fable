# =============================================================================
# Regresión (pedido explícito del usuario, 24 sep 2026): "volvió el tema del
# joystick... el personaje se sigue moviendo con la animación de idle sin
# fin en la última dirección hecha". La corrección anterior
# (_verificar_joystick_soltado) solo insistía UNA vez al detectar el
# soltado -- si esa única muestra (RPC reliable) se perdía, o un aviso
# viejo de "seguí moviéndote" la pisaba después, nada lo volvía a corregir
# y el cuerpo autoritativo del servidor quedaba caminando solo. Ahora
# insiste varios fotogramas seguidos tras el soltado (ver
# _FOTOGRAMAS_INSISTIR_JOYSTICK_SOLTADO), y además rectifica "velocity"
# directamente, no solo "direccion" -- pedido explícito del usuario: "quiero
# que añadas un rectificador para la velocidad de movimiento".
#
# Confirma:
#   1. Al soltar con direccion != ZERO, arranca una ventana de insistencia
#      (contador > 0) que sigue bajando en los fotogramas siguientes aunque
#      direccion ya esté en cero.
#   2. Mientras dura esa ventana, si algo más deja "velocity" en un valor
#      no-cero, el rectificador lo vuelve a poner en cero.
#   3. La ventana se agota sola tras varios fotogramas (no insiste para
#      siempre -- eso spamearía el canal reliable con el joystick simplemente
#      quieto).
#   4. Volver a presionar el joystick corta la insistencia de inmediato.
#   godot --headless --path . --script res://pruebas/prueba_joystick_soltado_insiste_varios_fotogramas.gd
# =============================================================================
extends SceneTree

var _f := 0
var _jugador
var _joystick

var _insiste_varios_fotogramas_ok := false
var _rectifica_velocity_ok := false
var _ventana_se_agota_ok := false
var _presionar_corta_insistencia_ok := false


func _process(_delta: float) -> bool:
	_f += 1
	match _f:
		1:
			_montar()
		3:
			_probar_insiste_varios_fotogramas()
		5:
			_probar_rectifica_velocity()
		7:
			_probar_ventana_se_agota()
		9:
			_probar_presionar_corta_insistencia()
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


func _probar_insiste_varios_fotogramas() -> void:
	_jugador.direccion = Vector2.RIGHT
	_jugador._verificar_joystick_soltado()
	var contador_tras_primera: int = _jugador._fotogramas_insistiendo_joystick_soltado
	_jugador._verificar_joystick_soltado()
	var contador_tras_segunda: int = _jugador._fotogramas_insistiendo_joystick_soltado
	_insiste_varios_fotogramas_ok = contador_tras_primera > 0 and contador_tras_segunda == contador_tras_primera - 1
	print("La ventana de insistencia sigue activa (y bajando) en el fotograma siguiente (esperado true): %s" % \
		_insiste_varios_fotogramas_ok)


func _probar_rectifica_velocity() -> void:
	_jugador.velocity = Vector2(500, 0)  # simula algo dejando velocity sucia mientras dura la ventana.
	_jugador._verificar_joystick_soltado()
	_rectifica_velocity_ok = _jugador.velocity == Vector2.ZERO
	print("Con la ventana todavía activa, velocity se rectifica a cero (esperado true): %s" % \
		_rectifica_velocity_ok)


func _probar_ventana_se_agota() -> void:
	for _i in range(30):
		_jugador._verificar_joystick_soltado()
	_ventana_se_agota_ok = _jugador._fotogramas_insistiendo_joystick_soltado <= 0
	print("La ventana de insistencia se agota sola tras varios fotogramas (esperado true): %s" % \
		_ventana_se_agota_ok)


func _probar_presionar_corta_insistencia() -> void:
	_jugador.direccion = Vector2.RIGHT
	_jugador._verificar_joystick_soltado()  # arranca de nuevo la ventana.
	_joystick._on_touch_iniciado(0, _joystick.global_position + Vector2(10, 0))
	_jugador._verificar_joystick_soltado()
	_presionar_corta_insistencia_ok = _jugador._fotogramas_insistiendo_joystick_soltado == 0
	print("Volver a presionar corta la ventana de insistencia (esperado true): %s" % \
		_presionar_corta_insistencia_ok)


func _informar() -> bool:
	var exito := _insiste_varios_fotogramas_ok and _rectifica_velocity_ok \
		and _ventana_se_agota_ok and _presionar_corta_insistencia_ok
	print("PRUEBA JOYSTICK SOLTADO INSISTE VARIOS FOTOGRAMAS %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
