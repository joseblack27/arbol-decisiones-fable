# =============================================================================
# Prueba del almacén compartido del leñador (GestorLenador.gd) — el usuario
# confirmó explícitamente que quería un "pozo compartido real": una sola
# cantidad de verdad, validada por el servidor, la misma para todos los
# jugadores en todo momento (a diferencia de los cofres normales, por
# jugador — ver Cofre.gd/CofresComponente). Mismo patrón "sin transporte
# real" que prueba_tienda_comprar_item.gd/prueba_objeto_recolectable.gd:
# ENetMultiplayerPeer de servidor SIN conexión real, get_remote_sender_id()
# da 0 al llamar el RPC directo.
#
# Cubre:
#   1. Retirar más de lo disponible rechaza (no descuenta nada).
#   2. Sender sin jugador identificable rechaza.
#   3. Retiro válido descuenta del almacén GLOBAL y le da el ítem al
#      inventario del jugador.
#   4. Un SEGUNDO jugador ve el mismo total actualizado tras el depósito —
#      el punto central del pedido del usuario: no son copias por jugador.
#   godot --headless --path . --script res://pruebas/prueba_almacen_lenador_compartido.gd
# =============================================================================
extends SceneTree

const _RUTA_LENA := "res://recursos/items/recursos/lena_1.tres"

var _gl
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

	_gl = root.get_node("/root/GestorLenador")
	_gl._almacen.clear()
	_gl.almacen_replicado.clear()

	var item := load(_RUTA_LENA) as DatosItem
	_gl.depositar_servidor(item)  # 1 unidad, ver lena_1.tres (quantity=1).

	_jugador_a = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	_jugador_a.name = "0"  # get_remote_sender_id() da 0 sin transporte real.
	_jugador_a.peer_id_dueño = 0
	root.add_child(_jugador_a)

	_jugador_b = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	_jugador_b.name = "999"
	_jugador_b.peer_id_dueño = 999
	root.add_child(_jugador_b)


func _cantidad_lena(inventario) -> int:
	var total := 0
	for item: DatosItem in inventario.items:
		if item.name == "Leña":
			total += item.quantity
	return total


func _probar_retirar_de_mas_rechaza() -> void:
	_gl._pedir_retirar_red(_RUTA_LENA, 999)
	var total: int = _gl._almacen.get(_RUTA_LENA, 0)
	print("Retirar más de lo disponible no descuenta nada (esperado 1): %d" % total)
	_retirar_de_mas_rechaza_ok = total == 1


func _probar_sender_sin_jugador_rechaza() -> void:
	# multiplayer.get_remote_sender_id() da 0 al llamar el RPC directo sin
	# transporte real — sacamos al jugador "0" de la escena así
	# InteresEspacial.jugador_de_peer(0) no encuentra a nadie.
	root.remove_child(_jugador_a)
	# InteresEspacial cachea jugador_de_peer() por fotograma físico (ver ese
	# archivo) — sacar/meter el nodo DENTRO del mismo fotograma (sin
	# transporte real de por medio) necesita invalidar a mano.
	root.get_node("/root/InteresEspacial").invalidar_cache_jugadores()
	_gl._pedir_retirar_red(_RUTA_LENA, 1)
	var total: int = _gl._almacen.get(_RUTA_LENA, 0)
	print("Sender sin jugador identificable no descuenta nada (esperado 1): %d" % total)
	_sender_sin_jugador_rechaza_ok = total == 1
	root.add_child(_jugador_a)
	root.get_node("/root/InteresEspacial").invalidar_cache_jugadores()


func _probar_retiro_valido() -> void:
	_gl._pedir_retirar_red(_RUTA_LENA, 1)
	var total: int = _gl._almacen.get(_RUTA_LENA, 0)
	var inventario_a: Node = _jugador_a.get_node("InventarioComponente")
	print("Retiro válido descuenta del almacén (esperado 0): %d" % total)
	print("Y le da la Leña al jugador que la pidió (esperado 1): %d" % _cantidad_lena(inventario_a))
	_retiro_valido_descuenta_y_da_item_ok = total == 0 and _cantidad_lena(inventario_a) == 1


## El punto central del pedido del usuario: el segundo jugador retira contra
## el MISMO total que dejó el primero (no una copia propia sin tocar) — si
## el almacén fuera por jugador (como un Cofre normal), B vería su propia
## entrada vacía/con otro valor, sin importar lo que A ya haya sacado.
func _probar_segundo_jugador_ve_el_mismo_total() -> void:
	var item := load(_RUTA_LENA) as DatosItem
	_gl.depositar_servidor(item)
	_gl.depositar_servidor(item)
	var total_antes: int = _gl._almacen.get(_RUTA_LENA, 0)
	print("Total antes de que B retire (esperado 2): %d" % total_antes)

	# _jugador_a (peer "0") retira 1 primero — mismo camino que
	# _probar_retiro_valido, deja el total en 1.
	_gl._pedir_retirar_red(_RUTA_LENA, 1)

	# multiplayer.get_remote_sender_id() SIEMPRE da 0 al llamar el RPC
	# directo sin transporte real (mismo límite que el resto de esta
	# suite) — para simular que ahora es OTRO jugador el que pide, se saca
	# a A de la escena y se pone a B en el nombre "0" (InteresEspacial.
	# jugador_de_peer busca por nombre exacto).
	root.remove_child(_jugador_a)
	_jugador_a.queue_free()
	_jugador_b.name = "0"
	root.get_node("/root/InteresEspacial").invalidar_cache_jugadores()
	_jugador_b.peer_id_dueño = 0
	_gl._pedir_retirar_red(_RUTA_LENA, 1)

	var total_final: int = _gl._almacen.get(_RUTA_LENA, 0)
	var inventario_b: Node = _jugador_b.get_node("InventarioComponente")
	print("Total tras el retiro de B (esperado 0): %d" % total_final)
	print("B recibió la Leña restante (esperado 1): %d" % _cantidad_lena(inventario_b))
	_segundo_jugador_ve_el_mismo_total_ok = total_final == 0 and _cantidad_lena(inventario_b) == 1


func _informar() -> bool:
	var exito := _retirar_de_mas_rechaza_ok and _sender_sin_jugador_rechaza_ok \
		and _retiro_valido_descuenta_y_da_item_ok and _segundo_jugador_ve_el_mismo_total_ok
	print("PRUEBA ALMACEN LEÑADOR COMPARTIDO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
