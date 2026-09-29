extends Node
## Identidad del jugador en red: quién es (id_unico, la clave de su partida;
## ver GestorGuardado), cómo se llama en pantalla (nombre_visible), la cuenta
## con PIN (GestorCuentas) y la expulsión de su propia conexión vieja
## ("fantasma"). Lo crea Jugador.gd como hijo.
##
## Los dos RPC (_registrar_identidad_red y _rechazar_cuenta_red) siguen en
## Jugador.gd y delegan acá: así su ruta de red no cambia.


@onready var _jugador: CharacterBody2D = get_parent()


## CLIENTE dueño: le manda al servidor su identidad y su nombre. Ninguno de
## los dos lo puede saber el servidor solo: ambos viven en el cliente.
func enviar_al_servidor() -> void:
	_jugador.nombre_visible = Utils.nombre_jugador_local()
	_jugador.rpc_id(1, "_registrar_identidad_red", Utils.id_jugador_local(),
		_jugador.nombre_visible, Utils.pin_conexion)


## SERVIDOR (ya validado que lo pidió el dueño): anota id_unico y
## nombre_visible. id_unico se queda en el servidor; nombre_visible se replica
## por el Sync (ver Jugador._enter_tree).
func registrar(id: String, nombre: String, pin: String) -> void:
	var id_limpio := id.strip_edges()
	var nombre_limpio := nombre.strip_edges().substr(0, 24)
	if nombre_limpio != "":
		_jugador.nombre_visible = nombre_limpio
	# Con PIN, la identidad real la resuelve la CUENTA (nombre+PIN), no el
	# dispositivo: así el progreso sigue al nombre aunque cambie de celular
	# (ver GestorCuentas.resolver_cuenta). Sin PIN, comportamiento clásico:
	# el id del dispositivo tal cual.
	if pin.strip_edges() != "" and nombre_limpio != "":
		var id_cuenta: String = GestorCuentas.resolver_cuenta(nombre_limpio, pin.strip_edges(), id_limpio)
		if id_cuenta == "":
			_rechazar_por_pin(nombre_limpio)
			return
		_confirmar(id_cuenta)
		return
	if id_limpio != "":
		_confirmar(id_limpio)


func _confirmar(id_unico: String) -> void:
	_jugador.id_unico = id_unico
	_expulsar_fantasma_de_la_misma_identidad()
	GestorGrupos.registrar_conectado(_jugador.peer_id_dueño, _jugador.nombre_visible, id_unico)


## PIN incorrecto: avisar al dueño y desconectarlo. Jugar con la identidad
## "equivocada" (la del dispositivo) sería peor: creería estar en su cuenta y
## estaría escribiendo otra partida.
func _rechazar_por_pin(nombre: String) -> void:
	var peer_id: int = _jugador.peer_id_dueño
	_jugador.rpc_id(peer_id, "_rechazar_cuenta_red", "PIN incorrecto para '%s'." % nombre)
	var peer := multiplayer.multiplayer_peer
	if peer is ENetMultiplayerPeer:
		# Timer real, no call_deferred(): eso solo pospone al mismo fotograma y
		# ENet no llega a transmitir el RPC reliable antes del corte (el cliente no
		# recibía el aviso y reintentaba con el mismo PIN malo para siempre).
		get_tree().create_timer(0.3).timeout.connect(
			(peer as ENetMultiplayerPeer).disconnect_peer.bind(peer_id, false)
		)


## CLIENTE dueño: el servidor rechazó la cuenta. Solo anota el motivo: el
## disconnect_peer() que llega justo después dispara server_disconnected, y
## Mundo._al_perder_conexion() decide qué mostrar. Si esto también cambiara de
## escena, correría una carrera contra ese evento y normalmente la perdería
## (reconectando con el mismo PIN malo para siempre).
func anotar_rechazo(motivo: String) -> void:
	GestorLogRed.registrar("Cuenta rechazada: %s" % motivo)
	Utils.error_conexion = motivo


## SERVIDOR: si ya existe otro Jugador con la MISMA identidad (mismo id_unico,
## otro peer_id_dueño), es una conexión vieja que ENet todavía no detectó como
## muerta (p. ej. el cliente reintentó conectarse solo tras reiniciarse el
## servidor). Los mobs seguirían atacando a ese fantasma mientras el jugador de
## verdad queda libre de aggro.
##
## Se lo desconecta apenas se confirma la identidad, antes de cargar la
## partida; ServidorDedicado._al_desconectar hace toda la limpieza.
func _expulsar_fantasma_de_la_misma_identidad() -> void:
	var fantasma := _buscar_fantasma_de_la_misma_identidad()
	if fantasma == null:
		return
	var peer := multiplayer.multiplayer_peer
	if peer is ENetMultiplayerPeer and fantasma.peer_id_dueño >= 0:
		# Timer real, ni corte sincrónico ni call_deferred(): esto corre dentro del
		# RPC de OTRO peer, y cortar ya deja a ENet a medio actualizar varios
		# fotogramas; cualquier paquete al fantasma en ese lapso revienta con "Unable
		# to send packet... max channels: 0".
		var id_a_expulsar: int = fantasma.peer_id_dueño
		get_tree().create_timer(0.3).timeout.connect(
			(peer as ENetMultiplayerPeer).disconnect_peer.bind(id_a_expulsar, false)
		)


## Separado de _expulsar_fantasma_de_la_misma_identidad() para poder probar la
## detección (encontrar al fantasma correcto, sin falsos positivos entre
## jugadores distintos ni falsos negativos consigo mismo) sin un
## ENetMultiplayerPeer real: ver pruebas/prueba_expulsar_fantasma_identidad.gd.
func _buscar_fantasma_de_la_misma_identidad() -> Node:
	for otro in get_tree().get_nodes_in_group("jugadores"):
		if otro == _jugador or not ("id_unico" in otro) or not ("peer_id_dueño" in otro):
			continue
		if otro.id_unico == _jugador.id_unico and otro.peer_id_dueño != _jugador.peer_id_dueño:
			return otro
	return null
