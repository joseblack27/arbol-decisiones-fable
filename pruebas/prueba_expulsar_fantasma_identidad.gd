# =============================================================================
# Prueba de la regresión reportada en juego real: "una copia del jugador se
# crea al spawnear y todos los mobs lo atacan a el mientras yo puedo moverme
# libremente" — una reconexión rápida (confirmado: justo tras reiniciar el
# servidor) puede dejar dos Jugador vivos para la MISMA identidad (mismo
# id_unico) a la vez: uno viejo/fantasma que los mobs siguen atacando, y el
# nuevo que de verdad controla el jugador.
#
# Verifica la lógica de detección de Jugador._buscar_fantasma_de_la_misma_
# identidad() (llamada desde _registrar_identidad_red apenas se confirma la
# identidad real, ver ese archivo):
#   1. Dos Jugador con el MISMO id_unico y distinto peer_id_dueño -> se
#      detecta al otro como fantasma.
#   2. Dos Jugador con id_unico DISTINTO -> sin falso positivo, aunque estén
#      los dos en el grupo "jugadores".
#   3. Un solo Jugador en el grupo -> no se detecta a sí mismo.
#   godot --headless --path . --script res://pruebas/prueba_expulsar_fantasma_identidad.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _jugador_a
var _jugador_b

var _detecta_mismo_id_distinto_peer := false
var _no_falso_positivo_id_distinto := false
var _no_se_detecta_a_si_mismo := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas == 1:
		_montar()
	if _fotogramas == 3:
		_probar_solo()
	if _fotogramas == 5:
		_probar_mismo_id()
	if _fotogramas == 7:
		_probar_id_distinto()
	if _fotogramas == 9:
		return _informar()
	return false


func _montar() -> void:
	_jugador_a = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	_jugador_a.name = "100"
	root.add_child(_jugador_a)
	_jugador_a.id_unico = "cuenta-1"
	_jugador_a.peer_id_dueño = 100


func _probar_solo() -> void:
	var fantasma = _jugador_a.call("_buscar_fantasma_de_la_misma_identidad")
	_no_se_detecta_a_si_mismo = fantasma == null


func _probar_mismo_id() -> void:
	_jugador_b = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	_jugador_b.name = "200"
	root.add_child(_jugador_b)
	_jugador_b.id_unico = "cuenta-1"
	_jugador_b.peer_id_dueño = 200

	var fantasma = _jugador_b.call("_buscar_fantasma_de_la_misma_identidad")
	_detecta_mismo_id_distinto_peer = fantasma == _jugador_a


func _probar_id_distinto() -> void:
	_jugador_b.id_unico = "cuenta-2"
	var fantasma = _jugador_b.call("_buscar_fantasma_de_la_misma_identidad")
	_no_falso_positivo_id_distinto = fantasma == null


func _informar() -> bool:
	print("Detecta al fantasma (mismo id_unico, distinto peer) (esperado true): %s" % _detecta_mismo_id_distinto_peer)
	print("No se detecta a si mismo estando solo (esperado true): %s" % _no_se_detecta_a_si_mismo)
	print("Sin falso positivo con id_unico distinto (esperado true): %s" % _no_falso_positivo_id_distinto)
	var exito := _detecta_mismo_id_distinto_peer and _no_se_detecta_a_si_mismo and _no_falso_positivo_id_distinto
	print("PRUEBA EXPULSAR FANTASMA IDENTIDAD %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
