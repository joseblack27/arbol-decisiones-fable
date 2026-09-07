# =============================================================================
# Regresión: el Minero (ver Minero.gd/GestorMinero.gd) es una instancia
# ÚNICA creada por el SERVIDOR bajo GestorNiveles.contenedor_errantes()
# ("NPCsErrantes" en Mundo.tscn/ServidorDedicado.tscn) — mismo diseño que el
# Leñador. Esa creación solo pasa server-side (multiplayer.is_server()); lo
# que hace que el nodo también exista del lado del CLIENTE es el
# MultiplayerSpawner "GeneradorNPCsErrantes" colgado de ese contenedor, que
# replica automáticamente cualquier hijo agregado CUYA ESCENA esté en su
# lista _spawnable_scenes.
#
# Bug real: Minero.tscn nunca se agregó a esa lista (a diferencia de
# Lenador.tscn/Cazador.tscn) — el servidor lo instanciaba igual y su propia
# máquina de estados funcionaba (ver prueba_minero_recorrido_completo.gd),
# pero ningún cliente conectado recibía jamás el nodo — "el minero no se ve"
# reportado en juego. El MultiplayerSpawner vive en DOS escenas (Mundo.tscn,
# el cliente real, y ServidorDedicado.tscn, lo que corre en Docker) — las
# dos necesitan la entrada o el bug reaparece en una sola de las dos.
#   godot --headless --path . --script res://pruebas/prueba_minero_replicado_por_spawner.gd
# =============================================================================
extends SceneTree

const _RUTA_MINERO := "res://escenas/npc/minero/Minero.tscn"


func _process(_delta: float) -> bool:
	var mundo_ok := _tiene_minero("res://escenas/mundo/Mundo.tscn")
	print("Mundo.tscn (cliente real) replica Minero.tscn (esperado true): %s" % mundo_ok)

	var servidor_ok := _tiene_minero("res://escenas/mundo/ServidorDedicado.tscn")
	print("ServidorDedicado.tscn (Docker) replica Minero.tscn (esperado true): %s" % servidor_ok)

	var exito := mundo_ok and servidor_ok
	print("PRUEBA MINERO REPLICADO POR SPAWNER %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true


func _tiene_minero(ruta_escena: String) -> bool:
	var escena := load(ruta_escena) as PackedScene
	var raiz := escena.instantiate()
	var spawner := raiz.get_node_or_null("NPCsErrantes/GeneradorNPCsErrantes") as MultiplayerSpawner
	var tiene := false
	if spawner:
		for i in spawner.get_spawnable_scene_count():
			if spawner.get_spawnable_scene(i) == _RUTA_MINERO:
				tiene = true
				break
	raiz.free()
	return tiene
