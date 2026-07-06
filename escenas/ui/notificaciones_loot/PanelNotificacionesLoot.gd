extends VBoxContainer
class_name PanelNotificacionesLoot
## Lista de avisos rápidos: ítems obtenidos (BusEventos.item_agregado) y XP
## ganada (BusEventos.xp_agregada) — cada aviso apila una fila debajo de la
## anterior. No es interactuable (todo el árbol tiene mouse_filter=IGNORE) y
## cada fila se desvanece y se borra sola a los pocos segundos — esto solo
## conecta las señales y las va agregando, no gestiona su ciclo de vida.

@export var escena_notificacion: PackedScene = preload("res://escenas/ui/notificaciones_loot/NotificacionLoot.tscn")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	BusEventos.item_agregado.connect(_on_item_agregado)
	BusEventos.xp_agregada.connect(_on_xp_agregada)


func _on_item_agregado(item: DatosItem, cantidad: int) -> void:
	if item == null:
		return
	var noti := escena_notificacion.instantiate() as NotificacionLoot
	add_child(noti)
	noti.configurar(item, cantidad)


func _on_xp_agregada(cantidad: int, _xp_total: int) -> void:
	var noti := escena_notificacion.instantiate() as NotificacionLoot
	add_child(noti)
	noti.configurar_texto("+%d XP" % cantidad)
