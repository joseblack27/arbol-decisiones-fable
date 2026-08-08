# =============================================================================
# bot_viaje_cueva.gd — reproduce contra el SERVIDOR REAL el viaje Pradera →
# Cueva → Pradera, que es lo que el usuario reportó roto ("al salir de la
# cueva se buguea, se pierde la conexión con el servidor y no me puedo
# mover").
#
# Igual que bot_carga.gd, reutiliza Mundo.tscn TAL CUAL: mismo camino de
# conexión, spawn, réplica y joystick que un cliente real — un simulador
# aparte podría no reproducir el bug.
#
# Va informando el estado de la conexión, el nivel que tiene cargado ESTE
# cliente y la posición del jugador, para poder cruzar el relato del cliente
# con el log del servidor (que es donde faltaba la mitad de la película).
#
#   godot --headless --path . --script res://herramientas/carga/bot_viaje_cueva.gd -- --ip=127.0.0.1
# =============================================================================
extends SceneTree

var _ip := "127.0.0.1"
var _solo_ida := false
## Se queda en la cueva en vez de volver — para que OTRO bot compruebe que a
## él no se lo llevaron puesto.
var _quedarse := false
## No se mueve nunca: sólo informa en qué nivel está. Es la "víctima" que
## antes era arrastrada a la cueva por el primero que cruzaba un portal.
var _quieto := false
## Viaja al Camino en vez de a la Cueva.
var _al_camino := false
var _duracion := 60.0
var _mundo: Node2D
var _jugador: CharacterBody2D
var _fase := "conectando"
var _tiempo := 0.0
var _tiempo_fase := 0.0
var _ultimo_informe := 0.0
var _nivel_anterior := ""
var _estado_anterior := -1

const _TOPE_FASE := 45.0


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ip="):
			_ip = arg.substr(5)
		elif arg == "--solo_ida":
			_solo_ida = true
		elif arg == "--quedarse":
			_quedarse = true
		elif arg == "--quieto":
			_quieto = true
		elif arg == "--camino":
			_al_camino = true
		elif arg.begins_with("--duracion="):
			_duracion = float(arg.substr(11))


func _process(delta: float) -> bool:
	_tiempo += delta
	_tiempo_fase += delta

	if _fase == "conectando" and _mundo == null:
		var utils = root.get_node("/root/Utils")
		utils.ip_conexion = _ip
		utils.puerto_conexion = 8920
		utils.modo_local_pruebas = false
		# Nombre único por corrida: si se reusa la cuenta, el servidor le
		# restaura la posición guardada de la sesión anterior y el viaje
		# arranca desde donde quedó, no desde el punto de aparición — ruido
		# que no tiene nada que ver con lo que se está probando.
		utils.nombre_conexion = "BotCueva%d" % (Time.get_unix_time_from_system() as int % 100000)
		print("[BOT] conectando a %s:8920" % _ip)
		_mundo = (load("res://escenas/mundo/Mundo.tscn") as PackedScene).instantiate()
		root.add_child(_mundo)
		current_scene = _mundo
		return false

	_vigilar_conexion()
	_vigilar_nivel()

	if _jugador == null or not is_instance_valid(_jugador):
		_buscar_jugador_propio()
		if _tiempo_fase > _TOPE_FASE:
			print("[BOT] ABANDONA: nunca spawneó.")
			quit(1)
			return true
		return false

	match _fase:
		"conectando":
			if _quieto:
				_cambiar_fase("quieto")
			else:
				_cambiar_fase("yendo_a_la_cueva")
		"quieto", "quedandose":
			# No se mueve: sólo hay que ver en qué nivel lo tiene el servidor.
			if _tiempo - _ultimo_censo >= 2.0:
				_ultimo_censo = _tiempo
				_censar_mobs()
			if _tiempo_fase >= _duracion:
				print("[BOT] terminó en la fase '%s' con nivel '%s'" % [_fase, _nivel()])
				_informe("final")
				quit(0)
				return true
			return false
		"yendo_a_la_cueva":
			_mover(_hacia_portal("PortalACamino" if _al_camino else "PortalACueva",
				Vector2.LEFT if _al_camino else Vector2.RIGHT))
			if _nivel() == ("Camino" if _al_camino else "Cueva"):
				print("[BOT] ENTRÓ a %s en %s" % [_nivel(), _jugador.global_position])
				if _solo_ida:
					# Deja al SERVIDOR con la Cueva puesta y se va: sirve para
					# comprobar que el que se conecte después cargue la Cueva y
					# no el nivel inicial a ciegas.
					print("[BOT] --solo_ida: corta acá, dejando el servidor en la Cueva")
					quit(0)
					return true
				if _quedarse:
					_mover(Vector2.ZERO)
					_cambiar_fase("quedandose")
					return false
				_cambiar_fase("volviendo")
		"volviendo":
			# Un respiro antes de arrancar: la ventana de gracia del gestor
			# (1s) descarta cualquier portal que se pise recién llegando.
			if _tiempo_fase < 2.0:
				return false
			_mover(_hacia_portal("PortalAPradera", Vector2.LEFT))
			if _nivel() == "Pradera":
				print("[BOT] VOLVIÓ a la Pradera en %s — VIAJE COMPLETO OK" % _jugador.global_position)
				_informe("final")
				quit(0)
				return true

	if _tiempo_fase > _TOPE_FASE:
		print("[BOT] ABANDONA en la fase '%s' tras %.0fs." % [_fase, _TOPE_FASE])
		_informe("abandono")
		quit(1)
		return true

	if _tiempo - _ultimo_informe >= 3.0:
		_ultimo_informe = _tiempo
		_informe("periodico")
	return false


