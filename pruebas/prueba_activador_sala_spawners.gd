# =============================================================================
# Prueba de ActivadorSalaSpawners: un jugador pisando el área activa los
# SpawnerMobs conectados (que arrancan con activo=false), y NO reacciona a
# un cuerpo que no sea un jugador (un mob de prueba, por ejemplo). Sin red
# real (SceneTree suelto, Utils.en_red() da false) -- mismo criterio que
# prueba_trampa.gd/prueba_cepo.gd para probar overlap de Area2D real vía
# física, sin levantar cliente+servidor.
#   godot --headless --path . --script res://pruebas/prueba_activador_sala_spawners.gd
# =============================================================================
extends SceneTree

var _activador
var _spawner1
var _spawner2
var _no_jugador
var _fotogramas := 0

var _spawner1_ok_antes := false
var _spawner2_ok_antes := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		5:
			_spawner1_ok_antes = not _spawner1.activo
			_spawner2_ok_antes = not _spawner2.activo
			print("Spawners arrancan desactivados (esperado true): %s" % (_spawner1_ok_antes and _spawner2_ok_antes))
			# Cuerpo que NO es jugador, pisando el área -- no debe activar nada.
			_no_jugador.global_position = _activador.global_position
		10:
			print("Un cuerpo que no es jugador NO activa los spawners (esperado true): %s" % (
				not _spawner1.activo and not _spawner2.activo))
			_no_jugador.queue_free()
		12:
			_montar_jugador()
		20:
			return _informar()
	return false


func _montar() -> void:
	_activador = (load("res://escenas/objetos/ActivadorSalaSpawners.tscn") as PackedScene).instantiate()
	_activador.global_position = Vector2(500, 500)
	root.add_child(_activador)

	_spawner1 = (load("res://escenas/enemigos/SpawnerMobs.gd") as GDScript).new()
	_spawner1.activo = false
	root.add_child(_spawner1)

	_spawner2 = (load("res://escenas/enemigos/SpawnerMobs.gd") as GDScript).new()
	_spawner2.activo = false
	root.add_child(_spawner2)

	var rutas: Array[NodePath] = [_spawner1.get_path(), _spawner2.get_path()]
	_activador.spawners = rutas

	# Cuerpo físico ajeno (ni jugador ni con el método activar) -- confirma
	# que el filtro por grupo "jugadores" es real, no "cualquier cosa que
	# entre".
	_no_jugador = CharacterBody2D.new()
	_no_jugador.collision_layer = 8
	_no_jugador.global_position = Vector2(-9000, -9000)
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 8.0
	forma.shape = circulo
	_no_jugador.add_child(forma)
	root.add_child(_no_jugador)


func _montar_jugador() -> void:
	var jugador := CharacterBody2D.new()
	jugador.add_to_group("jugadores")
	jugador.collision_layer = 8
	jugador.global_position = _activador.global_position
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 8.0
	forma.shape = circulo
	jugador.add_child(forma)
	root.add_child(jugador)


func _informar() -> bool:
	var activo_1: bool = _spawner1.activo
	var activo_2: bool = _spawner2.activo
	print("El jugador activa los DOS spawners de la sala (esperado true): %s" % (activo_1 and activo_2))

	var exito := _spawner1_ok_antes and _spawner2_ok_antes and activo_1 and activo_2
	print("PRUEBA ACTIVADOR SALA SPAWNERS %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
