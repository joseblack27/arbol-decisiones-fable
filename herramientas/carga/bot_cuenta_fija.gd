# =============================================================================
# bot_cuenta_fija.gd — conecta con un nombre FIJO (pasado por argumento) y
# solo informa si el jugador propio llegó a spawnear. Pensado para correrse
# dos veces como procesos SEPARADOS con el mismo --nombre: la primera corrida
# crea la cuenta, la segunda la reconecta y carga la partida guardada — así
# se reproduce "volver a entrar" de verdad, sin artificios de reconexión
# dentro del mismo proceso.
#   godot --headless --path . --script res://herramientas/carga/bot_cuenta_fija.gd -- --ip=127.0.0.1 --nombre=X
# =============================================================================
extends SceneTree

var _ip := "127.0.0.1"
var _nombre := "BotCuentaFija"
var _mundo: Node2D
var _jugador: CharacterBody2D
var _tiempo := 0.0


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
		print("[BOT] conectando como '%s' a %s:8920" % [_nombre, _ip])
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
				print("[BOT] jugador propio encontrado en %s, vida=%s" % [
					propio.global_position, propio.get_node("VidaComponente").obtener_vida()])
				quit(0)
				return true
		if _tiempo > 25.0:
			print("[BOT] ABANDONA: nunca spawneó.")
			quit(1)
			return true
	return false
