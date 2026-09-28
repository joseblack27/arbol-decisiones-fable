# =============================================================================
# bot_movimiento_red.gd — verificación en vivo del movimiento como ESTADO de
# input (Jugador._enviar_input_red / _recibir_input_red) contra un servidor
# dedicado REAL. Mide la posición AUTORITATIVA que el servidor le devuelve a
# este cliente (_posicion_replicada), no la predicción local.
#
# Por cada tanda: empuja el joystick 1s en una dirección, lo suelta, y
# comprueba que el cuerpo del servidor se movió de verdad y que después de
# soltar se FRENA (el bug de "el personaje se sigue moviendo solo").
# La última tanda cambia de rumbo cada pocos fotogramas antes de soltar.
#
# NUNCA usa la configuración guardada (podría apuntar a producción).
#   godot --headless --path . --script res://herramientas/carga/bot_movimiento_red.gd -- --puerto=8920
# =============================================================================
extends SceneTree

const JoystickBot := preload("res://herramientas/carga/joystick_bot.gd")
const _DIRECCIONES := [Vector2.RIGHT, Vector2.UP, Vector2.LEFT, Vector2.DOWN, Vector2.ZERO]
const _SEGUNDOS_EMPUJE := 1.0
const _SEGUNDOS_PARA_FRENAR := 0.5
const _SEGUNDOS_OBSERVANDO_QUIETO := 1.0

var _puerto := 8920
var _mundo: Node2D
var _jugador
var _nivel_estable: Node
var _segundos_nivel_estable := 0.0
var _tiempo_esperando := 0.0
var _tanda := 0
var _t := 0.0
var _pos_inicio := Vector2.ZERO
var _pos_al_soltar := Vector2.ZERO
var _pos_frenado := Vector2.ZERO
var _fallas: Array[String] = []


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--puerto="):
			_puerto = int(arg.substr(9))


func _process(delta: float) -> bool:
	if _mundo == null:
		var utils = root.get_node("/root/Utils")
		utils.ip_conexion = "127.0.0.1"
		utils.puerto_conexion = _puerto
		utils.modo_local_pruebas = false
		utils.nombre_conexion = "BotMovimiento%d" % (Time.get_unix_time_from_system() as int % 100000)
		# Identidad nueva en memoria: sin esto usa la guardada en esta PC (la
		# misma que el cliente real) y reaparece donde quedó la vez anterior.
		utils._id_jugador_local_cache = utils._generar_uuid()
		_mundo = (load("res://escenas/mundo/Mundo.tscn") as PackedScene).instantiate()
		root.add_child(_mundo)
		current_scene = _mundo
		return false

	_tiempo_esperando += delta
	if _tiempo_esperando > 60.0:
		print("[BOT-MOVIMIENTO] ABANDONA: se pasó el tiempo.")
		quit(1)
		return true

	if _jugador == null or not is_instance_valid(_jugador):
		var jugadores := _mundo.get_node_or_null("Jugadores")
		if jugadores != null:
			_jugador = jugadores.get_node_or_null(str(root.get_multiplayer().get_unique_id()))
		return false

	# Esperar a que el nivel quede fijo (la partida guardada puede mudarlo) y a
	# que pase el bloqueo de llegada (Jugador.TIEMPO_BLOQUEO_TRANSICION).
	var nivel = root.get_node("/root/GestorNiveles").nivel_actual()
	if nivel != _nivel_estable:
		_nivel_estable = nivel
		_segundos_nivel_estable = 0.0
		if nivel != null:
			print("[BOT-MOVIMIENTO] en '%s'" % nivel.name)
	_segundos_nivel_estable += delta
	if _tanda == 0 and _segundos_nivel_estable < 4.0:
		return false
	if _atender_muerte(delta):
		return false

	return _correr_tandas(delta)


## Un mob de la Pradera puede matar al bot a mitad de una tanda: muerto no se
## mueve, y al reaparecer salta al punto de aparición. Medido como movimiento,
## eso son dos fallas falsas ("casi no lo movió" y "siguió moviéndose"). Se
## anuncia y la tanda en curso se repite entera al reaparecer.
const _MAX_MUERTES := 3
const _SEGUNDOS_TRAS_REAPARECER := 0.5
var _muertes := 0
var _esperando_reaparecer := false
var _t_tras_reaparecer := 0.0

