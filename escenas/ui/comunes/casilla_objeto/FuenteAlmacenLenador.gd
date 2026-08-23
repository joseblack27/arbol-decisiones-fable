extends FuenteObjetos
class_name FuenteAlmacenLenador
## Fuente de SOLO RETIRO para GrillaObjetos — el almacén compartido del
## leñador (ver GestorLenador.gd/AlmacenLenador.gd), reusado con el mismo
## panel/grillas que un cofre normal (ver PanelCofre.gd, modo almacén). A
## diferencia de FuenteCofre (por jugador, sin validar — CofresComponente
## muta directo, sin RPC), este pozo es COMPARTIDO por todos los jugadores
## y el servidor valida cada retiro (ver GestorLenador.pedir_retirar, mismo
## patrón de 4 pasos que ObjetoRecolectable._pedir_recolectar_red).
##
## agregar()/agregar_cantidad() SIEMPRE devuelven false — pedido explícito
## del usuario tras preguntarle: nadie deposita acá arrastrando, solo el
## leñador (server-side, ver GestorLenador.depositar_servidor). Por el
## contrato de FuenteObjetos ("false = no hay lugar, el llamador no debe
## quitar el ítem de su origen"), esto alcanza para bloquear un drag desde
## el inventario del jugador hacia esta grilla sin tocar GrillaObjetos.
##
## item.id_recurso (NO item.resource_path): los DatosItem que arma esta
## grilla son duplicados frescos por cada refresco (ver PanelCofre.
## _obtener_items_almacen — necesario para no mutar el .quantity de un
## recurso CACHEADO por el ResourceLoader), y Resource.duplicate() no
## conserva resource_path — mismo motivo/mismo campo que ya usa
## CofresComponente.agregar_cantidad() para este caso.

func agregar(_item: DatosItem) -> bool:
	return false


func agregar_cantidad(_item: DatosItem, _cantidad: int) -> bool:
	return false


func quitar(item: DatosItem) -> void:
	GestorLenador.pedir_retirar(item.id_recurso, item.quantity)


func quitar_cantidad(item: DatosItem, cantidad: int) -> void:
	GestorLenador.pedir_retirar(item.id_recurso, cantidad)
