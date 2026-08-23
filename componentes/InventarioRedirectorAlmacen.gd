extends Node
class_name InventarioRedirectorAlmacen
## Reemplaza al InventarioComponente real como hijo nombrado exactamente
## "InventarioComponente" de un NPC no-jugador que caza de verdad (ver
## Cazador.gd) — Enemigo._otorgar_item_al_atacante() busca ese nombre por
## CONVENCIÓN, no por tipo (ver ese comentario en Enemigo.gd), así que este
## componente alcanza para interceptar el reparto de botín sin tocar
## Enemigo.gd en absoluto.
##
## En vez de guardar el ítem localmente, lo redirige al almacén compartido
## del leñador — pedido explícito del usuario: "que deje los recursos en
## el mismo cofre del leñador".

func agregar_item(item: DatosItem, _cantidad: int = -1, _silencioso: bool = false) -> void:
	GestorLenador.depositar_servidor(item)
