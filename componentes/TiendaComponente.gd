extends Node
class_name TiendaComponente
## Compra en la tienda de un NPC — mismo patrón cliente-pide/servidor-decide
## que MejorasComponente.gastar_en_pasiva: el cliente en red solo pide, el
## SERVIDOR es quien de verdad valida los créditos y aplica el cambio
## (CreditosComponente.quitar_creditos + InventarioComponente.agregar_item),
## confirmando SOLO al dueño (no un broadcast) vía ComponenteConfirmacionesRed.

## API pública: comprar UN ItemTienda (item + precio) de un DatosTienda.
func comprar_item(item_tienda: ItemTienda) -> void:
	if item_tienda == null or item_tienda.item == null:
		return
	if Utils.en_red() and not multiplayer.is_server():
		rpc_id(1, "_pedir_comprar_red", item_tienda.item.resource_path, item_tienda.precio)
		return
	_comprar_por_ruta(item_tienda.item.resource_path, item_tienda.precio)


func _comprar_por_ruta(ruta_item: String, precio: int) -> bool:
	var item: DatosItem = load(ruta_item) as DatosItem if ruta_item != "" else null
	return _comprar_local(item, precio)


## SERVIDOR: mismas verificaciones de dueño que el resto de los RPC "pedir"
## del proyecto (ver MejorasComponente._pedir_gastar_pasiva_red). Si la
## compra se concreta, confirma de vuelta al cliente dueño con el saldo de
## créditos YA descontado — el cliente no vuelve a restar de su lado, fija
## el valor exacto que ya calculó el servidor (ver CreditosComponente.
## _fijar_creditos_local).
@rpc("any_peer", "reliable")
func _pedir_comprar_red(ruta_item: String, precio: int) -> void:
	if not multiplayer.is_server():
		return
	var jugador := get_parent()
	if not jugador or not ("peer_id_dueño" in jugador):
		return
	if multiplayer.get_remote_sender_id() != jugador.peer_id_dueño:
		return
	if _comprar_por_ruta(ruta_item, precio):
		var item := load(ruta_item) as DatosItem
		var creditos := jugador.get_node_or_null("CreditosComponente") as CreditosComponente
		var confirmaciones := jugador.get_node_or_null("ComponenteConfirmacionesRed")
		if confirmaciones and creditos and item:
			confirmaciones.rpc_id(jugador.peer_id_dueño, "_recibir_compra_red",
					ruta_item, item.quantity, creditos.obtener_creditos())


## Aplica la compra DE VERDAD — reusado por comprar_item() (fuera de red o
## ya siendo el servidor) y por el flujo RPC de arriba. true si se concretó.
func _comprar_local(item: DatosItem, precio: int) -> bool:
	if item == null or precio < 0:
		return false
	var padre := get_parent()
	if padre == null:
		return false
	var creditos := padre.get_node_or_null("CreditosComponente") as CreditosComponente
	if creditos == null or not creditos.quitar_creditos(precio):
		return false
	var inventario := padre.get_node_or_null("InventarioComponente")
	if inventario == null:
		# No debería pasar (todo Jugador tiene InventarioComponente) — pero si
		# faltara, no dejar los créditos gastados sin nada a cambio.
		creditos.agregar_creditos(precio)
		return false
	inventario.agregar_item(item)
	return true


# =============================================================================
# Vender
# =============================================================================

## Fracción del DatosItem.valor que se paga al vender — no es lo mismo que
## costaría comprarlo de vuelta (si no, comprar y vender el mismo ítem
## saldría gratis). Punto de partida razonable (uso común en RPGs), fácil
## de ajustar acá mismo si hace falta otra proporción.
const PORCENTAJE_VENTA := 0.5

## API pública: vender "cantidad" unidades de un ítem del inventario propio
## a cambio de créditos. A diferencia de comprar_item() (que recibe el
## precio del lado del llamador), acá el SERVIDOR calcula el pago solo, a
## partir del DatosItem.valor real cargado del disco — el cliente nunca
## puede inflar cuánto cobra pidiendo un valor distinto.
func vender_item(item: DatosItem, cantidad: int = 1) -> void:
	if item == null or cantidad <= 0 or item.id_recurso == "":
		return
	if Utils.en_red() and not multiplayer.is_server():
		rpc_id(1, "_pedir_vender_red", item.id_recurso, cantidad)
		return
	_vender_local(item.id_recurso, cantidad)


## SERVIDOR: mismas verificaciones de dueño que _pedir_comprar_red. Si la
## venta se concreta, confirma de vuelta al cliente dueño con el saldo de
## créditos YA sumado — el cliente no vuelve a sumar de su lado, fija el
## valor exacto que ya calculó el servidor.
@rpc("any_peer", "reliable")
func _pedir_vender_red(ruta_item: String, cantidad: int) -> void:
	if not multiplayer.is_server():
		return
	var jugador := get_parent()
	if not jugador or not ("peer_id_dueño" in jugador):
		return
	if multiplayer.get_remote_sender_id() != jugador.peer_id_dueño:
		return
	var pago := _vender_local(ruta_item, cantidad)
	if pago > 0:
		var creditos := jugador.get_node_or_null("CreditosComponente") as CreditosComponente
		var confirmaciones := jugador.get_node_or_null("ComponenteConfirmacionesRed")
		if confirmaciones and creditos:
			confirmaciones.rpc_id(jugador.peer_id_dueño, "_recibir_venta_red",
					ruta_item, cantidad, creditos.obtener_creditos())


## Aplica la venta DE VERDAD — reusado por vender_item() (fuera de red o ya
## siendo el servidor) y por el flujo RPC de arriba. Devuelve los créditos
## pagados (0 si no se concretó: no tenía la cantidad pedida, el ítem no
## tiene valor de venta...) — nunca confía en que el cliente diga tener
## algo, siempre revalida contra el InventarioComponente real.
func _vender_local(ruta_item: String, cantidad: int) -> int:
	if ruta_item == "" or cantidad <= 0:
		return 0
	var padre := get_parent()
	if padre == null:
		return 0
	var inventario := padre.get_node_or_null("InventarioComponente")
	if inventario == null:
		return 0
	var item_real := _buscar_por_recurso(inventario, ruta_item)
	if item_real == null or item_real.valor <= 0:
		return 0
	if not inventario.quitar_cantidad(item_real, cantidad):
		return 0
	var pago := int(item_real.valor * PORCENTAJE_VENTA) * cantidad
	var creditos := padre.get_node_or_null("CreditosComponente") as CreditosComponente
	if creditos:
		creditos.agregar_creditos(pago)
	return pago


## Busca en el inventario REAL la entrada cuyo id_recurso coincide — mismo
## campo que InventarioComponente.agregar_item() ya usa para recargar el
## .tres original tras un duplicate() (ver ese comentario, por qué). Los
## ítems EQUIPABLE nunca se apilan (puede haber más de una entrada con el
## mismo id_recurso, ej. dos espadas de hierro idénticas) — sin ninguna
## diferencia real entre copias (sin durabilidad ni stats por instancia en
## este modelo de datos), vender cualquiera de ellas es equivalente.
func _buscar_por_recurso(inventario, ruta_item: String) -> DatosItem:
	for item: DatosItem in inventario.items:
		if item.id_recurso == ruta_item:
			return item
	return null
