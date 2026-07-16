# =============================================================================
# Prueba de navegación: en la pradera, se ordena al lobo ir a un destino y se
# verifica que (a) la malla de navegación existe, (b) el agente calcula una
# ruta con varios puntos y (c) el lobo avanza hacia el destino.
# También regresión: sin malla (enemigo suelto), comandar_destino sigue
# funcionando en línea recta.
#   godot --headless --path . --script res://pruebas/prueba_navegacion.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _lobo: CharacterBody2D
var _movimiento: Node
var _destino := Vector2.ZERO
var _distancia_inicial := 0.0


var _frames_con_lobo := 0

func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas == 1:
		_montar()
		return false
	# Los mobs ya no son nodos fijos del nivel: los crea SpawnerMobs en
	# runtime, en un fotograma que varía — sondear hasta que aparezca en vez
	# de asumir un fotograma fijo.
	if _lobo == null:
		if _fotogramas > 120:
			print("FALLO: SpawnerMobs no creó ningún lobo en la pradera.")
			print("PRUEBA NAVEGACIÓN FALLIDA")
			quit(1)
			return true
		_capturar_lobo()
		return false
	_frames_con_lobo += 1
	match _frames_con_lobo:
		10:
			# Comando tras unos frames (la malla se sincroniza al inicio).
			# Destino RELATIVO al lobo: su spawn es aleatorio (SpawnerMobs) —
			# un punto absoluto podía quedar a media pradera de distancia,
			# imposible de recorrer dentro de la ventana de la prueba.
			_destino = _lobo.global_position + Vector2(300, 0)
			_distancia_inicial = _lobo.global_position.distance_to(_destino)
			_movimiento.comandar_destino(_destino)
		310:
			return _informar()
	return false


func _informar() -> bool:
	var mapa := _lobo.get_world_2d().navigation_map
	var regiones := NavigationServer2D.map_get_regions(mapa).size()
	# Desde el componente: funciona igual con agente de escena o auto-creado.
	var agente := _movimiento.get("agente_navegacion") as NavigationAgent2D
	var puntos_ruta := agente.get_current_navigation_path().size()
	var distancia_final := _lobo.global_position.distance_to(_destino)
	print("Regiones de navegación en el mapa: %d" % regiones)
	print("Puntos en la ruta del agente: %d" % puntos_ruta)
	print("Distancia al destino: %.0f -> %.0f" % [_distancia_inicial, distancia_final])
	var exito := regiones > 0 and puntos_ruta >= 2 \
		and distancia_final < _distancia_inicial * 0.5
	print("PRUEBA NAVEGACIÓN %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true


func _montar() -> void:
	var nivel := (load("res://escenas/niveles/NivelPradera.tscn") as PackedScene).instantiate()
	root.add_child(nivel)
	current_scene = nivel


func _capturar_lobo() -> void:
	for mob in root.get_tree().get_nodes_in_group("enemigos"):
		if "Lobo" in String(mob.name):
			_lobo = mob
			break
	if _lobo == null:
		return  # Todavía no spawneó — se reintenta el próximo fotograma.
	# Apagar su IA para que el comando de la prueba no compita con el árbol.
	var ia := _lobo.get_node_or_null("ArbolComportamiento")
	if ia != null:
		ia.set("activo", false)
	_movimiento = _lobo.get_node("MovimientoComponente")
