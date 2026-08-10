# =============================================================================
# Bug real reportado: "después de abandonar una misión y volverla a
# aceptar, no se deja aceptar de nuevo" — abandonar_mision() no pasaba por
# RPC (solo borraba la copia LOCAL de quien llamaba), así que en un
# cliente real el SERVIDOR (la copia autoritativa que aceptar_mision()
# valida) nunca se enteraba del abandono. Mismo molde que prueba_tienda_
# comprar_item.gd: server real sin transporte, _pedir_X_red() llamado
# directo, get_remote_sender_id()==0 simula "pedido del dueño real".
#   godot --headless --path . --script res://pruebas/prueba_misiones_abandonar_reaceptar.gd
# =============================================================================
extends SceneTree

var _jugador
var _misiones
var _datos_mision: DatosMision

var _aceptar_inicial_ok := false
var _sender_ajeno_no_abandona_ok := false
var _abandonar_borra_progreso_ok := false
var _reaceptar_tras_abandonar_ok := false


func _process(_delta: float) -> bool:
	_montar()
	_probar_aceptar_inicial()
	_probar_sender_ajeno_no_abandona()
	_probar_abandonar_borra_progreso()
	_probar_reaceptar_tras_abandonar()
	return _informar()


func _montar() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(0)
	root.multiplayer.multiplayer_peer = peer

	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(_jugador)
	_misiones = _jugador.get_node("MisionesComponente")
	_jugador.peer_id_dueño = 0  # coincide con get_remote_sender_id() (0): dueño real.

	_datos_mision = DatosMision.new()
	_datos_mision.id = "mision_abandonar_reaceptar"
	_datos_mision.objetivos = []
	_datos_mision.recompensas = DatosRecompensaMision.new()
	root.get_node("/root/GestorMisiones").catalogo.append(_datos_mision)


func _probar_aceptar_inicial() -> void:
	_misiones._pedir_aceptar_mision_red(_datos_mision.id)
	_aceptar_inicial_ok = _misiones.estado_de(_datos_mision.id) == Enums.Mision.Estado.EN_PROGRESO
	print("Aceptar inicial deja la misión EN_PROGRESO (esperado true): %s" % _aceptar_inicial_ok)


func _probar_sender_ajeno_no_abandona() -> void:
	_jugador.peer_id_dueño = 999  # no coincide con get_remote_sender_id() (0).
	_misiones._pedir_abandonar_mision_red(_datos_mision.id)
	_sender_ajeno_no_abandona_ok = _misiones.estado_de(_datos_mision.id) == Enums.Mision.Estado.EN_PROGRESO
	print("Sender que no es el dueño no abandona (esperado true, sigue EN_PROGRESO): %s" % _sender_ajeno_no_abandona_ok)
	_jugador.peer_id_dueño = 0  # devolver al dueño real para el resto de la prueba.


func _probar_abandonar_borra_progreso() -> void:
	_misiones._pedir_abandonar_mision_red(_datos_mision.id)
	_abandonar_borra_progreso_ok = _misiones.estado_de(_datos_mision.id) == Enums.Mision.Estado.BLOQUEADA
	print("Abandonar borra el progreso, vuelve a BLOQUEADA (esperado true): %s" % _abandonar_borra_progreso_ok)


## El bug real: sin _pedir_abandonar_mision_red, esto fallaba porque el
## servidor seguía teniendo la entrada vieja y _aceptar_mision_local() la
## rechazaba en silencio (progreso.has(id) daba true).
func _probar_reaceptar_tras_abandonar() -> void:
	_misiones._pedir_aceptar_mision_red(_datos_mision.id)
	_reaceptar_tras_abandonar_ok = _misiones.estado_de(_datos_mision.id) == Enums.Mision.Estado.EN_PROGRESO
	print("Volver a aceptar tras abandonar SÍ funciona (esperado true, antes fallaba en silencio): %s" % _reaceptar_tras_abandonar_ok)


func _informar() -> bool:
	var exito := _aceptar_inicial_ok and _sender_ajeno_no_abandona_ok \
		and _abandonar_borra_progreso_ok and _reaceptar_tras_abandonar_ok
	print("PRUEBA MISIONES ABANDONAR REACEPTAR %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
