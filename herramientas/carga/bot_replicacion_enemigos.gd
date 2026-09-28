# =============================================================================
# bot_replicacion_enemigos.gd — verificación en vivo de ReplicadorEnemigos
# contra un servidor dedicado REAL (dos procesos, conexión ENet de verdad).
#
# Se conecta, persigue y ataca al mob más cercano, y cuenta cuántas altas y
# bajas ve llegar al contenedor "Enemigos". Si las altas/bajas incrementales
# andan bien, la reconciliación periódica (cada 2s) no tiene nada que
# corregir después de la primera — cualquier corrección es un mob que se
# desincronizó por el camino normal.
#
# NUNCA usa la configuración guardada en la máquina (podría apuntar al
# servidor de producción): siempre --ip y --puerto explícitos.
#   godot --headless --path . --script res://herramientas/carga/bot_replicacion_enemigos.gd -- --puerto=8920 --duracion=40
# =============================================================================
extends SceneTree

const JoystickBot := preload("res://herramientas/carga/joystick_bot.gd")

var _puerto := 8920
var _duracion := 40.0
var _mundo: Node2D
var _jugador: CharacterBody2D
var _nivel: Node
var _contenedor: Node
var _replicador
var _altas := 0
var _bajas := 0
var _tiempo_esperando := 0.0
var _proxima_decision := 0.0
## Cruzar un portal libera el nivel (y su replicador) del cliente: se van
## acumulando los contadores de cada nivel visitado.
var _niveles_visitados: Array[String] = []
var _reconciliaciones_previas := 0
var _correcciones_previas := 0
var _ultimo_snapshot := [0, 0]
## Alta y baja deterministas sin depender de ganar peleas: el aliado de
## Invocación aparece y se desvanece solo a los 15s.
var _tiempo_en_nivel := 0.0
var _invocacion_equipada := false
var _proxima_invocacion := 4.0
var _aliados_vistos := 0
var _aliados_despachados := 0
## Invocar a los 4s + 15s de vida del aliado + margen para que llegue la baja.
const _SEGUNDOS_CICLO_ALIADO := 24.0


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--puerto="):
			_puerto = int(arg.substr(9))
		elif arg.begins_with("--duracion="):
			_duracion = float(arg.substr(11))


func _process(delta: float) -> bool:
	if _mundo == null:
		var utils = root.get_node("/root/Utils")
		utils.ip_conexion = "127.0.0.1"
		utils.puerto_conexion = _puerto
		utils.modo_local_pruebas = false
		utils.nombre_conexion = "BotReplicador%d" % (Time.get_unix_time_from_system() as int % 100000)
		# Identidad nueva en memoria: sin esto usa la guardada en esta PC (la
		# misma que el cliente real) y reaparece donde quedó la vez anterior.
		utils._id_jugador_local_cache = utils._generar_uuid()
		_mundo = (load("res://escenas/mundo/Mundo.tscn") as PackedScene).instantiate()
		root.add_child(_mundo)
		current_scene = _mundo
		return false

	if _jugador == null or not is_instance_valid(_jugador):
		_tiempo_esperando += delta
		if _tiempo_esperando > 30.0:
			print("[BOT-REPLICADOR] ABANDONA: nunca spawneó.")
			quit(1)
			return true
		var jugadores := _mundo.get_node_or_null("Jugadores")
		if jugadores != null:
			_jugador = jugadores.get_node_or_null(str(root.get_multiplayer().get_unique_id()))
		return false

	_seguir_nivel_actual()
	_simular_accion(delta)
	_invocar_periodicamente(delta)
	_duracion -= delta
	if _duracion > 0.0:
		return false
	return _informar()


func _seguir_nivel_actual() -> void:
	if is_instance_valid(_replicador):
		_ultimo_snapshot = [_replicador.reconciliaciones_recibidas, _replicador.correcciones_tras_la_primera]
	var nivel = root.get_node("/root/GestorNiveles").nivel_actual()
	if nivel == null or nivel == _nivel:
		return
	_reconciliaciones_previas += _ultimo_snapshot[0]
	_correcciones_previas += _ultimo_snapshot[1]
	_ultimo_snapshot = [0, 0]
	_nivel = nivel
	_contenedor = nivel.get_node_or_null("Enemigos")
	_replicador = nivel.get_node_or_null("ReplicadorEnemigos")
	if _contenedor == null or _replicador == null:
		print("[BOT-REPLICADOR] ABANDONA: el nivel '%s' no tiene Enemigos/ReplicadorEnemigos." % nivel.name)
		quit(1)
		return
	_contenedor.child_entered_tree.connect(_al_entrar)
	# Solo cuenta a los que se van YA muertos (despachados por el replicador):
	# al cambiar de nivel se liberan todos vivos y eso no es una baja.
	_contenedor.child_exiting_tree.connect(_al_salir)
	_tiempo_en_nivel = 0.0
	_proxima_invocacion = 4.0
	# El aliado del nivel anterior se liberó vivo con el nivel (no cuenta como
	# baja): dar tiempo a que el nuevo aparezca y se desvanezca acá.
	if not _niveles_visitados.is_empty():
		_duracion = maxf(_duracion, _SEGUNDOS_CICLO_ALIADO)
	_niveles_visitados.append(String(nivel.name))
	print("[BOT-REPLICADOR] en '%s' con %d hijos en Enemigos." % [nivel.name, _contenedor.get_child_count()])


