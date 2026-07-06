extends VBoxContainer
class_name PanelNotificacionesLoot
## Lista de avisos rápidos: ítems obtenidos (BusEventos.item_agregado) y XP
## ganada (BusEventos.xp_agregada). No es interactuable (todo el árbol tiene
## mouse_filter=IGNORE). Sistema de cola: como máximo "max_filas_visibles"
## filas están en pantalla a la vez; lo que llega de más espera en _cola y se
## va mostrando a medida que las filas activas terminan su propio fundido y
## se eliminan solas.

@export var escena_notificacion: PackedScene = preload("res://escenas/ui/notificaciones_loot/NotificacionLoot.tscn")
@export var max_filas_visibles: int = 5

var _cola: Array[Dictionary] = []
var _activas := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	BusEventos.item_agregado.connect(_on_item_agregado)
	BusEventos.xp_agregada.connect(_on_xp_agregada)


func _on_item_agregado(item: DatosItem, cantidad: int) -> void:
	if item == null:
		return
	_encolar({"tipo": "item", "item": item, "cantidad": cantidad})


func _on_xp_agregada(cantidad: int, _xp_total: int) -> void:
	_encolar({"tipo": "xp", "texto": "+%d XP" % cantidad})


func _encolar(datos: Dictionary) -> void:
	_cola.append(datos)
	_procesar_cola()


func _procesar_cola() -> void:
	while _activas < max_filas_visibles and not _cola.is_empty():
		_mostrar(_cola.pop_front())


func _mostrar(datos: Dictionary) -> void:
	var noti := escena_notificacion.instantiate() as NotificacionLoot
	add_child(noti)
	_activas += 1
	noti.tree_exited.connect(_on_fila_terminada)
	if datos.tipo == "item":
		noti.configurar(datos.item, datos.cantidad)
	else:
		noti.configurar_texto(datos.texto)


func _on_fila_terminada() -> void:
	_activas -= 1
	_procesar_cola()
