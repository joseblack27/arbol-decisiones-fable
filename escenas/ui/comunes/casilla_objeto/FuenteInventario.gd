extends FuenteObjetos
class_name FuenteInventario
## Delega en GestorInventario (mismo facade que ya usa SlotItem/
## PanelInventario). silencioso=true: mover algo HACIA el inventario
## general desde otra colección (ej. un cofre propio) no es botín nuevo —
## mismo criterio que el resto de los flujos cofre<->inventario (ver
## CofresComponente/GestorGuardado). Sin tope de capacidad — agregar()
## siempre acepta.

func agregar(item: DatosItem) -> bool:
	GestorInventario.agregar_item(item, -1, true)
	return true


func quitar(item: DatosItem) -> void:
	GestorInventario.quitar_item(item)


## agregar_item(item, cantidad, true) ya fusiona con un stack existente del
## mismo nombre/tipo o duplica uno nuevo si hace falta (ver ese método) —
## nada especial que hacer acá.
func agregar_cantidad(item: DatosItem, cantidad: int) -> bool:
	GestorInventario.agregar_item(item, cantidad, true)
	return true


func quitar_cantidad(item: DatosItem, cantidad: int) -> void:
	GestorInventario.quitar_cantidad(item, cantidad)
