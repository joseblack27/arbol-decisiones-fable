extends Node
## Grupos/parties — Feature C del plan de escalado a MMO. Autoload de
## script plano: puro estado de runtime en memoria del SERVIDOR (los grupos
## son sesiones, no progreso persistente — no sobreviven un reinicio del
## servidor, mismo criterio que otras cosas de sesión como InteresEspacial).
## Indexado por id_unico (NUNCA peer_id, que cambia en cada reconexión) —
## la resolución a un peer_id/nodo Jugador vivo siempre se hace EN EL
## MOMENTO (ver jugador_de_id_unico), nunca se guarda en caché, así que un
## miembro que se reconecta con un peer_id nuevo sigue siendo encontrable
## sin ningún paso extra de "reenganche".
##
## Principio de diseño del proyecto (sin roles, ver memoria
## sin-roles-supervivencia-solo): nada acá crea dependencia funcional entre
## miembros. El líder solo administra el grupo en sí (expulsar) — no tiene
## ninguna ventaja de combate ni bloquea a los demás de nada.
##
## Flujo (decisión del usuario: panel dedicado, no comando de chat):
## PanelGrupo pide invitar a alguien del roster de conectados -> servidor
## crea una invitación pendiente con TTL -> el destino ve un popup
## (PanelInvitacionGrupo) -> acepta/rechaza -> el servidor arma/suma al
## grupo y difunde la vista actualizada a cada miembro (nombre + vida de
## todos, para BarraLateral/PanelGrupo). Rechazar avisa al invitante por el
## mismo canal de GestorChat (mensaje de sistema), sin inventar otro tipo
## de notificación aparte.

signal roster_actualizado
signal grupo_actualizado
signal invitacion_recibida(nombre_invitante: String)

const TAMANO_MAXIMO_GRUPO := 4
const TTL_INVITACION_SEGUNDOS := 30.0

## id_unico -> id_grupo (String)
var _grupo_de_miembro: Dictionary = {}
## id_grupo -> {"lider": id_unico, "miembros": Array[String]}
var _grupos: Dictionary = {}
var _proximo_id: int = 1

## id_unico_destino -> {"origen": id_unico, "nombre_origen": String, "vence": float}
var _invitaciones: Dictionary = {}

## SERVIDOR: peer_id -> {"nombre": String, "id_unico": String} — quién está
## conectado ahora mismo, para poblar el panel de "invitar".
var _conectados: Dictionary = {}

## CLIENTE: copia local de lo último que mandó el servidor — lo que leen
## PanelGrupo/PanelInvitacionGrupo/BarraLateral.
var roster: Array = []
var mi_grupo: Dictionary = {}   # {} si no estás en ningún grupo.


# =============================================================================
# ROSTER DE CONECTADOS
# =============================================================================

## SERVIDOR: llamado desde Jugador._registrar_identidad_red al confirmarse
## la identidad de un peer recién conectado (o reconectado con id nuevo).
func registrar_conectado(peer_id: int, nombre: String, id_unico: String) -> void:
	_conectados[peer_id] = {"nombre": nombre, "id_unico": id_unico}
	_difundir_roster()


## SERVIDOR: llamado desde ServidorDedicado._al_desconectar.
func quitar_conectado(peer_id: int) -> void:
	_conectados.erase(peer_id)
	_difundir_roster()


func _difundir_roster() -> void:
	if not (Utils.en_red() and multiplayer.is_server()):
		return
	var lista: Array = []
	for peer_id in _conectados:
		var entrada: Dictionary = _conectados[peer_id]
		lista.append({"peer_id": peer_id, "nombre": entrada.get("nombre", "")})
	for destino in InteresEspacial.peers_conectados_listos():
		rpc_id(destino, "_recibir_roster_red", lista)


@rpc("authority", "reliable")
func _recibir_roster_red(lista: Array) -> void:
	roster = lista
	roster_actualizado.emit()


# =============================================================================
# RESOLUCIÓN id_unico -> Jugador vivo (nunca cacheada, ver cabecera)
# =============================================================================

