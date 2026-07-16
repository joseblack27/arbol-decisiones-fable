extends Node
class_name SlotHabilidades
## Manager de slots de habilidades equipadas.
## Los slots se equipan en runtime vía equipar()/equipar_escena() — no hay
## asignación fija en el Inspector (a diferencia de versiones viejas con
## slot_0..slot_3 @export): el catálogo + total_slots definen el universo
## posible, y GestorGuardado restaura lo que el jugador tenía equipado.
##
## total_slots reemplaza el límite fijo de 4 (ver PaginadorHabilidades para
## la paginación del lado de la UI — acá adentro no hay concepto de
## "página", solo un array plano de slots 0..total_slots-1).

signal slot_cambiado(slot_index: int, habilidad: HabilidadBase)

## Referencia explícita al jugador — asignar en el Inspector.
@export var jugador: Node

## Catálogo de habilidades disponibles — fuente única de verdad.
## MenuEquipamiento y PanelHabilidades leen de aquí.
@export var catalogo: Array[DatosHabilidad] = []

## Cantidad total de slots equipables (repartidos en páginas de a
## PaginadorHabilidades.POR_PAGINA en el HUD — ver ese archivo).
@export var total_slots: int = 10

var _instancias: Array[HabilidadBase] = []
var _datos_equipados: Array = []  # Array[DatosHabilidad]


func _ready() -> void:
	add_to_group("slot_habilidades")
	_instancias.resize(total_slots)
	_datos_equipados.resize(total_slots)
	# Notificar a UIHabilidad con el estado inicial.
	# Deferred para que UIHabilidad ya haya conectado slot_cambiado.
	call_deferred("_notificar_inicial")
	# Deferred obligatorio: peer_id_dueño lo asigna Jugador._ready(), que corre
	# DESPUÉS que el _ready() de sus hijos (este nodo) — leerlo acá directo
	# daría siempre -1 y la réplica nunca pediría su equipo.
	call_deferred("_pedir_equipo_replica_red")


func _notificar_inicial() -> void:
	for i in total_slots:
		slot_cambiado.emit(i, _instancias[i])
		if jugador:
			BusEventos.habilidad_equipada.emit(jugador, i, _instancias[i])


func _instanciar(index: int, escena: PackedScene, datos: DatosHabilidad = null) -> void:
	var hab := escena.instantiate() as HabilidadBase
	if not hab:
		push_error("SlotHabilidades: slot %d no es HabilidadBase" % index)
		return
	hab.entidad_dueña = jugador
	hab.slot_index    = index
	# force_readable_name=true: sin esto, add_child() le pone un nombre
	# interno tipo "@GolpeBasico@N" — N es un contador de CADA PROCESO, no
	# coincide entre cliente y servidor. HabilidadBase._activar_red() manda
	# el RPC resolviendo el nodo por su NodePath — si el nombre no coincide
	# en ambos lados, el servidor nunca encuentra el nodo y la habilidad no
	# hace nada (aunque visualmente parezca equipada).
	jugador.add_child(hab, true)
	_instancias[index] = hab
	if datos:
		hab.aplicar_datos(datos)


## Devuelve los DatosHabilidad equipados en el slot, o null.
func obtener_datos(index: int) -> DatosHabilidad:
	if index >= 0 and index < total_slots:
		return _datos_equipados[index] as DatosHabilidad
	return null


## Devuelve la instancia activa del slot indicado, o null.
func obtener(index: int) -> HabilidadBase:
	if index >= 0 and index < total_slots:
		return _instancias[index]
	return null


## Devuelve la primera habilidad cuyo tipo_habilidad coincide, o null.
func obtener_por_tipo(tipo: String) -> HabilidadBase:
	for hab in _instancias:
		if hab and hab.tipo_habilidad == tipo:
			return hab
	return null


## Número de slots con habilidad activa.
func cantidad_equipada() -> int:
	var n := 0
	for hab in _instancias:
		if hab != null:
			n += 1
	return n


## Reemplaza la habilidad en un slot usando DatosHabilidad.
func equipar(slot_index: int, datos: DatosHabilidad) -> void:
	if slot_index < 0 or slot_index >= total_slots:
		return
	if _instancias[slot_index]:
		_instancias[slot_index].queue_free()
		_instancias[slot_index] = null
	_datos_equipados[slot_index] = datos
	if datos and datos.escena:
		_instanciar(slot_index, datos.escena, datos)
	slot_cambiado.emit(slot_index, _instancias[slot_index])
	BusEventos.habilidad_equipada.emit(jugador, slot_index, _instancias[slot_index])
	_sincronizar_equipo_red(slot_index, datos)


