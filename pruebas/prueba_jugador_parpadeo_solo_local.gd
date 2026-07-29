# =============================================================================
# Prueba de que Jugador solo parpadea al recibir daño en la pantalla de su
# propio dueño — no en la de otros jugadores que lo tengan replicado en
# pantalla (pedido del usuario). Mismo truco que la prueba del enemigo:
# un ENetMultiplayerPeer real creado como servidor (create_server), sin
# conectar ningún cliente de verdad, alcanza para que Utils.en_red() dé
# true y multiplayer.get_unique_id() sea determinístico.
#   godot --headless --path . --script res://pruebas/prueba_jugador_parpadeo_solo_local.gd
# =============================================================================
extends SceneTree

var _jugador
var _fotogramas := 0

var _sin_red_parpadea := false
var _en_red_dueño_parpadea := false
var _en_red_ajeno_no_parpadea := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			_probar_sin_red()
		3:
			_probar_en_red_dueño()
		4:
			_probar_en_red_ajeno()
		5:
			return _informar()
	return false


func _montar() -> void:
	var escena := load("res://escenas/jugador/Jugador.tscn") as PackedScene
	_jugador = escena.instantiate()
	root.add_child(_jugador)


## parpadear() anima con un Tween — recién arranca a interpolar modulate en
## el PRÓXIMO fotograma, así que leer modulate en el mismo tick en que se
## llama _on_vida_cambiada() siempre da blanco, haya parpadeado o no (bug
## real de una primera versión de esta prueba). En cambio, si arrancó un
## tween de verdad, _tween_parpadeo queda válido/corriendo YA, en el mismo
## tick — eso sí se puede leer sin esperar un fotograma.
func _se_disparo_el_parpadeo() -> bool:
	return _jugador._tween_parpadeo != null and _jugador._tween_parpadeo.is_valid() \
		and _jugador._tween_parpadeo.is_running()


## Limpia el tween de la corrida anterior ANTES de cada sub-prueba: si no,
## un tween previo (que dura 0.2s = varios fotogramas) sigue "corriendo"
## cuando se chequea la siguiente sub-prueba, aunque ESA llamada puntual no
## haya disparado nada — _se_disparo_el_parpadeo() daría un falso positivo.
func _limpiar_tween_previo() -> void:
	if _jugador._tween_parpadeo and _jugador._tween_parpadeo.is_valid():
		_jugador._tween_parpadeo.kill()
	_jugador._tween_parpadeo = null


func _probar_sin_red() -> void:
	_limpiar_tween_previo()
	_jugador._vida_anterior = 100.0
	_jugador._on_vida_cambiada(50.0)
	_sin_red_parpadea = _se_disparo_el_parpadeo()


func _probar_en_red_dueño() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(0)
	root.multiplayer.multiplayer_peer = peer
	_jugador.peer_id_dueño = root.multiplayer.get_unique_id()

	_limpiar_tween_previo()
	_jugador._vida_anterior = 100.0
	_jugador._on_vida_cambiada(50.0)
	_en_red_dueño_parpadea = _se_disparo_el_parpadeo()


func _probar_en_red_ajeno() -> void:
	_jugador.peer_id_dueño = root.multiplayer.get_unique_id() + 999

	_limpiar_tween_previo()
	_jugador._vida_anterior = 100.0
	_jugador._on_vida_cambiada(50.0)
	_en_red_ajeno_no_parpadea = not _se_disparo_el_parpadeo()

	root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func _informar() -> bool:
	print("Sin red, cualquier daño propio parpadea: %s" % _sin_red_parpadea)
	print("En red, siendo el dueño local, parpadea: %s" % _en_red_dueño_parpadea)
	print("En red, siendo la réplica de OTRO jugador, NO parpadea: %s" % _en_red_ajeno_no_parpadea)

	var exito := _sin_red_parpadea and _en_red_dueño_parpadea and _en_red_ajeno_no_parpadea
	print("PRUEBA JUGADOR PARPADEO SOLO LOCAL %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
