# =============================================================================
# Prueba de TiendaComponente — patrón RPC de "pedir → servidor valida →
# aplica → confirma solo al dueño" (mismo molde que MejorasComponente,
# ver prueba_lanzallamas_detiene_canal_por_servidor.gd para el mismo
# criterio de probar SIN transporte de red real).
#
# multiplayer.get_remote_sender_id() devuelve 0 cuando _pedir_comprar_red()
# se llama DIRECTO (no vía RPC real, sin nadie conectado) — por eso
# peer_id_dueño = 0 simula "el pedido vino del dueño de verdad" y
# cualquier otro valor simula un sender ajeno (anti-spoof).
#   godot --headless --path . --script res://pruebas/prueba_tienda_comprar_item.gd
# =============================================================================
extends SceneTree

var _jugador
var _creditos
var _inventario
var _tienda
var _item: DatosItem
var _ruta_item: String

var _sender_ajeno_rechaza_ok := false
var _creditos_insuficientes_rechaza_ok := false
var _compra_valida_descuenta_y_agrega_ok := false


func _process(_delta: float) -> bool:
	_montar()
	_probar_sender_ajeno()
	_probar_creditos_insuficientes()
	_probar_compra_valida()
	return _informar()


func _montar() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(0)
	root.multiplayer.multiplayer_peer = peer

	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(_jugador)

	_creditos = _jugador.get_node("CreditosComponente")
	_inventario = _jugador.get_node("InventarioComponente")
	_tienda = _jugador.get_node("TiendaComponente")
	_creditos.agregar_creditos(100)

	_item = load("res://recursos/items/consumibles/botiquin.tres") as DatosItem
	_ruta_item = _item.resource_path


## InventarioComponente.agregar_item() SIEMPRE duplica el recurso antes de
## guardarlo (para no mutar un .tres compartido, ver ese comentario) — el
## objeto guardado nunca es "== _item" por identidad, hay que comparar por
## nombre, mismo criterio que usa agregar_item() para detectar apilables.
func _cantidad_en_inventario() -> int:
	var total := 0
	for item: DatosItem in _inventario.items:
		if item.name == _item.name:
			total += 1
	return total


func _probar_sender_ajeno() -> void:
	_jugador.peer_id_dueño = 999  # no coincide con get_remote_sender_id() (0).
	_tienda._pedir_comprar_red(_ruta_item, 30)
	_sender_ajeno_rechaza_ok = _creditos.obtener_creditos() == 100 and _cantidad_en_inventario() == 0
	print("Sender que no es el dueño rechaza la compra (esperado true): %s" % _sender_ajeno_rechaza_ok)


func _probar_creditos_insuficientes() -> void:
	_jugador.peer_id_dueño = 0  # coincide con get_remote_sender_id() (0): dueño real.
	_tienda._pedir_comprar_red(_ruta_item, 99999)
	_creditos_insuficientes_rechaza_ok = _creditos.obtener_creditos() == 100 and _cantidad_en_inventario() == 0
	print("Créditos insuficientes rechaza la compra (esperado true): %s" % _creditos_insuficientes_rechaza_ok)


func _probar_compra_valida() -> void:
	_tienda._pedir_comprar_red(_ruta_item, 30)
	_compra_valida_descuenta_y_agrega_ok = _creditos.obtener_creditos() == 70 and _cantidad_en_inventario() == 1
	print("Compra válida descuenta créditos (100 -> 70) y agrega el ítem (esperado true): %s" % _compra_valida_descuenta_y_agrega_ok)


func _informar() -> bool:
	var exito := _sender_ajeno_rechaza_ok and _creditos_insuficientes_rechaza_ok \
		and _compra_valida_descuenta_y_agrega_ok
	print("PRUEBA TIENDA COMPRAR ITEM %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
