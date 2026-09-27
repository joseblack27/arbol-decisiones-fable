# =============================================================================
# Movimiento del jugador en red como ESTADO de input con secuencia (27 sep
# 2026, punto 2 del refactor de red). Reemplaza a "moverme" (unreliable) +
# "parate" (reliable) por canales distintos, donde un "moverme" viejo podía
# llegar después del "parate" y dejar al cuerpo del servidor caminando solo
# para siempre ("el personaje se sigue moviendo con la animación de idle").
#
# Servidor (RPCs llamados directo; peer_id_dueño=0 porque sin transporte
# real get_remote_sender_id() da 0 — mismo criterio que otras pruebas):
#   1. Un input nuevo mueve el cuerpo.
#   2. Un input VIEJO que llega tarde (secuencia menor) se descarta: el bug
#      original, ahora imposible.
#   3. Un salto grande hacia atrás se acepta (el cliente reinició su contador).
#   4. Bloqueado (bloquear_control) no se mueve; al desbloquear retoma lo que
#      el cliente pide AHORA.
#   5. Lo mismo con el congelamiento de disparo.
#   6. Sin input por más de medio segundo, se frena solo.
#   7. Una dirección más larga que 1 se recorta (no se puede correr más rápido).
# Cliente:
#   8. Manda al instante al arrancar/frenar y si no cada _FOTOGRAMAS_REENVIO_INPUT.
#   godot --headless --path . --script res://pruebas/prueba_jugador_input_red.gd
# =============================================================================
extends SceneTree

var _jugador
var _resultados: Dictionary = {}


func _process(_delta: float) -> bool:
	_probar_servidor()
	_probar_cliente()
	return _informar()


func _probar_servidor() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(0)  # puerto 0 = el SO elige uno libre; no hace falta que nadie se conecte.
	root.multiplayer.multiplayer_peer = peer
	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	_jugador.name = "0"
	_jugador.peer_id_dueño = 0
	root.add_child(_jugador)

	_input(1, Vector2.RIGHT)
	_anotar("1. un input nuevo mueve el cuerpo", _jugador.direccion == Vector2.RIGHT)

	_input(3, Vector2.ZERO)
	_input(2, Vector2.RIGHT)
	_anotar("2. un input viejo que llega tarde se descarta", _jugador.direccion == Vector2.ZERO)

	_jugador._ultima_secuencia_input_recibida = 5000
	_input(1, Vector2.LEFT)
	_anotar("3. un salto grande hacia atrás se acepta como reinicio", _jugador.direccion == Vector2.LEFT)

	_jugador.bloquear_control()
	_input(2, Vector2.LEFT)
	var quieto_bloqueado: bool = _jugador.direccion == Vector2.ZERO
	_input(3, Vector2.UP)
	_jugador.desbloquear_control()
	_input(4, Vector2.UP)
	_anotar("4. bloqueado no se mueve y al desbloquear retoma lo pedido ahora",
		quieto_bloqueado and _jugador.direccion == Vector2.UP)

	_jugador.congelar_disparo_pendiente()
	_input(5, Vector2.UP)
	var quieto_congelado: bool = _jugador.direccion == Vector2.ZERO
	_jugador.descongelar_disparo_pendiente()
	_input(6, Vector2.UP)
	_anotar("5. congelado por disparo no se mueve y después retoma",
		quieto_congelado and _jugador.direccion == Vector2.UP)

	_jugador._aplicar_input_servidor(0.6)
	_anotar("6. sin input por más de medio segundo se frena solo", _jugador.direccion == Vector2.ZERO)

	_input(7, Vector2(5.0, 0.0))
	_anotar("7. una dirección más larga que 1 se recorta", _jugador.direccion.length() <= 1.0001)

	_jugador.queue_free()


func _input(secuencia: int, direccion: Vector2) -> void:
	_jugador._recibir_input_red(secuencia, direccion)
	_jugador._aplicar_input_servidor(0.016)


func _probar_cliente() -> void:
	# Cliente sin conectar: los rpc_id fallan con un error de consola, pero
	# acá solo importa cuándo decide mandar (cuenta de secuencia).
	var peer := ENetMultiplayerPeer.new()
	peer.create_client("127.0.0.1", 34603)
	root.multiplayer.multiplayer_peer = peer
	var jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(jugador)
	jugador.set_physics_process(false)

	jugador.direccion = Vector2.ZERO
	jugador._enviar_input_red()
	var tras_primero: int = jugador._secuencia_input
	for _i in 2:
		jugador._enviar_input_red()
	var sin_cambios_no_manda: bool = jugador._secuencia_input == tras_primero
	jugador._enviar_input_red()
	jugador._enviar_input_red()
	var reenvio_periodico: bool = jugador._secuencia_input == tras_primero + 1
	var antes_de_arrancar: int = jugador._secuencia_input
	jugador.direccion = Vector2.RIGHT
	jugador._enviar_input_red()
	var arrancar_manda_ya: bool = jugador._secuencia_input == antes_de_arrancar + 1
	_anotar("8. manda al instante al arrancar y si no cada %d fotogramas" % jugador._FOTOGRAMAS_REENVIO_INPUT,
		tras_primero == 1 and sin_cambios_no_manda and reenvio_periodico and arrancar_manda_ya)

	root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func _anotar(nombre: String, ok: bool) -> void:
	_resultados[nombre] = ok
	print("%s (esperado true): %s" % [nombre, ok])


func _informar() -> bool:
	var exito := _resultados.size() == 8
	if not exito:
		print("Faltan chequeos: se esperaban 8, llegaron %d (revisar SCRIPT ERROR arriba)" % _resultados.size())
	for ok in _resultados.values():
		exito = exito and ok
	print("PRUEBA JUGADOR INPUT RED %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
