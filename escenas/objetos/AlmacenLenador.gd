extends "res://escenas/objetos/AlmacenCompartido.gd"
class_name AlmacenLenador
## Almacén donde el leñador deja la madera (ver Lenador.gd y GestorLenador.gd).


func _init() -> void:
	nombre = "Almacén del Leñador"


func _pedir_panel() -> void:
	BusEventos.almacen_lenador_solicitado.emit()
