# =============================================================================
# Prueba del ratón (enemigo 100% declarativo, sin script propio):
#   1. Con el señuelo cerca debe huir siempre (velocidad ~base).
#   2. De vez en cuando entra en pánico: esprint a velocidad x2 unos segundos.
# El señuelo "persigue" teletransportándose detrás del ratón cada segundo.
# Para hacer determinista el pánico, la prueba fija su probabilidad en 1.0.
#   godot --headless --path . --script res://pruebas/prueba_raton_bt.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _raton: CharacterBody2D
var _senuelo: CharacterBody2D
var _vio_huida_normal := false
var _vio_esprint := false
var _velocidad_maxima := 0.0


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas == 1:
		_montar_escena()
		return false

	# El señuelo persigue: se re-coloca a 120 px detrás del ratón cada segundo.
	if _fotogramas % 60 == 0:
		var direccion_huida: Vector2 = _raton.velocity.normalized()
		if direccion_huida == Vector2.ZERO:
			direccion_huida = Vector2.RIGHT
		# A 80 px: dentro del radio de visión del ratón (100) para que la
		# huida sea continua y la prueba no dependa del azar del deambular.
		_senuelo.global_position = _raton.global_position - direccion_huida * 80.0

	var rapidez := _raton.velocity.length()
	_velocidad_maxima = maxf(_velocidad_maxima, rapidez)
	if rapidez > 80.0 and rapidez < 120.0:
		_vio_huida_normal = true
	if rapidez > 180.0:
		_vio_esprint = true

	if _fotogramas % 120 == 0:
		print("t=%4.1fs  rapidez=%6.1f  dist=%.0f" % [
			_fotogramas / 60.0, rapidez,
			_raton.global_position.distance_to(_senuelo.global_position),
		])

	if _fotogramas > 1200:
		print("Huida normal (~100 px/s) observada: %s" % _vio_huida_normal)
		print("Esprint de pánico (>180 px/s) observado: %s (máx %.0f)" % [_vio_esprint, _velocidad_maxima])
		var exito := _vio_huida_normal and _vio_esprint
		print("PRUEBA RATÓN %s" % ("OK" if exito else "FALLIDA"))
		quit(0 if exito else 1)
		return true
	return false


func _montar_escena() -> void:
	var escena := Node2D.new()
	escena.name = "EscenaPrueba"
	root.add_child(escena)
	current_scene = escena

	_raton = (load("res://enemigos/EnemigoRaton.tscn") as PackedScene).instantiate()
	root.add_child(_raton)
	_raton.global_position = Vector2(300, 300)

	# Pánico determinista para la prueba (en el juego queda al 50 %).
	var probabilidad := _raton.get_node(
		"ArbolComportamiento/Selector/Panico/EnfriamientoPanico/ProbabilidadPanico"
	)
	probabilidad.set("probabilidad", 1.0)

	_senuelo = CharacterBody2D.new()
	_senuelo.add_to_group("jugadores")
	var vida := VidaComponente.new()
	vida.collision_layer = 1
	var colision := CollisionShape2D.new()
	var forma := CircleShape2D.new()
	forma.radius = 20.0
	colision.shape = forma
	vida.add_child(colision)
	_senuelo.add_child(vida)
	root.add_child(_senuelo)
	vida.owner = _senuelo
	_senuelo.global_position = Vector2(420, 300)
