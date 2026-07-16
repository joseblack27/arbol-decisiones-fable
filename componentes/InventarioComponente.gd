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


## Usa un ítem consumible: aplica su efecto y saca UNA unidad del stack
## (el ítem entero si quantity ya era 1). La quita local siempre — mismo
## nivel de confianza que equipar (ver PanelInventario._equip_item, tampoco
## pasa por RPC). El efecto de curación SÍ es server-autoritativo (mismo
## motivo que VidaComponente.quitar_vida/agregar_vida): sin eso, un cliente
## podría curarse local mintiéndole el HP a los demás.
func usar_item(item: DatosItem) -> void:
	if item == null or not item.can_use:
		return
	# No desperdiciar consumibles que no aportarían nada: con la vida llena
	# una poción no se gasta, ni una jeringa con la energía llena. Un ítem
	# mixto (cura + energía) se usa si AL MENOS una de las dos falta.
	if not _consumible_util(item):
		return
	_quitar_una_unidad(item)
	if item.curacion > 0.0:
		_pedir_curacion(item.curacion)
	if item.energia > 0.0:
		_pedir_energia(item.energia)


## true si usar este ítem tendría algún efecto real ahora mismo. Los ítems
## sin efectos conocidos (curacion y energia en 0) se consumen como siempre
## — no hay forma de saber si "sirven", mejor no bloquearlos.
## El chequeo usa el espejo local de vida/energía (en red llegan replicados
## del servidor): puede desfasarse unos puntos por latencia, pero el peor
## caso es gastar una poción con 99.9% de vida — aceptable.
func _consumible_util(item: DatosItem) -> bool:
	if item.curacion <= 0.0 and item.energia <= 0.0:
		return true
	var padre := get_parent()
	if padre == null:
		return true
	if item.curacion > 0.0:
		var vida := padre.get_node_or_null("VidaComponente") as VidaComponente
		if vida == null or vida.obtener_vida() < vida.obtener_vida_maxima():
			return true
	if item.energia > 0.0:
		var energia := padre.get_node_or_null("EnergiaComponente") as EnergiaComponente
		if energia == null or not energia.tiene_energia(energia.energia_maxima):
			return true
	return false


## Siempre decrementa quantity de verdad (nunca la deja "atascada" en 1)
## para que cualquiera que solo tenga una referencia al ítem — como una
## casilla de la barra rápida de consumibles, que lo saca de "items" al
## soltarlo ahí — pueda saber si se agotó mirando item.quantity <= 0, sin
## depender de si sigue en esta lista o no. items.erase() es un no-op
## inofensivo si el ítem no está acá (ya vive en una casilla rápida).
func _quitar_una_unidad(item: DatosItem) -> void:
	item.quantity -= 1
	if item.quantity <= 0:
		items.erase(item)


func _pedir_curacion(cantidad: float) -> void:
	if Utils.en_red() and not multiplayer.is_server():
		rpc_id(1, "_pedir_curacion_red", cantidad)
		return
	_curar_local(cantidad)


func _curar_local(cantidad: float) -> void:
	var vida := get_parent().get_node_or_null("VidaComponente") as VidaComponente
	if vida:
		vida.agregar_vida(cantidad)


## SERVIDOR: el dueño de este inventario pide curarse (poción, botiquín...)
## — se verifica que quien llama sea de verdad el dueño (mismo criterio que
## HabilidadBase._activar_red) antes de aplicar la curación real.
@rpc("any_peer", "reliable")
func _pedir_curacion_red(cantidad: float) -> void:
	if not multiplayer.is_server():
		return
	var jugador := get_parent()
	if not jugador or not ("peer_id_dueño" in jugador):
		return
	if multiplayer.get_remote_sender_id() != jugador.peer_id_dueño:
		return
	_curar_local(cantidad)


## Espejo exacto del camino de curación, para consumibles de energía
## (jeringa de adrenalina): en red la energía real la decide el servidor
## (EnergiaComponente ya la replica solo hacia el cliente).
func _pedir_energia(cantidad: float) -> void:
	if Utils.en_red() and not multiplayer.is_server():
		rpc_id(1, "_pedir_energia_red", cantidad)
		return
	_energia_local(cantidad)


func _energia_local(cantidad: float) -> void:
	var energia := get_parent().get_node_or_null("EnergiaComponente") as EnergiaComponente
	if energia:
		energia.agregar_energia(cantidad)


## SERVIDOR: mismas verificaciones de dueño que _pedir_curacion_red.
@rpc("any_peer", "reliable")
func _pedir_energia_red(cantidad: float) -> void:
	if not multiplayer.is_server():
		return
	var jugador := get_parent()
	if not jugador or not ("peer_id_dueño" in jugador):
		return
	if multiplayer.get_remote_sender_id() != jugador.peer_id_dueño:
		return
	_energia_local(cantidad)
