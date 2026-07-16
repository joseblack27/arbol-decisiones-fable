# =============================================================================
# Prueba: al cargar un nivel, la cámara del jugador recibe límites que
# coinciden con el rectángulo real del Terreno (no el infinito por defecto),
# y al cambiar de nivel (portal) se actualizan a los del nivel nuevo.
#   godot --headless --path . --script res://pruebas/prueba_limites_camara.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _mundo: Node2D
var _limites_pradera := Rect2()


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			# Modo local de pruebas: sin esto, Mundo reintenta conectarse al
			# servidor para siempre (multijugador puro) — o peor, se conecta
			# de verdad al Docker si esta corriendo y la prueba deja de ser
			# determinista. Ver Mundo._arrancar_modo_prueba_local().
			root.get_node("/root/Utils").modo_local_pruebas = true
			_mundo = (load("res://escenas/mundo/Mundo.tscn") as PackedScene).instantiate()
			root.add_child(_mundo)
			current_scene = _mundo
		# +150 fotogramas de margen: Mundo.gd ahora SIEMPRE intenta conectarse
		# a un servidor primero y solo cae al modo local tras ~2s (120
		# fotogramas) de espera — el jugador/nivel no existen antes de eso.
		190:
			_limites_pradera = _leer_limites()
			var nivel := _nivel()
			var esperado := nivel.limites_camara()
			print("Límites tras cargar Pradera: %s (esperado %s)" % [_limites_pradera, esperado])
			if not _limites_pradera.is_equal_approx(esperado):
				print("PRUEBA LIMITES CAMARA FALLIDA (no coincide con limites_camara())")
				quit(1)
				return true
		250:
			var portal := _nivel().get_node("PortalACueva") as Node2D
			_jugador().global_position = portal.global_position
		370:
			return _informar()
	return false


func _informar() -> bool:
	var limites_cueva := _leer_limites()
	var nivel := _nivel()
	print("Nivel tras portal: %s | límites: %s" % [nivel.nombre_nivel if nivel else "?", limites_cueva])
	var cambiaron := not limites_cueva.is_equal_approx(_limites_pradera)
	var son_finitos := absf(limites_cueva.position.x) < 1000000.0
	var exito := cambiaron and son_finitos and nivel != null and nivel.nombre_nivel == "Cueva"
	print("PRUEBA LIMITES CAMARA %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true


func _leer_limites() -> Rect2:
	var camara := _jugador().get_node("Camara") as Camera2D
	return Rect2(
		Vector2(camara.limit_left, camara.limit_top),
		Vector2(camara.limit_right - camara.limit_left, camara.limit_bottom - camara.limit_top),
	)


func _nivel() -> NivelBase:
	return root.get_node("/root/GestorNiveles").nivel_actual()


func _jugador() -> CharacterBody2D:
	# Desde la migración a multijugador, Mundo.tscn ya no tiene un "Jugador"
	# fijo: el jugador de un solo jugador se crea en modo local bajo
	# "Jugadores/local" (ver Mundo.gd, _arrancar_modo_local()).
	return _mundo.get_node("Jugadores/local")
