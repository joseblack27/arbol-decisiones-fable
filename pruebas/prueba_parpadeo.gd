# =============================================================================
# Prueba de HabilidadParpadeo:
#   1. Sin obstáculos: teletransporta exactamente "distancia_parpadeo" en la
#      dirección apuntada.
#   2. Con un muro (capa 1) en el medio: se detiene antes del obstáculo.
#   3. Con un mob (capa 2) en el medio: lo ATRAVIESA y llega completo — los
#      enemigos ya no son obstáculo del parpadeo (los personajes no chocan
#      físicamente entre sí, así que caer solapado es inofensivo; frenar el
#      teletransporte en un mob era puro estorbo, reportado en juego real).
#   godot --headless --path . --script res://pruebas/prueba_parpadeo.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _entidad: CharacterBody2D
var _habilidad: Node
var _muro: StaticBody2D
var _mob: StaticBody2D
var _libre_ok := false
var _muro_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		5:
			# Sin obstáculos: debería llegar entero a 200px a la derecha.
			_habilidad.activar(Vector2.RIGHT, 1.0)
		6:
			print("Parpadeo libre (esperado (200,0)): %s" % _entidad.global_position)
			_libre_ok = _entidad.global_position.is_equal_approx(Vector2(200, 0))
			print("Parpadeo libre correcto: %s" % _libre_ok)
			_agregar_muro()
			_entidad.global_position = Vector2.ZERO
		8:
			_habilidad.activar(Vector2.RIGHT, 1.0)
		9:
			var x_muro: float = _entidad.global_position.x
			print("Parpadeo bloqueado por muro (capa 1) en x=80 (esperado < 80): %.1f" % x_muro)
			_muro_ok = x_muro < 80.0 and x_muro > 0.0
			_muro.queue_free()
			_entidad.global_position = Vector2.ZERO
			_agregar_mob()
		11:
			_habilidad.activar(Vector2.RIGHT, 1.0)
		12:
			return _informar()
	return false


func _montar() -> void:
	var escena := Node2D.new()
	root.add_child(escena)
	current_scene = escena

	_entidad = CharacterBody2D.new()
	escena.add_child(_entidad)
	var forma := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 8.0
	forma.shape = circ
	_entidad.add_child(forma)

	var contenedor := Marker2D.new()
	contenedor.name = "Habilidades"
	_entidad.add_child(contenedor)

	var guion := load("res://escenas/habilidades/parpadeo/HabilidadParpadeo.gd") as GDScript
	_habilidad = guion.new()
	_habilidad.set("distancia_parpadeo", 200.0)
	_habilidad.set("duracion_recarga", 0.0)
	contenedor.add_child(_habilidad)
	_habilidad.entidad_dueña = _entidad


func _agregar_muro() -> void:
	_muro = StaticBody2D.new()
	_muro.collision_layer = 1
	_muro.global_position = Vector2(80, 0)
	var forma := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 200)
	forma.shape = rect
	_muro.add_child(forma)
	current_scene.add_child(_muro)


## Mismo criterio que Enemigo.gd real: capa 2, su capa PROPIA — que el
## parpadeo debe IGNORAR (solo el mundo, capa 1, lo frena).
func _agregar_mob() -> void:
	_mob = StaticBody2D.new()
	_mob.collision_layer = 2
	_mob.global_position = Vector2(80, 0)
	var forma := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 10.0
	forma.shape = circ
	_mob.add_child(forma)
	current_scene.add_child(_mob)


func _informar() -> bool:
	var x_mob: float = _entidad.global_position.x
	print("Parpadeo ATRAVIESA al mob (capa 2) en x=80 (esperado 200): %.1f" % x_mob)
	var mob_ok := is_equal_approx(x_mob, 200.0)
	var exito := _libre_ok and _muro_ok and mob_ok
	print("PRUEBA PARPADEO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
