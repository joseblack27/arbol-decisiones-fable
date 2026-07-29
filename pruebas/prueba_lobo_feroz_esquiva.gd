# =============================================================================
# Prueba de EnemigoLoboFeroz — esquiva reactiva de parpadeo:
#   1. Una habilidad usada por el propio lobo (self) no dispara esquiva.
#   2. Una habilidad usada por OTRO enemigo (mismo equipo) no dispara esquiva.
#   3. Una habilidad usada por el jugador a más de 100px no dispara esquiva.
#   4. Una habilidad usada por el jugador a <=100px, con la tirada de
#      probabilidad forzada a "éxito" (seed), SÍ mueve al lobo (parpadeo) —
#      y el desplazamiento es perpendicular (90°) a la dirección hacia el
#      jugador, no directamente hacia/lejos de él.
#   godot --headless --path . --script res://pruebas/prueba_lobo_feroz_esquiva.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _lobo
var _otro_lobo
var _jugador


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
			return false
		2:
			return _prueba_self_no_dispara()
		3:
			return _prueba_mismo_equipo_no_dispara()
		4:
			return _prueba_lejos_no_dispara()
		5:
			return _prueba_cerca_dispara_perpendicular()
	return false


func _montar() -> void:
	_lobo = (load("res://escenas/enemigos/EnemigoLoboFeroz.tscn") as PackedScene).instantiate()
	root.add_child(_lobo)
	current_scene = _lobo
	_lobo.global_position = Vector2(0, 0)
	_lobo.add_to_group("enemigos")

	_otro_lobo = (load("res://escenas/enemigos/EnemigoLobo.tscn") as PackedScene).instantiate()
	root.add_child(_otro_lobo)
	_otro_lobo.global_position = Vector2(30, 0)
	_otro_lobo.add_to_group("enemigos")

	_jugador = Node2D.new()
	root.add_child(_jugador)
	_jugador.add_to_group("jugadores")


func _prueba_self_no_dispara() -> bool:
	var pos_antes: Vector2 = _lobo.global_position
	_lobo._on_habilidad_usada_cerca(_lobo, "arañazo")
	var ok: bool = _lobo.global_position == pos_antes
	print("No esquiva ante su propia habilidad (esperado true): %s" % ok)
	return false


func _prueba_mismo_equipo_no_dispara() -> bool:
	var pos_antes: Vector2 = _lobo.global_position
	_lobo._on_habilidad_usada_cerca(_otro_lobo, "arañazo")
	var ok: bool = _lobo.global_position == pos_antes
	print("No esquiva ante habilidad de otro enemigo (esperado true): %s" % ok)
	return false


func _prueba_lejos_no_dispara() -> bool:
	_jugador.global_position = Vector2(500, 0)
	var pos_antes: Vector2 = _lobo.global_position
	_lobo._on_habilidad_usada_cerca(_jugador, "arañazo")
	var ok: bool = _lobo.global_position == pos_antes
	print("No esquiva si el origen está a más de 100px (esperado true): %s" % ok)
	return false


func _prueba_cerca_dispara_perpendicular() -> bool:
	_jugador.global_position = Vector2(80, 0)  # a 80px, dentro del radio de reacción
	# Buscar una semilla donde la primera tirada (probabilidad) sea éxito.
	var s := 0
	while true:
		seed(s)
		if randf() < 0.3:
			break
		s += 1
	seed(s)
	var pos_antes: Vector2 = _lobo.global_position
	# El lobo puede haberse movido un poco entre fotogramas por su propio BT
	# (Deambular) — calcular la dirección real hacia el jugador justo antes
	# de disparar la esquiva, en vez de asumir una posición fija.
	var hacia_jugador: Vector2 = ((_jugador.global_position as Vector2) - pos_antes).normalized()
	_lobo._on_habilidad_usada_cerca(_jugador, "arañazo")
	var pos_despues: Vector2 = _lobo.global_position
	var se_movio := pos_despues != pos_antes
	var desplazamiento := pos_despues - pos_antes
	# Perpendicular = producto punto con la dirección hacia el jugador ~ 0.
	var es_perpendicular := absf(desplazamiento.normalized().dot(hacia_jugador)) < 0.01
	print("Esquiva forzada mueve al lobo (esperado true): %s" % se_movio)
	print("Desplazamiento perpendicular a la dirección del jugador (esperado true): %s (%s)" \
		% [es_perpendicular, desplazamiento])
	return _informar(se_movio and es_perpendicular)


func _informar(ultima_ok: bool) -> bool:
	print("PRUEBA LOBO FEROZ ESQUIVA %s" % ("OK" if ultima_ok else "FALLIDA"))
	quit(0 if ultima_ok else 1)
	return true
