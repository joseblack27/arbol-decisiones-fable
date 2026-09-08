# =============================================================================
# Prueba del almacén compartido del minero (GestorMinero.gd) — mirror exacto
# de prueba_almacen_lenador_compartido.gd (ver ese archivo para el porqué
# completo de cada decisión). Mismo patrón "sin transporte real":
# ENetMultiplayerPeer de servidor SIN conexión real, get_remote_sender_id()
# da 0 al llamar el RPC directo.
#
# Cubre:
#   1. Retirar más de lo disponible rechaza (no descuenta nada).
#   2. Sender sin jugador identificable rechaza.
#   3. Retiro válido descuenta del almacén GLOBAL y le da el ítem al
#      inventario del jugador.
#   4. Un SEGUNDO jugador ve el mismo total actualizado tras el depósito —
#      no son copias por jugador.
#   godot --headless --path . --script res://pruebas/prueba_almacen_minero_compartido.gd
# =============================================================================
extends SceneTree

const _RUTA_MINERAL := "res://recursos/items/recursos/mineral_cristal_1.tres"

var _gm
var _jugador_a
var _jugador_b

var _retirar_de_mas_rechaza_ok := false
var _sender_sin_jugador_rechaza_ok := false
var _retiro_valido_descuenta_y_da_item_ok := false
var _segundo_jugador_ve_el_mismo_total_ok := false


func _process(_delta: float) -> bool:
	_montar()
	_probar_retirar_de_mas_rechaza()
	_probar_sender_sin_jugador_rechaza()
	_probar_retiro_valido()
	_probar_segundo_jugador_ve_el_mismo_total()
	return _informar()


func _montar() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(0)
	root.multiplayer.multiplayer_peer = peer

	_gm = root.get_node("/root/GestorMinero")
	_gm._almacen.clear()
	_gm.almacen_replicado.clear()

	var item := load(_RUTA_MINERAL) as DatosItem
	_gm.depositar_servidor(item)  # 1 unidad, ver mineral_cristal_1.tres (quantity=1).

	_jugador_a = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	_jugador_a.name = "0"  # get_remote_sender_id() da 0 sin transporte real.
	_jugador_a.peer_id_dueño = 0
	root.add_child(_jugador_a)

	_jugador_b = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	_jugador_b.name = "999"
	_jugador_b.peer_id_dueño = 999
	root.add_child(_jugador_b)


func _cantidad_mineral(inventario) -> int:
	var total := 0
	for item: DatosItem in inventario.items:
		if item.name == "Mineral de Cristal":
			total += item.quantity
	return total


func _probar_retirar_de_mas_rechaza() -> void:
	_gm._pedir_retirar_red(_RUTA_MINERAL, 999)
	var total: int = _gm._almacen.get(_RUTA_MINERAL, 0)
	print("Retirar más de lo disponible no descuenta nada (esperado 1): %d" % total)
	_retirar_de_mas_rechaza_ok = total == 1


func _probar_sender_sin_jugador_rechaza() -> void:
	root.remove_child(_jugador_a)
	# InteresEspacial cachea jugador_de_peer() por fotograma físico (ver ese
	# archivo) — sacar/meter el nodo DENTRO del mismo fotograma (sin
	# transporte real de por medio) necesita invalidar a mano.
	root.get_node("/root/InteresEspacial").invalidar_cache_jugadores()
	_gm._pedir_retirar_red(_RUTA_MINERAL, 1)
	var total: int = _gm._almacen.get(_RUTA_MINERAL, 0)
	print("Sender sin jugador identificable no descuenta nada (esperado 1): %d" % total)
	_sender_sin_jugador_rechaza_ok = total == 1
	root.add_child(_jugador_a)
	root.get_node("/root/InteresEspacial").invalidar_cache_jugadores()


func _probar_retiro_valido() -> void:
	_gm._pedir_retirar_red(_RUTA_MINERAL, 1)
	var total: int = _gm._almacen.get(_RUTA_MINERAL, 0)
	var inventario_a: Node = _jugador_a.get_node("InventarioComponente")
	print("Retiro válido descuenta del almacén (esperado 0): %d" % total)
	print("Y le da el mineral al jugador que la pidió (esperado 1): %d" % _cantidad_mineral(inventario_a))
	_retiro_valido_descuenta_y_da_item_ok = total == 0 and _cantidad_mineral(inventario_a) == 1


func _probar_segundo_jugador_ve_el_mismo_total() -> void:
	var item := load(_RUTA_MINERAL) as DatosItem
	_gm.depositar_servidor(item)
	_gm.depositar_servidor(item)
	var total_antes: int = _gm._almacen.get(_RUTA_MINERAL, 0)
	print("Total antes de que B retire (esperado 2): %d" % total_antes)

	_gm._pedir_retirar_red(_RUTA_MINERAL, 1)

	root.remove_child(_jugador_a)
	_jugador_a.queue_free()
	_jugador_b.name = "0"
	root.get_node("/root/InteresEspacial").invalidar_cache_jugadores()
	_jugador_b.peer_id_dueño = 0
	_gm._pedir_retirar_red(_RUTA_MINERAL, 1)

	var total_final: int = _gm._almacen.get(_RUTA_MINERAL, 0)
	var inventario_b: Node = _jugador_b.get_node("InventarioComponente")
	print("Total tras el retiro de B (esperado 0): %d" % total_final)
	print("B recibió el mineral restante (esperado 1): %d" % _cantidad_mineral(inventario_b))
	_segundo_jugador_ve_el_mismo_total_ok = total_final == 0 and _cantidad_mineral(inventario_b) == 1


func _informar() -> bool:
	var exito := _retirar_de_mas_rechaza_ok and _sender_sin_jugador_rechaza_ok \
		and _retiro_valido_descuenta_y_da_item_ok and _segundo_jugador_ve_el_mismo_total_ok
	print("PRUEBA ALMACEN MINERO COMPARTIDO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
