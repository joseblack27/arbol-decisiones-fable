# =============================================================================
# bot_reconexion.gd — conecta con un nombre FIJO (a diferencia de los demás
# bots, que usan un nombre único por corrida), se desconecta, y vuelve a
# conectar con el MISMO nombre — para reproducir "cargar una partida
# existente" en vez de "cuenta nueva", que es la diferencia real frente al
# reporte del usuario ("el jugador no sale" — su conexión SÍ abrió la base
# de datos de partidas, a diferencia de una cuenta nueva).
#   godot --headless --path . --script res://herramientas/carga/bot_reconexion.gd -- --ip=127.0.0.1 --nombre=X
# =============================================================================
extends SceneTree

var _ip := "127.0.0.1"
var _nombre := "BotReconexionFijo"
var _mundo: Node2D
var _jugador: CharacterBody2D
var _tiempo := 0.0
var _ronda := 1


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ip="):
			_ip = arg.substr(5)
		elif arg.begins_with("--nombre="):
			_nombre = arg.substr(9)


func _process(delta: float) -> bool:
	_tiempo += delta

	if _mundo == null:
		var utils = root.get_node("/root/Utils")
		utils.ip_conexion = _ip
		utils.puerto_conexion = 8920
		utils.modo_local_pruebas = false
		utils.nombre_conexion = _nombre
		print("[BOT] ronda %d: conectando como '%s' a %s:8920" % [_ronda, _nombre, _ip])
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
				print("[BOT] ronda %d: jugador propio encontrado en %s" % [_ronda, propio.global_position])
		if _jugador == null:
			if _tiempo > 20.0:
				print("[BOT] ronda %d: ABANDONA, nunca spawneó." % _ronda)
				if _ronda == 1:
					_reintentar_ronda_2()
					return false
				quit(1)
				return true
			return false

	if _ronda == 1:
		print("[BOT] ronda 1 OK — cerrando la conexión para simular reconexión...")
		var mp := root.get_multiplayer().multiplayer_peer
		if mp:
			mp.close()
		_mundo.queue_free()
		_mundo = null
		_jugador = null
		_ronda = 2
		_tiempo = 0.0
		return false

	print("[BOT] ronda 2 OK — la reconexión con partida existente funciona.")
	quit(0)
	return true


func _reintentar_ronda_2() -> void:
	_ronda = 2
	_tiempo = 0.0
	_jugador = null
	_mundo = null
