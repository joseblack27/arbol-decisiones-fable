extends Node
class_name InventarioComponente
## InventarioComponente — el inventario de ESTE jugador (Fase 1 del plan de
## migración a multijugador: cada jugador tiene el suyo propio, en vez de
## un único inventario global compartido).
##
## Misma lógica que tenía GestorInventario (autoload) — se movió acá tal
## cual, dato incluido. GestorInventario.gd sigue existiendo como fachada de
## compatibilidad (ver ese archivo) para no tener que tocar todo el código
## que ya lo usa (PanelInventario, Enemigo, GestorGuardado...).

## DatosItem.type == 3 ("equipable"): estos nunca se apilan, cada uno es
## una entrada propia (a futuro podrían llevar stats distintos por copia).
const TYPE_EQUIPABLE := 3

var items: Array[DatosItem] = []


## Añade un ítem al inventario. Si es apilable (no equipable) y ya hay uno
## igual (mismo nombre y tipo), suma cantidades en vez de crear una entrada
## nueva. "cantidad" por defecto usa la del propio recurso (item.quantity).
## Siempre duplica el recurso antes de guardarlo: el mismo DatosItem .tres
## puede estar referenciado en varias tablas de botín a la vez, y mutar su
## "quantity" directamente corrompería ese recurso compartido.
##
## silencioso=true omite BusEventos.item_agregado (no dispara el popup de
## "obtuviste X" en PanelNotificacionesLoot): lo usa GestorGuardado al
## restaurar una partida — esos ítems ya eran tuyos, no son botín nuevo, y
## sin este flag el jugador veía una ráfaga de notificaciones de TODO su
## inventario guardado apenas cargaba (reportado por el usuario).
func agregar_item(item: DatosItem, cantidad: int = -1, silencioso: bool = false) -> void:
	if item == null:
		return
	var cantidad_real := cantidad if cantidad > 0 else item.quantity

	if item.type != TYPE_EQUIPABLE:
		for existente in items:
			if existente.name == item.name and existente.type == item.type:
				existente.quantity += cantidad_real
				if not silencioso:
					BusEventos.item_agregado.emit(existente, cantidad_real)
				return

	var copia := item.duplicate() as DatosItem
	copia.quantity = cantidad_real
	# .duplicate() no conserva resource_path — estampar id_recurso ahora
	# (mientras "item", el original, todavía lo tiene) es la única ventana
	# para no perderlo. "item.id_recurso" de respaldo cubre el caso de
	# GestorGuardado.cargar_partida(), que ya pasa un item recién cargado
	# desde disco vía load(), con resource_path pero sin necesidad de volver
	# a resolverlo.
	copia.id_recurso = item.id_recurso if item.id_recurso != "" else item.resource_path
	items.append(copia)
	if not silencioso:
		BusEventos.item_agregado.emit(copia, cantidad_real)


func quitar_item(item: DatosItem) -> void:
	items.erase(item)


func tiene_item(nombre: String) -> bool:
	for i in items:
		if i.name == nombre:
			return true
	return false
