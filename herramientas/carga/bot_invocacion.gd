# =============================================================================
# bot_invocacion.gd — reproduce contra el SERVIDOR REAL los reportes sobre
# Invocación: primero "ya no sale la invocación" (spawn perdido por la
# carrera de conexión) y después "en el mapa de Camino no se mueve, ni
# ataca, ni desaparece" (nivel_actual() vs nivel_de_jugador() — ver
# HabilidadInvocacion._ejecutar()).
#
# Por defecto prueba en Pradera (donde spawnea el jugador). Con --camino
# camina hasta el portal y repite la prueba allá, vigilando además que el
# aliado SE MUEVA con el tiempo (no solo que exista) y que desaparezca solo
# al vencer su duración.
#
#   godot --headless --path . --script res://herramientas/carga/bot_invocacion.gd -- --ip=127.0.0.1 [--camino]
# =============================================================================
extends SceneTree

var _ip := "127.0.0.1"
var _al_camino := false
var _mundo: Node2D
var _jugador: CharacterBody2D
var _tiempo := 0.0
var _tiempo_con_jugador := 0.0
var _fase := "conectando"
var _tiempo_fase := 0.0
var _activada := false
var _posiciones_aliado: Array = []


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ip="):
			_ip = arg.substr(5)
		elif arg == "--camino":
			_al_camino = true


func _process(delta: float) -> bool:
	_tiempo += delta
	_tiempo_fase += delta

	if _mundo == null:
		var utils = root.get_node("/root/Utils")
		utils.ip_conexion = _ip
		utils.puerto_conexion = 8920
		utils.modo_local_pruebas = false
		utils.nombre_conexion = "BotInvoc%d" % (Time.get_unix_time_from_system() as int % 100000)
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
				print("[BOT] jugador propio encontrado: %s en nivel '%s'" % [propio.name, _nivel()])
				_cambiar_fase("yendo_a_camino" if _al_camino else "listo")
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
				_cambiar_fase("listo")
			elif _tiempo_fase > 30.0:
				print("[BOT] ABANDONA: nunca llegó a Camino (sigue en '%s')" % _nivel())
				quit(1)
				return true
			return false

		"listo":
			_tiempo_con_jugador += delta
			if _tiempo_con_jugador < 2.0:
				return false
			if not _activada:
				_activada = true
				var slots = root.get_node("/root/Utils").slot_habilidades_local()
				if slots == null:
					print("[BOT] ABANDONA: no se encontró SlotHabilidades local.")
					quit(1)
					return true
				var datos = load("res://recursos/habilidades/invocacion.tres")
				print("[BOT] equipando Invocación en el slot 0 (nivel actual: '%s')..." % _nivel())
				slots.equipar(0, datos)
				return false
			if _tiempo_con_jugador < 4.0:
				return false
			if not _tiempo_con_jugador > 4.1:
				var hab = slots_obtener_hab()
				if hab == null:
					print("[BOT] ABANDONA: el slot 0 no tiene una habilidad instanciada.")
					quit(1)
					return true
				print("[BOT] activando Invocación...")
				hab.activar(Vector2.ZERO, 1.0)
				_cambiar_fase("vigilando")
			return false

		"vigilando":
			# Censo de posición cada segundo: si nunca cambia, el aliado está
			# congelado (reportado en Camino).
			if int(_tiempo_fase) > _posiciones_aliado.size():
				var aliado := _buscar_aliado()
				if aliado != null:
					_posiciones_aliado.append((aliado as Node2D).global_position)
					print("[BOT t=%.0f] aliado en %s" % [_tiempo_fase, (aliado as Node2D).global_position])
					_censar_cercania(aliado)
					_reportar_vida_mob_mas_cercano(aliado)
				else:
					print("[BOT t=%.0f] aliado no encontrado (¿ya desapareció?)" % _tiempo_fase)
			if _tiempo_fase > 20.0:
				_informar_resultado()
				return true
			return false
	return false


func _informar_resultado() -> void:
	var aliado := _buscar_aliado()
	var se_movio := false
	if _posiciones_aliado.size() >= 2:
		var primera: Vector2 = _posiciones_aliado[0]
		for p in _posiciones_aliado:
			if (p as Vector2).distance_to(primera) > 5.0:
				se_movio = true
				break
	print("[BOT] nivel de la prueba: %s" % _nivel())
	print("[BOT] ¿se lo vio en algún momento? %s" % (not _posiciones_aliado.is_empty()))
	print("[BOT] ¿se movió? %s (posiciones: %s)" % [se_movio, str(_posiciones_aliado)])
	print("[BOT] ¿desapareció antes de t=20s (duracion_invocacion=15s)? %s" % (aliado == null))
	var ok := not _posiciones_aliado.is_empty() and se_movio and aliado == null
	print("[BOT] RESULTADO GENERAL: %s" % ("OK" if ok else "FALLA"))
	quit(0 if ok else 1)


## Diagnóstico: ¿hay mobs reales cerca como para que el aliado tenga algo
## que atacar? Si no hay ninguno dentro de rango_deteccion, "no se mueve" es
## el comportamiento ESPERADO (vuelve junto al dueño, ya está cerca), no un
## bug.
func _censar_cercania(aliado: Node2D) -> void:
	var nivel = root.get_node("/root/GestorNiveles").nivel_de_jugador(_jugador)
	if nivel == null:
		return
	var contenedor = nivel.get_node_or_null("Enemigos")
	if contenedor == null:
		return
	var partes: Array[String] = []
	for hijo in contenedor.get_children():
		if hijo == aliado or not (hijo is Node2D):
			continue
		var dist: float = (hijo as Node2D).global_position.distance_to(aliado.global_position)
		partes.append("%s(d=%.0f)" % [hijo.name, dist])
	print("[BOT t=%.0f] otros en Enemigos: %s" % [_tiempo_fase, ", ".join(partes)])


## ¿el aliado ATACA de verdad? Si hay un mob a d < rango_ataque(40) y su
## vida no baja con el tiempo, no está peleando aunque no se mueva un pixel.
func _reportar_vida_mob_mas_cercano(aliado: Node2D) -> void:
	var nivel = root.get_node("/root/GestorNiveles").nivel_de_jugador(_jugador)
	if nivel == null:
		return
	var contenedor = nivel.get_node_or_null("Enemigos")
	if contenedor == null:
		return
	var mejor: Node = null
	var mejor_dist := INF
	for hijo in contenedor.get_children():
		if hijo == aliado or not (hijo is Node2D) or not hijo.is_in_group("enemigos"):
			continue
		var d: float = (hijo as Node2D).global_position.distance_to(aliado.global_position)
		if d < mejor_dist:
			mejor_dist = d
			mejor = hijo
	if mejor == null:
		return
	var vida := mejor.get_node_or_null("VidaComponente")
	var salud_actual = vida.get("salud_actual") if vida else "?"
	print("[BOT t=%.0f] mob más cercano=%s d=%.0f salud_actual=%s" % [
		_tiempo_fase, mejor.name, mejor_dist, str(salud_actual)])


func _buscar_aliado() -> Node:
	var nivel = root.get_node("/root/GestorNiveles").nivel_de_jugador(_jugador)
	if nivel == null:
		return null
	var contenedor = nivel.get_node_or_null("Enemigos")
	if contenedor == null:
		return null
	for hijo in contenedor.get_children():
		if hijo.name.begins_with("AliadoInvocado"):
			return hijo
	return null


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


func slots_obtener_hab():
	var slots = root.get_node("/root/Utils").slot_habilidades_local()
	return slots.obtener(0) if slots else null
