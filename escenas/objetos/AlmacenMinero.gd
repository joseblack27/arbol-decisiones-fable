extends "res://escenas/objetos/AlmacenCompartido.gd"
class_name AlmacenMinero
## Almacén donde el minero deja el mineral (ver Minero.gd y GestorMinero.gd).


func _init() -> void:
	nombre = "Almacén del Minero"


func _pedir_panel() -> void:
	BusEventos.almacen_minero_solicitado.emit()