func jugador_de_id_unico(id_unico: String) -> Node2D:
	if id_unico == "":
		return null
	for jugador in get_tree().get_nodes_in_group("jugadores"):
		if ("id_unico" in jugador) and jugador.id_unico == id_unico:
			return jugador as Node2D
	return null


# =============================================================================
# MEMBRESÍA
# =============================================================================

func grupo_de(id_unico: String) -> Variant:
	var id_grupo: String = _grupo_de_miembro.get(id_unico, "")
	if id_grupo == "" or not _grupos.has(id_grupo):
		return null
	return _grupos[id_grupo]


func esta_en_grupo(id_unico: String) -> bool:
	return grupo_de(id_unico) != null


## Todos los id_unico del grupo de "id_unico" (vacío si no está en ninguno)
## — usado por Enemigo._repartir_xp_de_grupo.
func miembros_del_grupo_de(id_unico: String) -> Array:
	var grupo = grupo_de(id_unico)
	if grupo == null:
		return []
	return grupo["miembros"]


func _crear_grupo(lider: String) -> String:
	var id_grupo := "g%d" % _proximo_id
	_proximo_id += 1
	_grupos[id_grupo] = {"lider": lider, "miembros": [lider]}
	_grupo_de_miembro[lider] = id_grupo
	return id_grupo


func _agregar_miembro(id_grupo: String, id_unico: String) -> void:
	(_grupos[id_grupo]["miembros"] as Array).append(id_unico)
	_grupo_de_miembro[id_unico] = id_grupo


## SERVIDOR: saca a "id_unico" de su grupo actual; si queda vacío se
## disuelve; si el que sale era el líder y quedan más, el primero que sigue
## en la lista pasa a liderar (administración pura, no ventaja de combate).
func _quitar_de_su_grupo(id_unico: String) -> void:
	var id_grupo: String = _grupo_de_miembro.get(id_unico, "")
	if id_grupo == "" or not _grupos.has(id_grupo):
		return
	var grupo: Dictionary = _grupos[id_grupo]
	(grupo["miembros"] as Array).erase(id_unico)
	_grupo_de_miembro.erase(id_unico)
	if (grupo["miembros"] as Array).is_empty():
		_grupos.erase(id_grupo)
	elif grupo["lider"] == id_unico:
		grupo["lider"] = (grupo["miembros"] as Array)[0]


# =============================================================================
# INVITACIÓN — RPC dirigidos, mismo patrón _pedir_X_red que MisionesComponente
# =============================================================================

@rpc("any_peer", "reliable")
func _pedir_invitar_red(peer_id_destino: int) -> void:
	if not multiplayer.is_server():
		return
	var origen := InteresEspacial.jugador_de_peer(multiplayer.get_remote_sender_id())
	if origen == null or not ("id_unico" in origen) or origen.id_unico == "":
		return
	var id_origen: String = origen.id_unico
	var destino := InteresEspacial.jugador_de_peer(peer_id_destino)
	if destino == null or not ("id_unico" in destino) or destino.id_unico == "":
		return
	var id_destino: String = destino.id_unico
	if id_origen == id_destino or esta_en_grupo(id_destino):
		return
	var grupo_origen = grupo_de(id_origen)
	if grupo_origen != null and (grupo_origen["miembros"] as Array).size() >= TAMANO_MAXIMO_GRUPO:
		return
	_invitaciones[id_destino] = {
		"origen": id_origen,
		"vence": Time.get_ticks_msec() / 1000.0 + TTL_INVITACION_SEGUNDOS,
	}
	rpc_id(peer_id_destino, "_recibir_invitacion_red", origen.nombre_visible)


@rpc("authority", "reliable")
func _recibir_invitacion_red(nombre_invitante: String) -> void:
	invitacion_recibida.emit(nombre_invitante)