## Sobrecarga para compatibilidad: equipar por PackedScene sin datos.
func equipar_escena(slot_index: int, escena: PackedScene) -> void:
	if slot_index < 0 or slot_index >= total_slots:
		return
	if _instancias[slot_index]:
		_instancias[slot_index].queue_free()
		_instancias[slot_index] = null
	_datos_equipados[slot_index] = null
	if escena:
		_instanciar(slot_index, escena)
	slot_cambiado.emit(slot_index, _instancias[slot_index])
	BusEventos.habilidad_equipada.emit(jugador, slot_index, _instancias[slot_index])


## Fase 7 del plan de multijugador: equipar desde el menú normal del juego
## solo tocaba el lado del CLIENTE — el servidor (autoritativo de verdad)
## nunca se enteraba, así que HabilidadBase._activar_red() no encontraba el
## nodo del lado del servidor y la habilidad no hacía nada (ver bug
## reportado: "las habilidades no se equipan"). Evita el eco infinito con
## _procesando_rpc_red (el servidor llama equipar() de nuevo al recibir el
## RPC, lo que dispararía otro intento de sincronizar si no se cortara acá).
var _procesando_rpc_red := false

func _sincronizar_equipo_red(slot_index: int, datos: DatosHabilidad) -> void:
	if not Utils.en_red():
		return
	if multiplayer.is_server():
		# Retransmitir a las réplicas de este jugador en TODOS los clientes
		# (el dueño se salta solo dentro de _equipar_replica): sin esto, los
		# demás peers no tienen el nodo de la habilidad y el RPC visual de
		# HabilidadBase._reproducir_visual_red les llegaba a un path
		# inexistente — un jugador nunca VEÍA las habilidades de otro. Va
		# ANTES del corte por _procesando_rpc_red: en el servidor equipar()
		# corre justamente dentro de _equipar_red (con la bandera puesta) y
		# aun así hay que retransmitir.
		rpc("_equipar_replica", slot_index, datos.resource_path if datos else "")
		return
	if _procesando_rpc_red:
		return
	if not is_instance_valid(jugador) or not ("peer_id_dueño" in jugador):
		return
	if jugador.peer_id_dueño != multiplayer.get_unique_id():
		return
	rpc_id(1, "_equipar_red", slot_index, datos.resource_path if datos else "")


@rpc("any_peer", "reliable")
func _equipar_red(slot_index: int, ruta_datos: String) -> void:
	if not multiplayer.is_server():
		return
	if not is_instance_valid(jugador) or not ("peer_id_dueño" in jugador):
		return
	if multiplayer.get_remote_sender_id() != jugador.peer_id_dueño:
		return
	var datos: DatosHabilidad = load(ruta_datos) as DatosHabilidad if ruta_datos != "" else null
	_procesando_rpc_red = true
	equipar(slot_index, datos)
	_procesando_rpc_red = false


## true si este SlotHabilidades es la RÉPLICA de un jugador AJENO en este
## peer — el único caso donde el equipo llega desde el servidor en vez de
## decidirse localmente. false en el servidor, en el dueño y fuera de red.
func _es_replica_remota() -> bool:
	if not Utils.en_red() or multiplayer.is_server():
		return false
	if not is_instance_valid(jugador) or not ("peer_id_dueño" in jugador):
		return false
	return jugador.peer_id_dueño >= 0 and jugador.peer_id_dueño != multiplayer.get_unique_id()


## Al aparecer la réplica de otro jugador en este cliente (spawn normal o
## conexión tardía), pedirle al servidor el equipo ACTUAL de ese jugador.
## También recupera cualquier _equipar_replica retransmitido mientras esta
## réplica todavía no existía acá (el RPC se perdía con "node not found").
func _pedir_equipo_replica_red() -> void:
	if _es_replica_remota():
		rpc_id(1, "_pedir_equipo_red")


## El servidor responde con el equipo completo del jugador de este slot —
## solo al peer que preguntó. No cambia ningún estado: seguro ante cualquier
## remitente.
@rpc("any_peer", "reliable")
func _pedir_equipo_red() -> void:
	if not multiplayer.is_server():
		return
	var solicitante := multiplayer.get_remote_sender_id()
	for i in total_slots:
		var datos: DatosHabilidad = _datos_equipados[i]
		if datos:
			rpc_id(solicitante, "_equipar_replica", i, datos.resource_path)


## Un cliente equipa acá la réplica de un jugador ajeno con lo que dicta el
## servidor ("authority": solo el servidor puede mandarlo). El dueño real se
## salta: él ya se equipó localmente (re-equipar le reiniciaría el cooldown).
@rpc("authority", "reliable")
func _equipar_replica(slot_index: int, ruta_datos: String) -> void:
	if not _es_replica_remota():
		return
	var datos: DatosHabilidad = load(ruta_datos) as DatosHabilidad if ruta_datos != "" else null
	_procesando_rpc_red = true
	equipar(slot_index, datos)
	_procesando_rpc_red = false
