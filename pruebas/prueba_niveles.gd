# =============================================================================
# Prueba del sistema de niveles:
#   1. Mundo arranca y carga NivelPradera (terreno generado, jugador en spawn).
#   2. El jugador pisa el portal → se carga NivelCueva y reaparece en su spawn.
#   3. Los enemigos del nivel anterior ya no existen (se liberaron con él).
#   godot --headless --path . --script res://pruebas/prueba_niveles.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _mundo: Node2D
var _fase1_ok := false
var _celdas_pradera := 0


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
		# +150 fotogramas de margen respecto a los checkpoints originales:
		# Mundo.gd ahora SIEMPRE intenta conectarse a un servidor primero
		# (ver _conectar_como_cliente) y solo cae al modo local tras ~2s
		# (120 fotogramas) de espera — el nivel no existe antes de eso.
		180:
			_verificar_pradera()
		210:
			# Pisar el portal a la cueva (tras la gracia de 1 s de la carga).
			pass
		240:
			var portal := _nivel().get_node("PortalACueva") as Node2D
			_jugador().global_position = portal.global_position
		350:
			return _verificar_cueva_e_informar()
	return false


func _nivel() -> NivelBase:
	# Por ruta y no por identificador: en modo --script los autoloads aún no
	# existen cuando se compila este guion.
	return root.get_node("/root/GestorNiveles").nivel_actual()


func _jugador() -> CharacterBody2D:
	# Desde la migración a multijugador, Mundo.tscn ya no tiene un "Jugador"
	# fijo: el jugador de un solo jugador se crea en modo local bajo
	# "Jugadores/local" (ver Mundo.gd, _arrancar_modo_local()).
	return _mundo.get_node("Jugadores/local")


func _verificar_pradera() -> void:
	var nivel := _nivel()
	if nivel == null:
		print("FALLO: no se cargó ningún nivel.")
		return
	_celdas_pradera = (nivel.get_node("Terreno") as TileMapLayer).get_used_cells().size()
	var distancia_spawn: float = _jugador().global_position \
		.distance_to((nivel.punto_aparicion() as Node2D).global_position)
	print("Nivel inicial: %s | celdas: %d | jugador a %.0f px del spawn" % [
		nivel.nombre_nivel, _celdas_pradera, distancia_spawn,
	])
	_fase1_ok = nivel.nombre_nivel == "Pradera" and _celdas_pradera > 1500 \
		and distancia_spawn < 50.0


func _verificar_cueva_e_informar() -> bool:
	var nivel := _nivel()
	var en_cueva := nivel != null and nivel.nombre_nivel == "Cueva"
	var enemigos_cueva: int = nivel.get_node("Enemigos").get_child_count() if en_cueva else 0
	print("Nivel tras portal: %s | enemigos del nivel: %d" % [
		nivel.nombre_nivel if nivel else "<ninguno>", enemigos_cueva,
	])
	var exito := _fase1_ok and en_cueva and enemigos_cueva == 5
	print("PRUEBA NIVELES %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
