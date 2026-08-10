# =============================================================================
# Prueba de TiendaComponente.vender_item — mismo patrón RPC de "pedir →
# servidor valida → aplica → confirma solo al dueño" que prueba_tienda_
# comprar_item.gd (ver ese archivo para el criterio de probar sin
# transporte de red real: get_remote_sender_id() devuelve 0 cuando
# _pedir_vender_red() se llama directo, por eso peer_id_dueño = 0 simula
# "el pedido vino del dueño de verdad").
#
# A diferencia de comprar, acá el SERVIDOR calcula el pago solo (nunca
# confía en un precio mandado por el cliente, ver TiendaComponente.
# _vender_local) — estas pruebas verifican esa cuenta contra DatosItem.
# valor/PORCENTAJE_VENTA, no contra ningún valor inventado por el test.
#   godot --headless --path . --script res://pruebas/prueba_tienda_vender_item.gd
# =============================================================================
extends SceneTree

var _jugador
var _creditos
var _inventario
var _tienda
var _item_vendible: DatosItem
var _item_no_vendible: DatosItem

var _sender_ajeno_rechaza_ok := false
var _cantidad_mayor_a_la_tenida_rechaza_ok := false
var _item_sin_valor_rechaza_ok := false
var _venta_parcial_ok := false
var _venta_total_saca_del_inventario_ok := false


func _process(_delta: float) -> bool:
	_montar()
	_probar_sender_ajeno()
	_probar_cantidad_mayor_a_la_tenida()
	_probar_item_sin_valor()
	_probar_venta_parcial()
	_probar_venta_total_saca_del_inventario()
	return _informar()


func _montar() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(0)
	root.multiplayer.multiplayer_peer = peer

	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(_jugador)
	_jugador.peer_id_dueño = 0  # coincide con get_remote_sender_id() (0): dueño real.

	_creditos = _jugador.get_node("CreditosComponente")
	_inventario = _jugador.get_node("InventarioComponente")
	_tienda = _jugador.get_node("TiendaComponente")

	# 3 botiquines (valor=15) para vender de a partes sin agotar el stack
	# antes de la última prueba.
	var botiquin := load("res://recursos/items/consumibles/botiquin.tres") as DatosItem
	_inventario.agregar_item(botiquin, 3, true)
	_item_vendible = _buscar_por_nombre(botiquin.name)

	# Un ítem tipo PASIVA nunca tuvo valor de venta asignado (valor=0 por
	# defecto, ver DatosItem.valor) — cubre "0 = no se le puede vender a
	# ningún comerciante" (ítems de misión son el otro caso real, mismo
	# valor 0; los equipables SÍ tienen valor asignado desde la tarea de
	# precios de equipables, ya no sirven de ejemplo acá).
	var tomo := load("res://recursos/items/pasivas/tomo_cosecha_de_vida.tres") as DatosItem
	_inventario.agregar_item(tomo, 1, true)
	_item_no_vendible = _buscar_por_nombre(tomo.name)


## agregar_item() siempre duplica el recurso antes de guardarlo (para no
## mutar un .tres compartido) — el objeto guardado nunca es "==" al
# original por identidad, hay que ubicarlo por nombre, mismo criterio que
## usa prueba_tienda_comprar_item.gd.
func _buscar_por_nombre(nombre: String) -> DatosItem:
	for item: DatosItem in _inventario.items:
		if item.name == nombre:
			return item
	return null


func _probar_sender_ajeno() -> void:
	_jugador.peer_id_dueño = 999  # no coincide con get_remote_sender_id() (0).
	_tienda._pedir_vender_red(_item_vendible.id_recurso, 1)
	_sender_ajeno_rechaza_ok = _creditos.obtener_creditos() == 0 and _item_vendible.quantity == 3
	print("Sender que no es el dueño rechaza la venta (esperado true): %s" % _sender_ajeno_rechaza_ok)
	_jugador.peer_id_dueño = 0  # devolver al dueño real para el resto de la prueba.


func _probar_cantidad_mayor_a_la_tenida() -> void:
	_tienda._pedir_vender_red(_item_vendible.id_recurso, 99)
	_cantidad_mayor_a_la_tenida_rechaza_ok = _creditos.obtener_creditos() == 0 and _item_vendible.quantity == 3
	print("Pedir vender más de lo que se tiene rechaza (esperado true): %s" % _cantidad_mayor_a_la_tenida_rechaza_ok)


func _probar_item_sin_valor() -> void:
	_tienda._pedir_vender_red(_item_no_vendible.id_recurso, 1)
	_item_sin_valor_rechaza_ok = _creditos.obtener_creditos() == 0 \
		and _buscar_por_nombre(_item_no_vendible.name) != null
	print("Ítem con valor=0 (tipo PASIVA) rechaza la venta (esperado true): %s" % _item_sin_valor_rechaza_ok)


func _probar_venta_parcial() -> void:
	var pago_esperado := int(_item_vendible.valor * TiendaComponente.PORCENTAJE_VENTA) * 2
	_tienda._pedir_vender_red(_item_vendible.id_recurso, 2)
	_venta_parcial_ok = _creditos.obtener_creditos() == pago_esperado and _item_vendible.quantity == 1
	print("Vender 2 de 3 paga %d créditos y deja quantity=1 (esperado true): %s" % [pago_esperado, _venta_parcial_ok])


func _probar_venta_total_saca_del_inventario() -> void:
	var creditos_antes: int = _creditos.obtener_creditos()
	var pago_esperado := int(_item_vendible.valor * TiendaComponente.PORCENTAJE_VENTA)
	_tienda._pedir_vender_red(_item_vendible.id_recurso, 1)
	_venta_total_saca_del_inventario_ok = _creditos.obtener_creditos() == creditos_antes + pago_esperado \
		and _buscar_por_nombre(_item_vendible.name) == null
	print("Vender la última unidad saca el ítem del inventario (esperado true): %s" % _venta_total_saca_del_inventario_ok)


func _informar() -> bool:
	var exito := _sender_ajeno_rechaza_ok and _cantidad_mayor_a_la_tenida_rechaza_ok \
		and _item_sin_valor_rechaza_ok and _venta_parcial_ok and _venta_total_saca_del_inventario_ok
	print("PRUEBA TIENDA VENDER ITEM %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
