extends FuenteObjetos
class_name FuenteAlmacenLenador
## Fuente de SOLO RETIRO para GrillaObjetos: el almacén compartido del leñador
## (ver GestorLenador.gd/AlmacenLenador.gd), con el mismo panel y grillas que
## un cofre (ver PanelCofre.gd, modo almacén). A diferencia de FuenteCofre (por
## jugador, sin validar), este pozo es COMPARTIDO y el servidor valida cada
## retiro (ver GestorLenador.pedir_retirar, el mismo patrón de 4 pasos que
## ObjetoRecolectable._pedir_recolectar_red).
##
## agregar()/agregar_cantidad() SIEMPRE devuelven false: solo el leñador
## deposita (en el servidor, ver GestorLenador.depositar_servidor). Por el
## contrato de FuenteObjetos ("false = no hay lugar, no quitar el ítem del
## origen"), eso ya bloquea arrastrar desde el inventario hacia esta grilla.
##
## item.id_recurso y NO item.resource_path: los DatosItem de esta grilla son
## duplicados frescos en cada refresco (ver
## PanelCofre._obtener_items_almacen, para no mutar el .quantity de un recurso
## cacheado), y Resource.duplicate() no conserva resource_path. Mismo campo
## que CofresComponente.agregar_cantidad().

func agregar(_item: DatosItem) -> bool:
	return false


func agregar_cantidad(_item: DatosItem, _cantidad: int) -> bool:
	return false


func quitar(item: DatosItem) -> void:
	GestorLenador.pedir_retirar(item.id_recurso, item.quantity)


func quitar_cantidad(item: DatosItem, cantidad: int) -> void:
	GestorLenador.pedir_retirar(item.id_recurso, cantidad)
