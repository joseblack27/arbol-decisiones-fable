# =============================================================================
# Prueba de InventarioComponente._pedir_experiencia_red — el camino de RED
# de los tickets de XP (usar_item -> _pedir_experiencia -> RPC al servidor)
# no tenía NINGUNA prueba (prueba_ticket_consumible_xp.gd solo ejercita el
# camino local sin red vía usar_item() directo). Bug real encontrado así:
# reportado por el usuario ("los tickets ya no suman a la xp... o no se
# reflejan") — la confirmación de vuelta al cliente (_recibir_xp_red) se
# movió de Jugador.gd a ComponenteConfirmacionesRed hace un tiempo, pero
# este call site había quedado apuntando a "jugador.rpc_id(...)" en vez de
# "confirmaciones.rpc_id(...)" — Jugador ya no tiene ese método, así que el
# servidor SÍ se sumaba la XP a sí mismo pero el cliente dueño nunca se
# enteraba. Mismo criterio de "sin transporte de red real" que
# prueba_tienda_comprar_item.gd: multiplayer.get_remote_sender_id() da 0
# cuando se llama _pedir_experiencia_red() directo (no vía RPC real).
#   godot --headless --path . --script res://pruebas/prueba_inventario_experiencia_red.gd
# =============================================================================
extends SceneTree

var _jugador
var _inventario
var _experiencia

var _sender_ajeno_rechaza_ok := false
var _sender_real_acredita_ok := false
var _confirmacion_apunta_al_componente_correcto_ok := false


func _process(_delta: float) -> bool:
	_montar()
	_probar_sender_ajeno()
	_probar_sender_real()
	_probar_confirmacion_apunta_al_componente_correcto()
	return _informar()


func _montar() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(0)
	root.multiplayer.multiplayer_peer = peer

	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(_jugador)
	_inventario = _jugador.get_node("InventarioComponente")
	_experiencia = _jugador.get_node("ExperienciaComponente")


func _probar_sender_ajeno() -> void:
	_jugador.peer_id_dueño = 999  # no coincide con get_remote_sender_id() (0).
	var xp_antes: int = _experiencia.xp_total
	_inventario._pedir_experiencia_red(100)
	_sender_ajeno_rechaza_ok = _experiencia.xp_total == xp_antes
	print("Sender que no es el dueño no acredita XP (esperado true): %s" % _sender_ajeno_rechaza_ok)


func _probar_sender_real() -> void:
	_jugador.peer_id_dueño = 0  # coincide con get_remote_sender_id() (0): dueño real.
	var xp_antes: int = _experiencia.xp_total
	_inventario._pedir_experiencia_red(100)
	_sender_real_acredita_ok = _experiencia.xp_total == xp_antes + 100
	print("Sender dueño real acredita 100 XP (esperado true): %s" % _sender_real_acredita_ok)


## El bug real no estaba en el gate anti-spoof (eso ya funcionaba) sino en
## A QUIÉN se le manda la confirmación de vuelta. Chequeo estructural
## directo: el método de confirmación tiene que vivir en
## ComponenteConfirmacionesRed (de ahí lo llama _pedir_experiencia_red),
## NO en Jugador — si algún día alguien vuelve a escribir
## "jugador.rpc_id(..., '_recibir_xp_red', ...)" en vez de
## "confirmaciones.rpc_id(...)", Jugador seguiría sin tener ese método.
func _probar_confirmacion_apunta_al_componente_correcto() -> void:
	var confirmaciones: Node = _jugador.get_node("ComponenteConfirmacionesRed")
	_confirmacion_apunta_al_componente_correcto_ok = confirmaciones.has_method("_recibir_xp_red") \
		and not _jugador.has_method("_recibir_xp_red")
	print("_recibir_xp_red vive en ComponenteConfirmacionesRed, no en Jugador (esperado true): %s" % _confirmacion_apunta_al_componente_correcto_ok)


func _informar() -> bool:
	var exito := _sender_ajeno_rechaza_ok and _sender_real_acredita_ok \
		and _confirmacion_apunta_al_componente_correcto_ok
	print("PRUEBA INVENTARIO EXPERIENCIA RED %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
