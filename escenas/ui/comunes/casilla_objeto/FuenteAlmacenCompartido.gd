extends FuenteObjetos
## Fuente de SOLO RETIRO para GrillaObjetos: el almacén compartido de un NPC
## (ver GestorAlmacenCompartido.gd), con el mismo panel y grillas que un cofre
## (ver PanelCofre.gd, modo almacén). A diferencia de FuenteCofre (por jugador,
## sin validar), el pozo es COMPARTIDO y el servidor valida cada retiro (ver
## pedir_retirar). Cada almacén dice qué gestor usa (_gestor).
##
## agregar()/agregar_cantidad() SIEMPRE devuelven false: solo el NPC deposita
## (en el servidor). Por el contrato de FuenteObjetos ("false = no hay lugar, no
## quitar el ítem del origen"), eso ya bloquea arrastrar desde el inventario
## hacia esta grilla.
##
## item.id_recurso y NO item.resource_path: los DatosItem de esta grilla son
## duplicados frescos en cada refresco (ver PanelCofre, para no mutar el
## .quantity de un recurso cacheado), y Resource.duplicate() no conserva
## resource_path. Mismo campo que CofresComponente.agregar_cantidad().


## El autoload del almacén (GestorLenador, GestorMinero).
func _gestor() -> Node:
	return null


func agregar(_item: DatosItem) -> bool:
	return false


func agregar_cantidad(_item: DatosItem, _cantidad: int) -> bool:
	return false


func quitar(item: DatosItem) -> void:
	_gestor().pedir_retirar(item.id_recurso, item.quantity)


func quitar_cantidad(item: DatosItem, cantidad: int) -> void:
	_gestor().pedir_retirar(item.id_recurso, cantidad)
