# =============================================================================
# Regresión (bug real reportado 18 sep 2026, "se me borró el pj"): al
# conectar, Mundo._esperar_jugador_propio() equipa el golpe_basico por
# defecto ANTES de pedir la partida real -- ese equipar() dispara el
# guardado por evento de GestorGuardado (2s de antirrebote) sin saber
# todavía si hay una partida real por aplicar. Si esa carrera la ganaba el
# antirrebote (red lenta, servidor ocupado), guardar_partida() mandaba al
# servidor el estado en blanco del cliente recién conectado, PISANDO el
# progreso real. Confirmado en producción: la fila en SQLite seguía viva
# (cuenta de días antes) pero datos_json era el de un personaje sin
# estrenar, guardado justo al conectar.
#
# Como CLIENTE (no servidor) en red -- mismo truco que prueba_arana_reina_
# invocacion_solo_servidor.gd: un ENetMultiplayerPeer en modo CLIENTE sin
# conectar alcanza para que Utils.en_red()==true y multiplayer.is_server()
# ==false, sin necesitar una red real de 2 peers (lento/flaky).
#   godot --headless --path . --script res://pruebas/prueba_guardado_no_pisa_partida_durante_carga.gd
# =============================================================================
extends SceneTree

var _gestor
var _jugador
var _guardo_mientras_esperaba := false
var _guardo_tras_recibir := false


func _process(_delta: float) -> bool:
	_montar()
	_probar_bloquea_durante_espera()
	_probar_destraba_tras_recibir()
	return _informar()


func _montar() -> void:
	_gestor = root.get_node("/root/GestorGuardado")

	var peer := ENetMultiplayerPeer.new()
	peer.create_client("127.0.0.1", 34599)  # puerto sin nadie escuchando: no hace falta conectar de verdad.
	root.multiplayer.multiplayer_peer = peer

	# Jugador._ready() deriva peer_id_dueño del NOMBRE del nodo (ver ese
	# comentario) -- asignar la propiedad a mano no alcanza, hay que
	# nombrarlo con el unique_id como string ANTES de add_child().
	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	_jugador.name = str(root.multiplayer.get_unique_id())
	_jugador.add_to_group("jugadores")
	root.add_child(_jugador)


func _probar_bloquea_durante_espera() -> void:
	_gestor.call("cargar_partida")
	var esperando: bool = _gestor.get("_esperando_carga_inicial")
	print("cargar_partida() deja _esperando_carga_inicial en true (esperado true): %s" % esperando)

	var funcion := func(): _guardo_mientras_esperaba = true
	_gestor.partida_guardada.connect(funcion)
	_gestor.call("guardar_partida")
	_gestor.partida_guardada.disconnect(funcion)
	print("guardar_partida() mientras se espera la carga NO manda nada (esperado false): %s" % _guardo_mientras_esperaba)


func _probar_destraba_tras_recibir() -> void:
	_gestor.call("_recibir_partida_red", JSON.stringify({}))
	var esperando: bool = _gestor.get("_esperando_carga_inicial")
	print("_recibir_partida_red destraba _esperando_carga_inicial (esperado false): %s" % esperando)

	var funcion := func(): _guardo_tras_recibir = true
	_gestor.partida_guardada.connect(funcion)
	_gestor.call("guardar_partida")
	_gestor.partida_guardada.disconnect(funcion)
	print("guardar_partida() después de recibir la carga SÍ manda (esperado true): %s" % _guardo_tras_recibir)


func _informar() -> bool:
	var exito := not _guardo_mientras_esperaba and _guardo_tras_recibir
	print("PRUEBA GUARDADO NO PISA PARTIDA DURANTE CARGA %s" % ("OK" if exito else "FALLIDA"))
	root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	quit(0 if exito else 1)
	return true
