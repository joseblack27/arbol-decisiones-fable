extends Node
class_name SlotHabilidades
## Manager de slots de habilidades equipadas.
## Asigna PackedScenes en el Inspector (o desde un menú en runtime).
## SlotHabilidades instancia las habilidades, asigna entidad_dueña y las añade
## como hijos del jugador. Para cambiar en runtime: equipar(index, nueva_escena).

signal slot_cambiado(slot_index: int, habilidad: HabilidadBase)

## Referencia explícita al jugador — asignar en el Inspector.
@export var jugador: Node

## Catálogo de habilidades disponibles — fuente única de verdad.
## MenuEquipamiento y PanelHabilidades leen de aquí.
@export var catalogo: Array[DatosHabilidad] = []

@export_group("Slots")
@export var slot_0: PackedScene = null
@export var slot_1: PackedScene = null
@export var slot_2: PackedScene = null
@export var slot_3: PackedScene = null

var _instancias: Array[HabilidadBase] = [null, null, null, null]
var _datos_equipados: Array = [null, null, null, null]  # Array[DatosHabilidad]


func _ready() -> void:
	add_to_group("slot_habilidades")
	for i in 4:
		var escena := _escena(i)
		if escena:
			# Buscar datos del catálogo por escena antes de instanciar
			for d in catalogo:
				if d and d.escena == escena:
					_datos_equipados[i] = d
					break
			_instanciar(i, escena, _datos_equipados[i])
	# Notificar a UIHabilidad con el estado inicial.
	# Deferred para que UIHabilidad ya haya conectado slot_cambiado.
	call_deferred("_notificar_inicial")


func _notificar_inicial() -> void:
	for i in 4:
		slot_cambiado.emit(i, _instancias[i])
		if jugador:
			BusEventos.habilidad_equipada.emit(jugador, i, _instancias[i])


func _escena(index: int) -> PackedScene:
	match index:
		0: return slot_0
		1: return slot_1
		2: return slot_2
		3: return slot_3
	return null


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
	if index >= 0 and index < 4:
		return _datos_equipados[index] as DatosHabilidad
	return null


## Devuelve la instancia activa del slot indicado, o null.
func obtener(index: int) -> HabilidadBase:
	if index >= 0 and index < 4:
		return _instancias[index]
	return null


## Devuelve la primera habilidad cuyo tipo_habilidad coincide, o null.
func obtener_por_tipo(tipo: String) -> HabilidadBase:
	for hab in _instancias:
		if hab and hab.tipo_habilidad == tipo:
			return hab
	return null


## Número de slots con habilidad activa.
func cantidad_slots() -> int:
	var n := 0
	for hab in _instancias:
		if hab != null:
			n += 1
	return n


## Reemplaza la habilidad en un slot usando DatosHabilidad.
func equipar(slot_index: int, datos: DatosHabilidad) -> void:
	if slot_index < 0 or slot_index >= 4:
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
	if slot_index < 0 or slot_index >= 4:
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
	if _procesando_rpc_red or not Utils.en_red() or multiplayer.is_server():
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
