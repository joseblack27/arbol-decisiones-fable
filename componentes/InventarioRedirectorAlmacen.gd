extends Node
class_name InventarioRedirectorAlmacen
## Reemplaza al InventarioComponente real como hijo llamado exactamente
## "InventarioComponente" de un NPC que caza (ver Cazador.gd):
## Enemigo._otorgar_item_al_atacante() busca ese nombre por CONVENCIÓN, no por
## tipo, así que esto intercepta el reparto de botín sin tocar Enemigo.gd.
##
## En vez de guardar el ítem, lo manda al almacén compartido del leñador.

func agregar_item(item: DatosItem, _cantidad: int = -1, _silencioso: bool = false) -> void:
	GestorLenador.depositar_servidor(item)
