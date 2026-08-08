# =============================================================================
# bot_arana_reina.gd — verificación en vivo contra el servidor real: viaja
# Pradera -> Camino -> Nido de la Araña Reina, y confirma que ahí aparece
# SOLO la Araña Reina (sin otros mobs sueltos).
#   godot --headless --path . --script res://herramientas/carga/bot_arana_reina.gd -- --ip=127.0.0.1
# =============================================================================
extends SceneTree

var _ip := "127.0.0.1"
var _mundo: Node2D
var _jugador: CharacterBody2D
var _fase := "conectando"
var _tiempo := 0.0
var _tiempo_fase := 0.0

const _TOPE_FASE := 45.0


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ip="):
			_ip = arg.substr(5)


func _process(delta: float) -> bool:
	_tiempo += delta
	_tiempo_fase += delta

	if _fase == "conectando" and _mundo == null:
		var utils = root.get_node("/root/Utils")
		utils.ip_conexion = _ip
		utils.puerto_conexion = 8920
		utils.modo_local_pruebas = false
		utils.nombre_conexion = "BotReina%d" % (Time.get_unix_time_from_system() as int % 100000)
		print("[BOT] conectando a %s:8920" % _ip)
		_mundo = (load("res://escenas/mundo/Mundo.tscn") as PackedScene).instantiate()
		root.add_child(_mundo)
		current_scene = _mundo
		return false

	if _jugador == null or not is_instance_valid(_jugador):
		var jugadores := _mundo.get_node_or_null("Jugadores")
		if jugadores != null:
			var id_propio := root.get_multiplayer().get_unique_id()
			var propio := jugadores.get_node_or_null(str(id_propio))
			if propio != null:
				_jugador = propio
				print("[BOT] jugador propio encontrado en nivel '%s'" % _nivel())
				_cambiar_fase("yendo_a_camino")
		if _jugador == null:
			if _tiempo > 30.0:
				print("[BOT] ABANDONA: nunca spawneó.")
				quit(1)
				return true
			return false

	match _fase:
		"yendo_a_camino":
			_mover(_hacia_portal("PortalACamino", Vector2.LEFT))
			if _nivel() == "Camino":
				print("[BOT] entró a Camino en %s" % _jugador.global_position)
				_mover(Vector2.ZERO)
				_cambiar_fase("yendo_al_nido")
			elif _tiempo_fase > _TOPE_FASE:
				print("[BOT] ABANDONA: nunca llegó a Camino (sigue en '%s')" % _nivel())
				quit(1)
				return true
			return false

		"yendo_al_nido":
			# Ventana de gracia tras llegar a Camino antes de buscar el portal
			# nuevo (mismo criterio que bot_viaje_cueva.gd).
			if _tiempo_fase < 2.0:
				return false
			_mover(_hacia_portal("PortalANidoArañaReina", Vector2.LEFT))
			if _nivel() == "Nido de la Araña Reina":
				print("[BOT] entró al Nido en %s" % _jugador.global_position)
				_mover(Vector2.ZERO)
				_cambiar_fase("verificando")
			elif _tiempo_fase > _TOPE_FASE:
				print("[BOT] ABANDONA: nunca llegó al Nido (sigue en '%s')" % _nivel())
				quit(1)
				return true
			return false

		"verificando":
			if _tiempo_fase < 2.0:
				return false
			var nivel = root.get_node("/root/GestorNiveles").nivel_de_jugador(_jugador)
			var contenedor = nivel.get_node_or_null("Enemigos") if nivel else null
			if contenedor == null:
				print("[BOT] ABANDONA: nivel sin contenedor Enemigos.")
				quit(1)
				return true
			var nombres: Array[String] = []
			var otros_mobs: Array[String] = []
			for hijo in contenedor.get_children():
				nombres.append(String(hijo.name))
				# SpawnerMobs/SpawnerRed son infraestructura (el generador
				# inactivo para registro de red y el MultiplayerSpawner que
				# arma NivelBase), no mobs — lo que importa es que no haya
				# NINGÚN otro Enemigo real aparte de la reina.
				if hijo is Enemigo and not (hijo.name as String).begins_with("EnemigoArañaReina"):
					otros_mobs.append(String(hijo.name))
			print("[BOT] Enemigos en el nido: %s" % str(nombres))
			var solo_la_reina := otros_mobs.is_empty()
			print("[BOT] ¿Solo está la Araña Reina (sin otros mobs)? %s" % solo_la_reina)
			quit(0 if solo_la_reina else 1)
			return true

	if _tiempo_fase > _TOPE_FASE:
		print("[BOT] ABANDONA en la fase '%s' tras %.0fs." % [_fase, _TOPE_FASE])
		quit(1)
		return true
	return false


func _cambiar_fase(nueva: String) -> void:
	_fase = nueva
	_tiempo_fase = 0.0
	print("[BOT] --> fase '%s'" % nueva)


func _mover(dir: Vector2) -> void:
	root.get_node("/root/SeñalManager").emitir("joystick_movimiento", "", [dir])


func _hacia_portal(nombre: String, respaldo: Vector2) -> Vector2:
	var nivel = root.get_node("/root/GestorNiveles").nivel_actual()
	if nivel == null or not is_instance_valid(_jugador):
		return respaldo
	var portal = nivel.get_node_or_null(nombre)
	if portal == null:
		return respaldo
	var delta: Vector2 = (portal as Node2D).global_position - _jugador.global_position
	if delta.length() < 1.0:
		return respaldo
	return delta.normalized()


func _nivel() -> String:
	var nivel = root.get_node("/root/GestorNiveles").nivel_actual()
	return nivel.nombre_nivel if nivel != null else "<ninguno>"
