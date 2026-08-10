# =============================================================================
# Bug real reportado: "el botón de vender no hace nada" — el pedido de venta
# SÍ llegaba al servidor (RPC, sender, dueño: todo bien), pero
# InventarioComponente.items del lado del SERVIDOR estaba VACÍO, así que
# _buscar_por_recurso nunca encontraba el ítem. Causa: GestorGuardado.
# _recibir_partida_red (CLIENTE) solo llena su propio espejo local — a
# diferencia del equipo (ver EquipoComponente._sincronizar_equipo_red), el
# inventario suelto nunca tenía un canal de vuelta al servidor, así que el
# AUTORITATIVO se quedaba sin saber qué había tras un cargar-partida/
# reconexión, aunque el cliente mostrara todo bien.
#
# Reproduce el escenario real: servidor con InventarioComponente.items
# VACÍO (como recién reconectado) + un cliente que "reporta" su espejo vía
# InventarioComponente._pedir_sincronizar_red — y confirma que DESPUÉS de
# eso, vender ese mismo ítem SÍ funciona (antes fallaba en silencio,
# _vender_local devolvía 0 con el inventario vacío).
#   godot --headless --path . --script res://pruebas/prueba_inventario_sincronizar_tras_cargar.gd
# =============================================================================
extends SceneTree

var _jugador
var _creditos
var _inventario
var _tienda

var _sender_ajeno_no_sincroniza_ok := false
var _sincroniza_desde_inventario_vacio_ok := false
var _vender_funciona_tras_sincronizar_ok := false


func _process(_delta: float) -> bool:
	_montar()
	_probar_sender_ajeno_no_sincroniza()
	_probar_sincroniza_desde_vacio()
	_probar_vender_funciona_tras_sincronizar()
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
	# A propósito NO se le agrega nada acá — simula el servidor recién
	# reconectado, con el InventarioComponente autoritativo vacío, que es
	# justo el estado que causaba el bug real.


func _rutas_y_cantidades(entradas: Array) -> Array:
	var rutas := PackedStringArray()
	var cantidades := PackedInt32Array()
	for entrada in entradas:
		rutas.append(entrada[0])
		cantidades.append(entrada[1])
	return [rutas, cantidades]


func _probar_sender_ajeno_no_sincroniza() -> void:
	_jugador.peer_id_dueño = 999  # no coincide con get_remote_sender_id() (0).
	var par := _rutas_y_cantidades([["res://recursos/items/consumibles/botiquin.tres", 3]])
	_inventario._pedir_sincronizar_red(par[0], par[1])
	_sender_ajeno_no_sincroniza_ok = _inventario.items.is_empty()
	print("Sender que no es el dueño no sincroniza (esperado true, sigue vacío): %s" % _sender_ajeno_no_sincroniza_ok)
	_jugador.peer_id_dueño = 0  # devolver al dueño real para el resto de la prueba.


func _probar_sincroniza_desde_vacio() -> void:
	var par := _rutas_y_cantidades([
		["res://recursos/items/equipables/armadura_1.tres", 1],
		["res://recursos/items/consumibles/botiquin.tres", 3],
	])
	_inventario._pedir_sincronizar_red(par[0], par[1])
	var armadura := _buscar_por_nombre("Armadura Ligera")
	var botiquin := _buscar_por_nombre("Botiquín")
	_sincroniza_desde_inventario_vacio_ok = _inventario.items.size() == 2 \
		and armadura != null and armadura.valor == 30 \
		and botiquin != null and botiquin.quantity == 3
	print("Sincronizar desde vacío repuebla el inventario autoritativo (esperado true): %s" % _sincroniza_desde_inventario_vacio_ok)


func _buscar_por_nombre(nombre: String) -> DatosItem:
	for item: DatosItem in _inventario.items:
		if item.name == nombre:
			return item
	return null


## El chequeo que de verdad reproduce el bug reportado: vender la armadura
## ANTES de sincronizar fallaba en silencio (inventario vacío del lado del
## servidor); DESPUÉS de sincronizar, el mismo pedido de venta sí paga.
func _probar_vender_funciona_tras_sincronizar() -> void:
	var creditos_antes: int = _creditos.obtener_creditos()
	_tienda._pedir_vender_red("res://recursos/items/equipables/armadura_1.tres", 1)
	var pago_esperado := int(30 * TiendaComponente.PORCENTAJE_VENTA)
	_vender_funciona_tras_sincronizar_ok = _creditos.obtener_creditos() == creditos_antes + pago_esperado \
		and _buscar_por_nombre("Armadura Ligera") == null
	print("Vender funciona después de sincronizar (esperado true): %s" % _vender_funciona_tras_sincronizar_ok)


func _informar() -> bool:
	var exito := _sender_ajeno_no_sincroniza_ok and _sincroniza_desde_inventario_vacio_ok \
		and _vender_funciona_tras_sincronizar_ok
	print("PRUEBA INVENTARIO SINCRONIZAR TRAS CARGAR %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