@rpc("any_peer", "reliable")
func _pedir_aceptar_invitacion_red() -> void:
	if not multiplayer.is_server():
		return
	var jugador := InteresEspacial.jugador_de_peer(multiplayer.get_remote_sender_id())
	if jugador == null or not ("id_unico" in jugador) or jugador.id_unico == "":
		return
	var id_unico: String = jugador.id_unico
	if not _invitaciones.has(id_unico):
		return
	var invitacion: Dictionary = _invitaciones[id_unico]
	_invitaciones.erase(id_unico)
	if Time.get_ticks_msec() / 1000.0 > float(invitacion["vence"]):
		return
	if esta_en_grupo(id_unico):
		return
	var id_origen: String = invitacion["origen"]
	var grupo_origen = grupo_de(id_origen)
	var id_grupo: String
	if grupo_origen == null:
		id_grupo = _crear_grupo(id_origen)
	else:
		id_grupo = _grupo_de_miembro[id_origen]
		if (_grupos[id_grupo]["miembros"] as Array).size() >= TAMANO_MAXIMO_GRUPO:
			return
	_agregar_miembro(id_grupo, id_unico)
	_difundir_grupo(id_grupo)


@rpc("any_peer", "reliable")
func _pedir_rechazar_invitacion_red() -> void:
	if not multiplayer.is_server():
		return
	var jugador := InteresEspacial.jugador_de_peer(multiplayer.get_remote_sender_id())
	if jugador == null or not ("id_unico" in jugador) or jugador.id_unico == "":
		return
	var id_unico: String = jugador.id_unico
	if not _invitaciones.has(id_unico):
		return
	var invitacion: Dictionary = _invitaciones[id_unico]
	_invitaciones.erase(id_unico)
	var origen := jugador_de_id_unico(invitacion["origen"])
	if origen != null and ("peer_id_dueño" in origen):
		GestorChat.enviar_mensaje_sistema_a(
			origen.peer_id_dueño, "%s rechazó tu invitación de grupo." % jugador.nombre_visible
		)


@rpc("any_peer", "reliable")
func _pedir_salir_del_grupo_red() -> void:
	if not multiplayer.is_server():
		return
	var jugador := InteresEspacial.jugador_de_peer(multiplayer.get_remote_sender_id())
	if jugador == null or not ("id_unico" in jugador):
		return
	_salir(jugador.id_unico)


## SERVIDOR: expulsar solo puede pedirlo el líder — la única restricción de
## "rol" que existe acá, y es administración del grupo, no una ventaja de
## combate (ver cabecera).
@rpc("any_peer", "reliable")
func _pedir_expulsar_red(id_unico_objetivo: String) -> void:
	if not multiplayer.is_server():
		return
	var jugador := InteresEspacial.jugador_de_peer(multiplayer.get_remote_sender_id())
	if jugador == null or not ("id_unico" in jugador):
		return
	var grupo = grupo_de(jugador.id_unico)
	if grupo == null or grupo["lider"] != jugador.id_unico or id_unico_objetivo == jugador.id_unico:
		return
	_salir(id_unico_objetivo)


func _salir(id_unico: String) -> void:
	var id_grupo: String = _grupo_de_miembro.get(id_unico, "")
	if id_grupo == "":
		return
	var miembros_previos: Array = (_grupos.get(id_grupo, {}).get("miembros", []) as Array).duplicate()
	_quitar_de_su_grupo(id_unico)
	# Avisar a quien salió/fue expulsado (ya no tiene grupo, vista vacía) y a
	# quienes quedan (vista sin ese miembro).
	_difundir_grupo_a_lista(id_unico, miembros_previos)
	if _grupos.has(id_grupo):
		_difundir_grupo(id_grupo)


func _difundir_grupo(id_grupo: String) -> void:
	if not _grupos.has(id_grupo):
		return
	_difundir_grupo_a_lista("", _grupos[id_grupo]["miembros"])


## Manda a cada id_unico en "destinatarios" (más "extra_id_unico" si no está
## ya incluido — típicamente alguien que ACABA de salir/ser expulsado) su
## vista actual del grupo, vacía ({}) para quien ya no tiene uno.
func _difundir_grupo_a_lista(extra_id_unico: String, destinatarios: Array) -> void:
	if not (Utils.en_red() and multiplayer.is_server()):
		return
	var lista: Array = destinatarios.duplicate()
	if extra_id_unico != "" and not lista.has(extra_id_unico):
		lista.append(extra_id_unico)
	for id_unico in lista:
		var jugador := jugador_de_id_unico(id_unico)
		if jugador == null or not ("peer_id_dueño" in jugador):
			continue
		rpc_id(jugador.peer_id_dueño, "_recibir_grupo_red", _vista_de_grupo_para(id_unico))


