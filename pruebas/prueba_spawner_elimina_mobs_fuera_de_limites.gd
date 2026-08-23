# =============================================================================
# Prueba: SpawnerMobs.gd debe eliminar (no reposicionar) a cualquier mob
# vivo que haya quedado fuera de la malla de navegación — bug real
# reportado: "los respawn de los mobs a veces quedan fuera del mapa". El
# punto de GENERACIÓN en sí ya se valida (ver prueba_spawner_posicion_
# valida.gd) — esto cubre la red de seguridad APARTE para un mob que ya
# estaba adentro y terminó afuera con el tiempo (deambular/huida
# empujándolo más allá del borde), llamando _revisar_mobs_fuera_de_
# limites() directo en vez de esperar el timer real (_INTERVALO_REVISION_
# LIMITES, 5s) para que la prueba sea rápida.
#   godot --headless --path . --script res://pruebas/prueba_spawner_elimina_mobs_fuera_de_limites.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _nivel: Node
# Sin tipar como SpawnerMobs — mismo motivo que prueba_spawner_posicion_
# valida.gd: ese script referencia el autoload Utils, y el análisis
# estático de esta prueba lo compilaría antes de que los autoloads existan.
var _spawner
var _mapa: RID
var _mob_afuera: Node2D
var _mob_adentro: Node2D


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_cargar_nivel()
		20:
			# Esperar a que la malla de navegación sincronice antes de ubicar
			# nada (misma cautela que el resto de pruebas de navegación).
			_montar_spawner_y_mobs()
		25:
			_spawner._revisar_mobs_fuera_de_limites()
		30:
			# queue_free() es diferido — dar un par de fotogramas de margen
			# para que el nodo ya esté realmente fuera del árbol.
			return _informar()
	return false


func _cargar_nivel() -> void:
	_nivel = (load("res://escenas/niveles/NivelPradera.tscn") as PackedScene).instantiate()
	root.add_child(_nivel)
	current_scene = _nivel
	_mapa = _nivel.mapa_navegacion()


func _montar_spawner_y_mobs() -> void:
	var limites: Rect2 = _nivel.call("limites_camara")
	var punto_valido: Vector2 = NavigationServer2D.map_get_closest_point(_mapa, limites.position + limites.size / 2.0)

	_spawner = (load("res://escenas/enemigos/SpawnerMobs.gd") as GDScript).new()
	var mobs: Array[PackedScene] = [load("res://escenas/enemigos/EnemigoRaton.tscn")]
	_spawner.lista_mobs = mobs
	_spawner.maximo_mobs = 10
	_spawner.cantidad_inicial = 0
	_nivel.get_node("Enemigos").add_child(_spawner)
	_spawner.global_position = punto_valido

	# "Adentro": sobre la malla real — la revisión no debe tocarlo.
	_mob_adentro = (load("res://escenas/enemigos/EnemigoRaton.tscn") as PackedScene).instantiate()
	_nivel.get_node("Enemigos").add_child(_mob_adentro, true)
	_mob_adentro.global_position = punto_valido
	_spawner.get("_vivos").append(_mob_adentro)

	# "Afuera": muy lejos de cualquier punto transitable — simula lo que
	# deambular/huida haría con el tiempo, sin pasar por la validación de
	# generación (esta prueba no cubre esa parte, ya cubierta aparte).
	_mob_afuera = (load("res://escenas/enemigos/EnemigoRaton.tscn") as PackedScene).instantiate()
	_nivel.get_node("Enemigos").add_child(_mob_afuera, true)
	_mob_afuera.global_position = limites.position - Vector2(5000, 5000)
	_spawner.get("_vivos").append(_mob_afuera)


func _informar() -> bool:
	var afuera_eliminado := not is_instance_valid(_mob_afuera)
	print("El mob fuera de la malla fue eliminado (esperado true): %s" % afuera_eliminado)

	var adentro_sigue := is_instance_valid(_mob_adentro)
	print("El mob sobre la malla NO se tocó (esperado true): %s" % adentro_sigue)

	var vivos_actuales: Array = _spawner.get("_vivos")
	var solo_queda_el_de_adentro: bool = vivos_actuales.size() == 1 and vivos_actuales[0] == _mob_adentro
	print("_vivos solo conserva al de adentro (esperado true): %s" % solo_queda_el_de_adentro)

	var exito: bool = afuera_eliminado and adentro_sigue and solo_queda_el_de_adentro
	print("PRUEBA SPAWNER ELIMINA MOBS FUERA DE LIMITES %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
