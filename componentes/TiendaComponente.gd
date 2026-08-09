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
