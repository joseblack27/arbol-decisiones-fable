extends FuenteObjetos
class_name FuenteAlmacenMinero
## Fuente de SOLO RETIRO para GrillaObjetos — el almacén compartido del
## minero (ver GestorMinero.gd/AlmacenMinero.gd), reusado con el mismo
## panel/grillas que un cofre normal (ver PanelCofre.gd, modo almacén del
## minero). Mismo diseño que FuenteAlmacenLenador.gd (ver ese archivo para
## el porqué completo): agregar()/agregar_cantidad() SIEMPRE devuelven
## false (nadie deposita acá arrastrando, solo el minero server-side), y
## quitar()/quitar_cantidad() enrutan por GestorMinero.pedir_retirar()
## (validado por el servidor).

func agregar(_item: DatosItem) -> bool:
	return false


func agregar_cantidad(_item: DatosItem, _cantidad: int) -> bool:
	return false


func quitar(item: DatosItem) -> void:
	GestorMinero.pedir_retirar(item.id_recurso, item.quantity)


func quitar_cantidad(item: DatosItem, cantidad: int) -> void:
	GestorMinero.pedir_retirar(item.id_recurso, cantidad)
