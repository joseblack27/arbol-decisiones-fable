# =============================================================================
# bot_carga.gd — Fase 4 del plan de escalado a MMO: simula UN jugador real
# conectándose al servidor dedicado, moviéndose y atacando, para poder medir
# capacidad bajo carga antes de invertir en interés espacial/sharding.
#
# Reutiliza Mundo.tscn TAL CUAL (mismo camino de conexión, spawn y réplica
# que un cliente real de verdad usa — no un simulador aparte que podría
# generar tráfico distinto al real). Corre como proceso separado por bot
# (así cada uno es una conexión ENet físicamente distinta, igual que
# clientes reales en máquinas distintas) — ver herramientas/carga/
# prueba_carga.sh, que lanza N de estos con --id=N --duracion=S.
#
#   godot --headless --path . --script res://herramientas/carga/bot_carga.gd -- --id=3 --duracion=60
# =============================================================================
extends SceneTree

var _id: int = 0
var _duracion: float = 60.0
var _fotogramas: int = 0
var _mundo: Node2D
var _jugador: CharacterBody2D
var _proxima_decision: float = 0.0
var _direccion_actual := Vector2.ZERO
## Si a los 20s no logró spawnear (conexión perdida, servidor lleno, nivel
## que tarda en cargar...), se rinde y sale con código de error — en vez de
## reintentar para siempre. Encontrado en la corrida real: si Mundo.gd
## pierde la conexión reacciona con reload_current_scene(), que LIBERA la
## instancia vieja de Mundo — pero _mundo seguía apuntando a esa referencia
## muerta, y el bot quedaba reintentando sobre un nodo liberado por
## siempre (spam de "Cannot call method on a previously freed instance",
## el bash del arnés esperándolo colgado sin fin).
const _TIMEOUT_SPAWN := 20.0
var _tiempo_esperando_spawn: float = 0.0

## Modo de verificación puntual de InteresEspacial (Fase 1): en vez de
## simular una sesión normal, este bot se aleja 5000px apenas spawnea y se
## queda quieto — para que otro bot con --observa confirme que deja de
## recibir su posición real una vez fuera del radio de interés.
var _teleporta_lejos := false
var _ya_se_teleporto := false
## Modo observador: en vez de moverse, registra la posición X máxima que
## ve de CUALQUIER otro jugador replicado — así se puede confirmar desde
## afuera si el filtro de distancia realmente frena la réplica.
var _observa := false
var _x_maxima_vista_otro: float = -INF

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--id="):
			_id = int(arg.substr(5))
		elif arg.begins_with("--duracion="):
			_duracion = float(arg.substr(11))
		elif arg == "--teleporta_lejos":
			_teleporta_lejos = true
		elif arg == "--observa":
			_observa = true


func _process(delta: float) -> bool:
	_fotogramas += 1

	if _fotogramas == 1:
		_mundo = (load("res://escenas/mundo/Mundo.tscn") as PackedScene).instantiate()
		root.add_child(_mundo)
		current_scene = _mundo
		return false

	if _jugador == null or not is_instance_valid(_jugador):
		_tiempo_esperando_spawn += delta
		if _tiempo_esperando_spawn > _TIMEOUT_SPAWN:
			push_error("BOT %d: no logró spawnear en %.0fs — abandona." % [_id, _TIMEOUT_SPAWN])
			quit(1)
			return true
		# _mundo puede haberse liberado (Mundo.gd llama reload_current_scene()
		# al perder la conexión) — sin este chequeo, _buscar_jugador_propio()
		# reventaba cada frame llamando métodos sobre una instancia muerta,
		# para siempre. Repuntar a la instancia NUEVA (current_scene ya
		# apunta ahí) en vez de rendirse: un reintento real puede recuperarse.
		if not is_instance_valid(_mundo):
			if is_instance_valid(current_scene) and current_scene.name == "Mundo":
				_mundo = current_scene
			return false
		_buscar_jugador_propio()
		return false

	if _teleporta_lejos:
		if not _ya_se_teleporto:
			_ya_se_teleporto = true
			_jugador.global_position += Vector2(5000, 0)
			print("BOT %d: teletransportado a %s" % [_id, str(_jugador.global_position)])
	elif _observa:
		_registrar_posiciones_ajenas()
	else:
		_simular_accion(delta)

	# El cronómetro arranca recién cuando el jugador existe: así --duracion
	# mide tiempo de JUEGO real, no el rato variable que tarda conectar.
	_duracion -= delta
	if _duracion <= 0.0:
		if _observa:
			print("BOT %d: X maxima vista de otro jugador = %.0f" % [_id, _x_maxima_vista_otro])
		print("BOT %d: terminó su sesión (%d fotogramas)." % [_id, _fotogramas])
		quit(0)
		return true
	return false


func _registrar_posiciones_ajenas() -> void:
	var jugadores := _mundo.get_node_or_null("Jugadores")
	if jugadores == null:
		return
	for hijo in jugadores.get_children():
		if hijo is CharacterBody2D and hijo != _jugador:
			_x_maxima_vista_otro = maxf(_x_maxima_vista_otro, hijo.global_position.x)


func _buscar_jugador_propio() -> void:
	# En un .gd pasado por --script (este archivo ES el MainLoop, no un nodo
	# de escena) los autoloads no siempre resuelven como identificador
	# global suelto — mismo caso documentado en pruebas/ para BusEventos:
	# hay que pedirlos por ruta ("/root/X") en vez de usarlos "a pelo".
	var utils = root.get_node("/root/Utils")
	if not utils.en_red():
		return  # se cayó a modo local (no hay servidor) — nada que simular.
	var jugadores := _mundo.get_node_or_null("Jugadores")
	if jugadores == null:
		return
	# "multiplayer" es una propiedad de Node (proxy a get_multiplayer()) —
	# este script extiende SceneTree, no Node, así que hay que pedírselo a
	# "root" (el Window, que sí es Node) en vez de usarlo directo.
	var id_propio := root.get_multiplayer().get_unique_id()
	for hijo in jugadores.get_children():
		if hijo is CharacterBody2D and hijo.name == str(id_propio):
			_jugador = hijo
			_tiempo_esperando_spawn = 0.0
			print("BOT %d: spawneado (peer %s)." % [_id, hijo.name])
			return


## Cada ~1-2s cambia de dirección (mueve por el joystick, el mismo camino
## real que usa un jugador humano — SeñalManager es el bus que la UI real
## dispara) y, con cierta probabilidad, ataca — así el tráfico generado se
## parece al de una sesión real, no a un bot inmóvil.
func _simular_accion(delta: float) -> void:
	_proxima_decision -= delta
	if _proxima_decision > 0.0:
		return
	_proxima_decision = randf_range(1.0, 2.5)

	if randf() < 0.3:
		_direccion_actual = Vector2.ZERO  # pausa breve, más realista que moverse siempre
	else:
		_direccion_actual = Vector2.from_angle(randf_range(0.0, TAU))
	var señales = root.get_node("/root/SeñalManager")
	señales.emitir("joystick_movimiento", "", [_direccion_actual])

	if randf() < 0.4:
		señales.emitir("slot_0_activar", "", [])
