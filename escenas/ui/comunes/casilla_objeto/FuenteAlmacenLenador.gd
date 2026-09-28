extends "res://escenas/ui/comunes/casilla_objeto/FuenteAlmacenCompartido.gd"
class_name FuenteAlmacenLenador
## Fuente de solo retiro del almacén del leñador (ver FuenteAlmacenCompartido.gd).


func _gestor() -> Node:
	return GestorLenador