func _al_entrar(nodo: Node) -> void:
	if nodo.has_method("esta_muerto"):
		_altas += 1
		if nodo.get_class() == "CharacterBody2D" and String(nodo.name).begins_with("AliadoInvocado"):
			_aliados_vistos += 1
			print("[BOT-REPLICADOR] alta: %s" % nodo.name)


func _al_salir(nodo: Node) -> void:
	if nodo.has_method("esta_muerto") and nodo.esta_muerto():
		_bajas += 1
		print("[BOT-REPLICADOR] baja: %s" % nodo.name)
		if String(nodo.name).begins_with("AliadoInvocado"):
			_aliados_despachados += 1


func _invocar_periodicamente(delta: float) -> void:
	_tiempo_en_nivel += delta
	var slots = root.get_node("/root/Utils").slot_habilidades_local()
	if slots == null:
		return
	if not _invocacion_equipada and _tiempo_en_nivel > 2.0:
		slots.equipar(0, load("res://recursos/habilidades/invocacion.tres"))
		_invocacion_equipada = true
	if not _invocacion_equipada or _tiempo_en_nivel < _proxima_invocacion:
		return
	_proxima_invocacion = _tiempo_en_nivel + 20.0
	var hab = slots.obtener(0)
	if hab != null:
		hab.activar(Vector2.ZERO, 1.0)


## Persigue y golpea al mob vivo más cercano: así hay muertes (bajas) y el
## spawner repone (altas) — caminar al azar terminaba metiéndose en un portal
## sin pelear nunca.
func _simular_accion(delta: float) -> void:
	_proxima_decision -= delta
	if _proxima_decision > 0.0:
		return
	_proxima_decision = 0.3
	var objetivo: Node2D = null
	var mejor := INF
	for hijo in _contenedor.get_children():
		if hijo.has_method("esta_muerto") and not hijo.esta_muerto() \
				and not String(hijo.name).begins_with("AliadoInvocado"):
			var d: float = _jugador.global_position.distance_to(hijo.global_position)
			if d < mejor:
				mejor = d
				objetivo = hijo
	# Toques reales sobre el joystick del HUD, ver joystick_bot.gd.
	if objetivo == null or mejor <= 45.0:
		JoystickBot.mover(root, Vector2.ZERO)
	else:
		JoystickBot.mover(root, _jugador.global_position.direction_to(objetivo.global_position))
	if objetivo != null and mejor < 120.0:
		root.get_node("/root/SeñalManager").emitir("slot_0_activar", "", [])


func _informar() -> bool:
	_seguir_nivel_actual()
	var enemigos := 0
	var en_origen := 0
	for hijo in _contenedor.get_children():
		if hijo.has_method("esta_muerto") and not hijo.esta_muerto():
			enemigos += 1
			if (hijo as Node2D).position == Vector2.ZERO:
				en_origen += 1
	var reconciliaciones: int = _reconciliaciones_previas + _ultimo_snapshot[0]
	var correcciones: int = _correcciones_previas + _ultimo_snapshot[1]
	print("[BOT-REPLICADOR] niveles=%s reconciliaciones=%d correcciones_tras_la_primera=%d enemigos_vivos=%d en_origen=%d altas=%d bajas=%d aliados_vistos=%d aliados_despachados=%d" % [
		str(_niveles_visitados), reconciliaciones, correcciones, enemigos, en_origen, _altas, _bajas,
		_aliados_vistos, _aliados_despachados])
	var exito: bool = reconciliaciones >= 3 and correcciones == 0 and enemigos > 0 and en_origen == 0 \
		and _aliados_vistos >= 1 and _aliados_despachados >= 1
	print("[BOT-REPLICADOR] %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
