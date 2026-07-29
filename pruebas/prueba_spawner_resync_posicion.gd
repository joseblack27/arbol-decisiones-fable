# =============================================================================
# Prueba de SpawnerMobs._recibir_mobs_existentes(): si el mob YA existe bajo
# el contenedor (simula el catch-up automático del MultiplayerSpawner nativo
# a un peer que se conecta tarde — a veces sí dispara, pero SIN posición,
# porque Enemigo no usa Synchronizer para eso a propósito), el resync debe
# IGUAL pisarle la posición real en vez de saltárselo por "ya existe".
# Antes de este fix se saltaba de largo y el mob quedaba pegado en el origen
# del contenedor — el "todos los mobs spawnean en el centro" reportado en
# juego real.
#   godot --headless --path . --script res://pruebas/prueba_spawner_resync_posicion.gd
# =============================================================================
extends SceneTree

var _contenedor: Node2D
var _spawner
var _mob_preexistente: Node2D


func _process(_delta: float) -> bool:
	_montar()
	return _informar()


func _montar() -> void:
	_contenedor = Node2D.new()
	root.add_child(_contenedor)
	current_scene = _contenedor

	_spawner = (load("res://escenas/enemigos/SpawnerMobs.gd") as GDScript).new()
	_contenedor.add_child(_spawner)
	_spawner.set("_contenedor", _contenedor)

	# Simula el mob que el MultiplayerSpawner nativo ya instanció SOLO
	# (catch-up automático), quieto en el origen porque nadie le mandó su
	# posición todavía.
	_mob_preexistente = Node2D.new()
	_mob_preexistente.name = "EnemigoRaton"
	_contenedor.add_child(_mob_preexistente)


func _informar() -> bool:
	var pos_real := Vector2(345.0, -678.0)
	_spawner.call(
		"_recibir_mobs_existentes",
		[["res://escenas/enemigos/EnemigoRaton.tscn", "EnemigoRaton", pos_real]],
	)
	var pos_final: Vector2 = _mob_preexistente.global_position
	print("Posición tras resync (esperado %s): %s" % [pos_real, pos_final])
	# Confirma que NO se creó un segundo nodo (sigue siendo el mismo, no
	# uno duplicado con nombre distinto).
	var un_solo_nodo := _contenedor.get_child_count() == 2  # spawner + el mob
	print("No duplicó el nodo (esperado true): %s" % un_solo_nodo)

	var exito := pos_final.is_equal_approx(pos_real) and un_solo_nodo
	print("PRUEBA SPAWNER RESYNC POSICION %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
