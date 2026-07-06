# =============================================================================
# Prueba del flujo de combate del lobo refactorizado:
# un señuelo (cuerpo con VidaComponente en grupo "jugadores") aparece dentro
# de la visión → el lobo debe fijarlo como objetivo, acercarse y elegir
# una habilidad con su SelectorHabilidades.
#   godot --headless --path . --script res://pruebas/prueba_lobo_combate.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _lobo: Node2D
var _senuelo: CharacterBody2D
var _distancia_inicial := 0.0
var _detecto := false
var _se_acerco := false
var _uso_habilidad := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas == 1:
		_montar_escena()
		return false
	if _fotogramas < 10:
		return false

	var memoria = _lobo.get("memoria")
	if memoria.obtener("objetivo") == _senuelo:
		_detecto = true
	var distancia: float = _lobo.global_position.distance_to(_senuelo.global_position)
	if _detecto and distancia < _distancia_inicial - 20.0:
		_se_acerco = true
	if memoria.obtener("habilidad_activa") != null:
		_uso_habilidad = true

	if _fotogramas > 400:
		print("Detectó al señuelo: %s" % _detecto)
		print("Se acercó: %s (%.0f -> %.0f px)" % [_se_acerco, _distancia_inicial, distancia])
		print("Eligió habilidad: %s" % _uso_habilidad)
		var exito := _detecto and _se_acerco and _uso_habilidad
		print("PRUEBA COMBATE %s" % ("OK" if exito else "FALLIDA"))
		quit(0 if exito else 1)
		return true
	return false


func _montar_escena() -> void:
	_lobo = (load("res://enemigos/EnemigoLobo.tscn") as PackedScene).instantiate()
	root.add_child(_lobo)
	_lobo.global_position = Vector2(300, 300)

	# Señuelo: cuerpo en grupo "jugadores" con un área VidaComponente detectable.
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
	# Enemigo.gd fija el objetivo con area.owner: en nodos creados por código
	# hay que asignarlo a mano (en escenas reales lo asigna el editor).
	vida.owner = _senuelo
	_senuelo.global_position = Vector2(460, 300)
	_distancia_inicial = _lobo.global_position.distance_to(_senuelo.global_position)
