# =============================================================================
# Prueba: el spawner de mobs no debe instanciar a nadie fuera del mapa ni
# sobre casillas no transitables (agua, huecos). Se coloca un spawner justo
# en la esquina del nivel con un radio_spawn enorme (para que la mayoría de
# candidatos al azar caigan fuera del mapa o sobre agua) y se comprueba que
# TODOS los mobs generados terminan sobre la malla de navegación.
#   godot --headless --path . --script res://pruebas/prueba_spawner_posicion_valida.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _nivel: Node
var _spawner: SpawnerMobs
var _mapa: RID


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_cargar_nivel()
		20:
			# Esperar a que la malla de navegación sincronice antes de ubicar
			# el spawner (misma cautela que el resto de pruebas de navegación).
			_montar_spawner()
		100:
			return _informar()
	return false


func _cargar_nivel() -> void:
	_nivel = (load("res://niveles/NivelPradera.tscn") as PackedScene).instantiate()
	root.add_child(_nivel)
	current_scene = _nivel
	_mapa = _nivel.get_node("Enemigos").get_world_2d().navigation_map


func _montar_spawner() -> void:
	var limites: Rect2 = _nivel.call("limites_camara")
	# Punto transitable más cercano a la esquina superior izquierda del
	# nivel: así el spawner queda sobre terreno válido (como lo colocaría
	# cualquier diseñador) pero pegado al borde del mapa, para que la mitad
	# de su radio de generación apunte fuera de los límites o hacia huecos.
	var punto_borde: Vector2 = NavigationServer2D.map_get_closest_point(_mapa, limites.position)

	_spawner = SpawnerMobs.new()
	_spawner.lista_mobs = [load("res://enemigos/EnemigoRaton.tscn")]
	_spawner.maximo_mobs = 10
	_spawner.cantidad_inicial = 10
	# Radio deliberadamente enorme: sin la validación, muchos candidatos
	# caerían fuera del rectángulo del nivel o sobre huecos/agua.
	_spawner.radio_spawn = 800.0
	_nivel.get_node("Enemigos").add_child(_spawner)
	_spawner.global_position = punto_borde


func _informar() -> bool:
	var tolerancia := 8.0
	var todos_validos := true
	var vivos: Array = _spawner.get("_vivos")
	var contados := vivos.size()
	for mob in vivos:
		if not (mob is Node2D):
			continue
		var pos: Vector2 = (mob as Node2D).global_position
		var mas_cercano: Vector2 = NavigationServer2D.map_get_closest_point(_mapa, pos)
		var distancia := pos.distance_to(mas_cercano)
		if distancia > tolerancia:
			todos_validos = false
			print("Mob fuera de la malla de navegación: pos=%s distancia=%.1f" % [pos, distancia])
	print("Mobs generados: %d, todos sobre malla transitable: %s" % [contados, todos_validos])
	var exito := contados == 10 and todos_validos
	print("PRUEBA SPAWNER POSICION VALIDA %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
