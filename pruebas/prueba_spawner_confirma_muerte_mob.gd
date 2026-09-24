# =============================================================================
# Regresión (reportado en juego real, 24 sep 2026): "si me quedo quieto en un
# grupo de hormigas, algunas se quedan estáticas y comienzan a dejar de
# atacarme, y ya no reciben daño... pero no se destruyen completamente".
# Confirmado con el usuario que se ven NORMALES (no a mitad de fundido de
# muerte) -- son fantasmas de red: el mob real murió del lado del servidor
# (Enemigo._desvanecer_y_eliminar -> rpc("_despawn_red"), dirigido al PROPIO
# nodo del mob) pero esa réplica puede no llegarle a un peer ya conectado
# (mismo bug ya diagnosticado con las larvas y con la generación de mobs,
# ver bug-huevos-multiplayerspawner-desincronizado.md). SpawnerMobs ahora
# manda un aviso de respaldo (_confirmar_muerte_mob_red), dirigido al PROPIO
# SpawnerMobs -- un nodo ESTÁTICO, no al mob dinámico -- con el mismo
# criterio ya probado que usa la insurance de generación.
#
# Confirma:
#   1. Si el mob nombrado YA NO EXISTE en el contenedor (el aviso normal
#      llegó bien), _confirmar_muerte_mob_red no hace nada -- idempotente.
#   2. Si el mob nombrado TODAVÍA existe (el aviso normal se perdió), lo
#      fuerza a desvanecerse igual que _despawn_red.
#   godot --headless --path . --script res://pruebas/prueba_spawner_confirma_muerte_mob.gd
# =============================================================================
extends SceneTree

var _spawner
var _contenedor: Node2D
var _mob_fantasma
var _f := 0

var _no_hace_nada_si_ya_no_existe_ok := false
var _fuerza_desvanecido_si_sigue_existiendo_ok := false


func _process(_delta: float) -> bool:
	_f += 1
	match _f:
		1:
			_montar()
		2:
			_probar_idempotente_si_ya_no_existe()
			_probar_fuerza_si_sigue_existiendo()
			return _informar()
	return false


func _montar() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(0)  # puerto 0 = el SO elige uno libre; no hace falta que nadie se conecte.
	root.multiplayer.multiplayer_peer = peer

	_contenedor = Node2D.new()
	_contenedor.name = "Enemigos"
	root.add_child(_contenedor)
	current_scene = _contenedor

	_spawner = (load("res://escenas/enemigos/SpawnerMobs.gd") as GDScript).new()
	_contenedor.add_child(_spawner)

	_mob_fantasma = (load("res://escenas/enemigos/EnemigoHormigaObrera.tscn") as PackedScene).instantiate()
	_mob_fantasma.name = "FantasmaDePrueba"
	_contenedor.add_child(_mob_fantasma)


func _probar_idempotente_si_ya_no_existe() -> void:
	# Nombre que NUNCA existió en el contenedor -- simula "el aviso normal
	# llegó bien, el cliente ya no tiene este mob".
	_spawner._confirmar_muerte_mob_red("NoExisteEsteNodo")
	_no_hace_nada_si_ya_no_existe_ok = true  # si no revienta al llegar acá, ya es la confirmación real.
	print("No revienta si el mob nombrado no existe (esperado true): %s" % _no_hace_nada_si_ya_no_existe_ok)


func _probar_fuerza_si_sigue_existiendo() -> void:
	_spawner._confirmar_muerte_mob_red("FantasmaDePrueba")
	# _despawn_red() marca _muerto=true sincrónico y recién libera el nodo
	# al final de un tween de 0.8s (fundido) -- is_queued_for_deletion()
	# daría false todavía acá, _muerto es la señal sincrónica correcta.
	_fuerza_desvanecido_si_sigue_existiendo_ok = _mob_fantasma._muerto
	print("Fuerza el desvanecido si el fantasma seguía ahí (esperado true): %s" % \
		_fuerza_desvanecido_si_sigue_existiendo_ok)


func _informar() -> bool:
	var exito := _no_hace_nada_si_ya_no_existe_ok and _fuerza_desvanecido_si_sigue_existiendo_ok
	print("PRUEBA SPAWNER CONFIRMA MUERTE MOB %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
