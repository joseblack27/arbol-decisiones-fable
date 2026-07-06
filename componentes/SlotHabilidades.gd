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
	jugador.add_child(hab)
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