## La "vista" que recibe un cliente: su propio grupo con nombre + vida/vida
## máxima de cada miembro (para BarraLateral/PanelGrupo), o {} si no tiene.
##
## "soy_lider" se calcula ACÁ, del lado servidor, en vez de que cada cliente
## compare su propio id_unico contra "lider" — el cliente no siempre conoce
## su id_unico REAL: con cuenta por PIN, el servidor lo resuelve a través
## de GestorCuentas.resolver_cuenta a un valor que puede ser DISTINTO del
## id de dispositivo que el cliente mandó (Utils.id_jugador_local()), y ese
## id_unico nunca se replica de vuelta (ver el comentario en Jugador.gd:
## "no se muestra nunca en pantalla, solo viaja al servidor").
func _vista_de_grupo_para(id_unico: String) -> Dictionary:
	var grupo = grupo_de(id_unico)
	if grupo == null:
		return {}
	var miembros_info: Array = []
	for id_miembro in (grupo["miembros"] as Array):
		var jugador := jugador_de_id_unico(id_miembro)
		var info := {"id_unico": id_miembro, "nombre": "", "vida": 0.0, "vida_maxima": 1.0}
		if jugador != null:
			info["nombre"] = jugador.get("nombre_visible")
			var vida_comp = jugador.get_node_or_null("VidaComponente")
			if vida_comp:
				info["vida"] = vida_comp.obtener_vida()
				info["vida_maxima"] = vida_comp.obtener_vida_maxima()
		miembros_info.append(info)
	return {
		"id_grupo": _grupo_de_miembro[id_unico],
		"lider": grupo["lider"],
		"soy_lider": grupo["lider"] == id_unico,
		"miembros": miembros_info,
	}


@rpc("authority", "reliable")
func _recibir_grupo_red(vista: Dictionary) -> void:
	mi_grupo = vista
	grupo_actualizado.emit()


# =============================================================================
# API pública para UI (cliente) — llamadas desde PanelGrupo/PanelInvitacionGrupo
# =============================================================================

func invitar(peer_id_destino: int) -> void:
	if Utils.en_red() and not multiplayer.is_server():
		rpc_id(1, "_pedir_invitar_red", peer_id_destino)
	else:
		_pedir_invitar_red(peer_id_destino)


func aceptar_invitacion() -> void:
	if Utils.en_red() and not multiplayer.is_server():
		rpc_id(1, "_pedir_aceptar_invitacion_red")
	else:
		_pedir_aceptar_invitacion_red()


func rechazar_invitacion() -> void:
	if Utils.en_red() and not multiplayer.is_server():
		rpc_id(1, "_pedir_rechazar_invitacion_red")
	else:
		_pedir_rechazar_invitacion_red()


func salir_del_grupo() -> void:
	if Utils.en_red() and not multiplayer.is_server():
		rpc_id(1, "_pedir_salir_del_grupo_red")
	else:
		_pedir_salir_del_grupo_red()


func expulsar(id_unico_objetivo: String) -> void:
	if Utils.en_red() and not multiplayer.is_server():
		rpc_id(1, "_pedir_expulsar_red", id_unico_objetivo)
	else:
		_pedir_expulsar_red(id_unico_objetivo)


# =============================================================================
# XP compartida — llamado desde Enemigo._repartir_xp_de_grupo
# =============================================================================

## SERVIDOR: un miembro de grupo cambió de vida — empuja la vista
## actualizada SOLO a sus compañeros (nunca a todos los jugadores, ver
## cabecera del feature C: evita el ruido que motivó posponer "vida de
## todos los jugadores en pantalla"). Los parámetros de vida no se usan acá
## directo: _vista_de_grupo_para relee el VidaComponente real de cada
## miembro al armar el paquete, así nunca se desincroniza.
func notificar_cambio_vida(id_unico: String, _vida: float, _vida_maxima: float) -> void:
	if not (Utils.en_red() and multiplayer.is_server()):
		return
	var id_grupo: String = _grupo_de_miembro.get(id_unico, "")
	if id_grupo != "":
		_difundir_grupo(id_grupo)
