extends RefCounted
class_name FuenteObjetos
## Adaptador entre una GrillaObjetos y la colección real que representa —
## quien recibe un drop (ver GrillaObjetos._transferir) llama a estos
## métodos sobre la fuente de CADA lado nada más; ninguna colección conoce
## ni le importa cómo persiste la otra. Una única instancia compartida por
## TODA la grilla (sin estado por casilla — acá no hay posiciones fijas,
## ver FuenteInventario/FuenteCofre).
##
## Dos interfaces a propósito, NO una sola:
## - agregar()/quitar(): mueve la REFERENCIA entera del ítem (stack
##   completo) — quitar() solo lo saca de la lista del origen, nunca toca
##   su "quantity", así que agregar() puede reusar la MISMA instancia del
##   lado del destino sin corromper nada.
## - agregar_cantidad()/quitar_cantidad(): mueve solo PARTE de un stack
##   (ver PopupCantidad, "cuantos quiero pasar") — acá SÍ hace falta
##   duplicar del lado de "agregar" (el origen se queda con el resto), y
##   quitar_cantidad() decrementa "quantity" de verdad en el origen. Por
##   eso NO se puede usar esta variante para un stack completo: como
##   GrillaObjetos._transferir agrega primero y recién después quita (para
##   no perder el ítem si el destino está lleno), reusar la referencia acá
##   y decrementarla después corrompería el ítem que ya está sentado en el
##   destino.

## false si no hay lugar (ej. cofre lleno, ver FuenteCofre) — el llamador
## NO debe quitar el ítem de su origen si esto devuelve false, o se
## perdería sin entrar a ningún lado.
func agregar(_item: DatosItem) -> bool:
	return true


func quitar(_item: DatosItem) -> void:
	pass


func agregar_cantidad(_item: DatosItem, _cantidad: int) -> bool:
	return true


func quitar_cantidad(_item: DatosItem, _cantidad: int) -> void:
	pass
