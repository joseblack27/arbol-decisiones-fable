extends "res://escenas/ui/comunes/casilla_objeto/FuenteAlmacenCompartido.gd"
class_name FuenteAlmacenMinero
## Fuente de solo retiro del almacén del minero (ver FuenteAlmacenCompartido.gd).


func _gestor() -> Node:
	return GestorMinero
