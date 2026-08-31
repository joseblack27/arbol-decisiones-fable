extends Node
## Chat global — Feature B del plan de escalado a MMO ("¿el chat debería ser
## global o por proximidad?" → decisión del usuario: global. Un solo canal
## "Mundo": todos los peers conectados lo ven, sin filtrar por distancia —
## el tráfico de texto es bajo comparado con posición/estado de mobs, no
## amerita el filtro que sí usa InteresEspacial para eso).
##
## Mismo patrón cliente-pide/servidor-valida-y-difunde que
## MisionesComponente/TiendaComponente, con una diferencia: este autoload NO
## cuelga de un Jugador puntual (no hay "dueño" fijo que comparar), así que
## la identidad del remitente se resuelve en el servidor directo desde
## multiplayer.get_remote_sender_id() — la conexión real, no falsificable
## por el cliente — en vez de un peer_id_dueño guardado en un componente.
## El NOMBRE tampoco viaja como parámetro del pedido: el servidor lo lee del
## propio nodo Jugador (nombre_visible), así nadie puede mandar un mensaje
## con el nombre de otro.
##
## Autoload de script plano (no de escena): es puro estado de runtime
## (historial, cooldowns), sin ningún catálogo de recursos para armar a
## mano en el Inspector — mismo criterio que GestorCuentas/InteresEspacial.

signal mensaje_recibido(nombre: String, texto: String, es_sistema: bool)

const LARGO_MAXIMO_MENSAJE := 200
## Frena flood accidental (no un anti-cheat elaborado): un jugador real no
## necesita mandar más rápido que esto.
const COOLDOWN_ENVIO_SEGUNDOS := 0.5
const HISTORIAL_MAXIMO := 100
const NOMBRE_SISTEMA := "Sistema"

var historial: Array[Dictionary] = []

var _ultimo_envio_por_id: Dictionary = {}


## Llamado desde PanelChat con lo que escribió el jugador LOCAL.
func enviar_mensaje(texto: String) -> void:
	if Utils.en_red() and not multiplayer.is_server():
		rpc_id(1, "_pedir_enviar_mensaje_red", texto)
		return
	# Servidor consigo mismo u offline (pruebas sin red): no hay peer real
	# que resolver, el remitente es directamente el jugador local.
	_validar_y_difundir(Utils.nombre_jugador_local(), texto)


@rpc("any_peer", "reliable")
func _pedir_enviar_mensaje_red(texto: String) -> void:
	if not multiplayer.is_server():
		return
	var remitente_id := multiplayer.get_remote_sender_id()
	var jugador := InteresEspacial.jugador_de_peer(remitente_id)
	if jugador == null:
		return
	var clave: String = jugador.id_unico if jugador.id_unico != "" else str(remitente_id)
	var ahora := Time.get_ticks_msec() / 1000.0
	if ahora - float(_ultimo_envio_por_id.get(clave, -INF)) < COOLDOWN_ENVIO_SEGUNDOS:
		return
	_ultimo_envio_por_id[clave] = ahora
	_validar_y_difundir(jugador.nombre_visible, texto)


## SERVIDOR (u offline): recorta/valida el texto y lo manda a todos los
## peers listos (InteresEspacial.peers_conectados_listos — mismo criterio
## defensivo contra "Unable to send packet" que ya usan los mobs). También
## sirve para mensajes de sistema dirigidos a todos (es_sistema=true).
func _validar_y_difundir(nombre: String, texto: String, es_sistema: bool = false) -> void:
	var limpio := texto.strip_edges().substr(0, LARGO_MAXIMO_MENSAJE)
	if limpio == "":
		return
	if Utils.en_red() and multiplayer.is_server():
		for peer_id in InteresEspacial.peers_conectados_listos():
			rpc_id(peer_id, "_recibir_mensaje_red", nombre, limpio, es_sistema)
	_aplicar_local(nombre, limpio, es_sistema)


@rpc("authority", "reliable")
func _recibir_mensaje_red(nombre: String, texto: String, es_sistema: bool) -> void:
	_aplicar_local(nombre, texto, es_sistema)


func _aplicar_local(nombre: String, texto: String, es_sistema: bool) -> void:
	historial.append({"nombre": nombre, "texto": texto, "es_sistema": es_sistema})
	if historial.size() > HISTORIAL_MAXIMO:
		historial.pop_front()
	mensaje_recibido.emit(nombre, texto, es_sistema)


## SERVIDOR: mensaje de sistema dirigido a UN jugador puntual (ej. "tu
## invitación de grupo fue rechazada" — ver GestorGrupos). Reusa el mismo
## canal en vez de inventar otro tipo de notificación aparte.
func enviar_mensaje_sistema_a(peer_id: int, texto: String) -> void:
	if not (Utils.en_red() and multiplayer.is_server()):
		return
	var limpio := texto.strip_edges().substr(0, LARGO_MAXIMO_MENSAJE)
	if limpio == "":
		return
	rpc_id(peer_id, "_recibir_mensaje_red", NOMBRE_SISTEMA, limpio, true)