func _cambiar_fase(nueva: String) -> void:
	_fase = nueva
	_tiempo_fase = 0.0
	print("[BOT] --> fase '%s'" % nueva)


func _mover(dir: Vector2) -> void:
	root.get_node("/root/SeñalManager").emitir("joystick_movimiento", "", [dir])


## Apunta al portal en vez de caminar derecho: un empujón de mob te desvía
## unos píxeles en Y y el portal sólo cubre 30 px de radio — caminando a
## ciegas te quedás apoyado contra el borde del mapa, al lado del portal pero
## sin tocarlo nunca.
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


## ¿Los mobs de este nivel se mueven en la pantalla del cliente? Reportado:
## "los mobs de la cueva se quedaron quietos". Imprime nombre + posición para
## poder comparar entre censos consecutivos.
var _ultimo_censo := 0.0

func _censar_mobs() -> void:
	var nivel = root.get_node("/root/GestorNiveles").nivel_actual()
	if nivel == null:
		return
	var contenedor = nivel.get_node_or_null("Enemigos")
	if contenedor == null:
		return
	var partes: Array[String] = []
	for mob in contenedor.get_children():
		if mob is Node2D:
			partes.append("%s=%s" % [mob.name, (mob as Node2D).global_position.round()])
	print("[MOBS t=%.0f] %s" % [_tiempo, ", ".join(partes)])


func _nivel() -> String:
	var nivel = root.get_node("/root/GestorNiveles").nivel_actual()
	return nivel.nombre_nivel if nivel != null else "<ninguno>"


## El síntoma central que hay que capturar: si el peer se cae, DÓNDE se cae.
func _vigilar_conexion() -> void:
	var par = root.get_multiplayer().multiplayer_peer
	var estado: int = par.get_connection_status() if par != null else -1
	if estado != _estado_anterior:
		var nombres := {0: "DESCONECTADO", 1: "CONECTANDO", 2: "CONECTADO"}
		print("[BOT] conexión: %s (fase '%s', t=%.1fs)" % [
			nombres.get(estado, "peer nulo (%d)" % estado), _fase, _tiempo])
		_estado_anterior = estado


func _vigilar_nivel() -> void:
	var actual := _nivel()
	if actual != _nivel_anterior:
		print("[BOT] nivel del CLIENTE: '%s' -> '%s' (t=%.1fs)" % [_nivel_anterior, actual, _tiempo])
		_nivel_anterior = actual


## pos = lo que ve ESTE cliente; pos_servidor = _posicion_replicada, o sea la
## posición AUTORITATIVA que el servidor viene anunciando. Si las dos se
## separan, el servidor y el cliente están jugando en mapas distintos — que es
## justo lo que hay que averiguar.
func _informe(motivo: String) -> void:
	var pos := _jugador.global_position if is_instance_valid(_jugador) else Vector2.ZERO
	var pos_srv: Vector2 = _jugador.get("_posicion_replicada") if is_instance_valid(_jugador) else Vector2.ZERO
	print("[BOT][%s] t=%.1fs fase='%s' nivel_cliente='%s' pos=%s pos_servidor=%s" % [
		motivo, _tiempo, _fase, _nivel(), pos, pos_srv])


func _buscar_jugador_propio() -> void:
	var utils = root.get_node("/root/Utils")
	if not utils.en_red():
		return
	if not is_instance_valid(_mundo):
		if is_instance_valid(current_scene) and current_scene.name == "Mundo":
			_mundo = current_scene
		return
	var jugadores := _mundo.get_node_or_null("Jugadores")
	if jugadores == null:
		return
	var id_propio := root.get_multiplayer().get_unique_id()
	for hijo in jugadores.get_children():
		if hijo is CharacterBody2D and hijo.name == str(id_propio):
			_jugador = hijo
			print("[BOT] spawneado como peer %s en %s" % [hijo.name, hijo.global_position])
			return