func _atender_muerte(delta: float) -> bool:
	if _jugador.get("_muerto"):
		if not _esperando_reaparecer:
			_esperando_reaparecer = true
			_muertes += 1
			JoystickBot.mover(root, Vector2.ZERO)
			_jugador.set_physics_process(true)
			print("[BOT-MOVIMIENTO] el jugador murió en la tanda %d; se repite al reaparecer." % _tanda)
			if _muertes > _MAX_MUERTES:
				print("[BOT-MOVIMIENTO] ABANDONA: murió %d veces." % _muertes)
				quit(1)
		return true
	if not _esperando_reaparecer:
		return false
	_t_tras_reaparecer += delta
	if _t_tras_reaparecer < _SEGUNDOS_TRAS_REAPARECER:
		return true
	_esperando_reaparecer = false
	_t_tras_reaparecer = 0.0
	_t = 0.0
	_pos_al_soltar = Vector2.ZERO
	_pos_frenado = Vector2.ZERO
	_t_corte = 0.0
	_pos_al_cortar = Vector2.ZERO
	_pos_tras_corte = Vector2.ZERO
	return false


func _correr_tandas(delta: float) -> bool:
	if _tanda >= _DIRECCIONES.size():
		return _probar_corte_de_input(delta)
	# Toques reales sobre el joystick del HUD (ver joystick_bot.gd): así se
	# prueba el camino completo, rectificador incluido.
	var direccion: Vector2 = _DIRECCIONES[_tanda]
	var zigzag := direccion == Vector2.ZERO
	if _t == 0.0:
		_pos_inicio = _jugador._posicion_replicada
		JoystickBot.mover(root, Vector2.RIGHT if zigzag else direccion)
	_t += delta
	if _t < _SEGUNDOS_EMPUJE:
		if zigzag:
			JoystickBot.mover(root, Vector2.from_angle(randf_range(0.0, TAU)))
		return false
	if _pos_al_soltar == Vector2.ZERO:
		JoystickBot.mover(root, Vector2.ZERO)
		_pos_al_soltar = _jugador._posicion_replicada
		return false
	if _t < _SEGUNDOS_EMPUJE + _SEGUNDOS_PARA_FRENAR:
		return false
	if _pos_frenado == Vector2.ZERO:
		_pos_frenado = _jugador._posicion_replicada
		return false
	if _t < _SEGUNDOS_EMPUJE + _SEGUNDOS_PARA_FRENAR + _SEGUNDOS_OBSERVANDO_QUIETO:
		return false

	var recorrido: float = _pos_inicio.distance_to(_pos_al_soltar)
	var deriva: float = _pos_frenado.distance_to(_jugador._posicion_replicada)
	var nombre := "zigzag" if zigzag else str(_DIRECCIONES[_tanda])
	print("[BOT-MOVIMIENTO] tanda %s: recorrió %.0f px empujando, derivó %.1f px ya soltado" % [
		nombre, recorrido, deriva])
	# El zigzag puede terminar cerca de donde empezó: solo se le exige frenar.
	if not zigzag and recorrido < 100.0:
		_fallas.append("%s: el servidor casi no lo movió (%.0f px)" % [nombre, recorrido])
	if deriva > 2.0:
		_fallas.append("%s: siguió moviéndose %.1f px después de soltar" % [nombre, deriva])
	_tanda += 1
	_t = 0.0
	_pos_al_soltar = Vector2.ZERO
	_pos_frenado = Vector2.ZERO
	return false


## Joystick apretado pero el cliente deja de mandar input (como la app en
## segundo plano): el servidor tiene que frenarlo solo en ~medio segundo en
## vez de dejarlo caminando para siempre.
var _t_corte := 0.0
var _pos_al_cortar := Vector2.ZERO
var _pos_tras_corte := Vector2.ZERO

func _probar_corte_de_input(delta: float) -> bool:
	if _t_corte == 0.0:
		JoystickBot.mover(root, Vector2.RIGHT)
	_t_corte += delta
	if _t_corte < 0.3:
		return false
	if _pos_al_cortar == Vector2.ZERO:
		_jugador.set_physics_process(false)
		_pos_al_cortar = _jugador._posicion_replicada
		return false
	if _t_corte < 1.3:
		return false
	if _pos_tras_corte == Vector2.ZERO:
		_pos_tras_corte = _jugador._posicion_replicada
		return false
	if _t_corte < 2.3:
		return false
	var deriva: float = _pos_tras_corte.distance_to(_jugador._posicion_replicada)
	print("[BOT-MOVIMIENTO] corte de input: avanzó %.0f px tras cortar, derivó %.1f px después" % [
		_pos_al_cortar.distance_to(_pos_tras_corte), deriva])
	if deriva > 2.0:
		_fallas.append("corte de input: el servidor lo dejó caminando (%.1f px)" % deriva)
	_jugador.set_physics_process(true)
	JoystickBot.mover(root, Vector2.ZERO)
	return _informar()


func _informar() -> bool:
	for falla in _fallas:
		print("[BOT-MOVIMIENTO] FALLA: %s" % falla)
	print("[BOT-MOVIMIENTO] %s" % ("OK" if _fallas.is_empty() else "FALLIDA"))
	quit(0 if _fallas.is_empty() else 1)
	return true
