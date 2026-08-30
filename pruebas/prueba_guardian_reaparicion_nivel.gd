# =============================================================================
# Prueba: NivelSantuarioGuardian repone al Guardián Quebrado en la MISMA
# ruta de nodo tras morir (mismo mecanismo, mismo motivo y misma prueba que
# prueba_arana_reina_reaparicion_nivel.gd — ver ese archivo para el
# historial completo de por qué existe este patrón). Usa un nivel SINTÉTICO
# (script + contenedor "Enemigos" + jefe), no el .tscn real completo con
# terreno: más rápido y evita depender del tilemap/navegación para esto.
#
# Simula ser el SERVIDOR con un ENetMultiplayerPeer sin que nadie se
# conecte (mismo criterio que la prueba de la reina): NivelSantuarioGuardian
# ._ready() solo arma la escucha de la muerte con Utils.en_red() y
# multiplayer.is_server() los dos en true.
#   godot --headless --path . --script res://pruebas/prueba_guardian_reaparicion_nivel.gd
# =============================================================================
extends SceneTree

var _nivel: Node2D
var _jefe_original
var _f := 0

var _conecto_la_muerte_ok := false
var _marca_muerto_ok := false
var _respawnea_en_la_misma_ruta_ok := false
var _respawnea_en_la_misma_posicion_ok := false
var _jefe_muerto_vuelve_a_false_ok := false
var _es_instancia_nueva_ok := false
var _jefe_nuevo_muerte_conectada_ok := false
var _no_duplica_si_ya_esta_vivo_ok := false


func _process(_delta: float) -> bool:
	_f += 1
	match _f:
		1:
			_montar()
			_probar_conexion()
		2:
			_matar_jefe_y_pedir_respawn()
			# Mismo fotograma, no el siguiente — la reposición ya deja todo
			# resuelto en forma síncrona (ver _respawnear_jefe), no hace
			# falta esperar (mismo criterio que la prueba de la reina, punto
			# 4 de su historial: esperar un fotograma le daba tiempo a la IA
			# del jefe nuevo de moverlo antes del chequeo de posición).
			return _probar_respawn_y_reconexion()
	return false


func _crear_nivel_falso() -> Node2D:
	var nivel := Node2D.new()
	nivel.set_script(load("res://escenas/niveles/NivelSantuarioGuardian.gd"))
	var enemigos := Node2D.new()
	enemigos.name = "Enemigos"
	nivel.add_child(enemigos)
	var jefe := (load("res://escenas/enemigos/EnemigoGuardianQuebrado.tscn") as PackedScene).instantiate()
	enemigos.add_child(jefe)
	return nivel


func _montar() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(34598)
	root.multiplayer.multiplayer_peer = peer

	_nivel = _crear_nivel_falso()
	root.add_child(_nivel)
	current_scene = _nivel
	_jefe_original = _nivel.get_node(_nivel._RUTA_JEFE)
	_jefe_original.global_position = Vector2(321, 654)
	# _ready() ya corrió al hacer add_child() — _posicion_jefe se capturó
	# ANTES de este reposicionamiento manual, así que se la fuerza de nuevo
	# a mano para que la prueba de "misma posición" de abajo sea exacta.
	_nivel._posicion_jefe = _jefe_original.global_position


func _probar_conexion() -> void:
	_conecto_la_muerte_ok = _jefe_original.componente_vida.muerte.is_connected(_nivel._al_morir_jefe)
	print("El nivel escucha la muerte real del jefe (esperado true): %s" % _conecto_la_muerte_ok)


func _matar_jefe_y_pedir_respawn() -> void:
	_nivel.call("_al_morir_jefe", 0.0)
	_marca_muerto_ok = _nivel._jefe_muerto
	print("_jefe_muerto pasa a true al morir (esperado true): %s" % _marca_muerto_ok)

	# No libera el nodo de inmediato (eso lo hace el desvanecido real de la
	# muerte) — se lo deja en cola para simular que la muerte real ya casi
	# terminó de resolverse cuando el respawn intenta correr (el caso que
	# _respawnear_jefe() cubre a propósito con su chequeo de "viejo").
	_jefe_original.queue_free()

	_nivel.call("_respawnear_jefe")


func _probar_respawn_y_reconexion() -> bool:
	var jefe_nuevo = _nivel.get_node_or_null(_nivel._RUTA_JEFE)
	_respawnea_en_la_misma_ruta_ok = jefe_nuevo != null
	print("Hay un jefe de nuevo en la ruta de siempre (esperado true): %s" % _respawnea_en_la_misma_ruta_ok)

	_es_instancia_nueva_ok = jefe_nuevo != null and jefe_nuevo != _jefe_original
	print("Es una instancia NUEVA, no la vieja reciclada (esperado true): %s" % _es_instancia_nueva_ok)

	_respawnea_en_la_misma_posicion_ok = jefe_nuevo != null \
		and jefe_nuevo.global_position.is_equal_approx(Vector2(321, 654))
	print("Aparece en la misma posición que el original (esperado true): %s" % \
		_respawnea_en_la_misma_posicion_ok)

	_jefe_muerto_vuelve_a_false_ok = not _nivel._jefe_muerto
	print("_jefe_muerto vuelve a false tras el respawn (esperado true): %s" % _jefe_muerto_vuelve_a_false_ok)

	_jefe_nuevo_muerte_conectada_ok = jefe_nuevo != null \
		and jefe_nuevo.componente_vida.muerte.is_connected(_nivel._al_morir_jefe)
	print("La muerte del jefe NUEVO también queda escuchada (esperado true): %s" % \
		_jefe_nuevo_muerte_conectada_ok)

	# Un segundo peer que "llega" con el jefe YA vivo no debe tocar nada.
	_nivel.call("_al_peer_listo", 2)
	var jefe_tras_segundo_peer = _nivel.get_node_or_null(_nivel._RUTA_JEFE)
	_no_duplica_si_ya_esta_vivo_ok = jefe_tras_segundo_peer == jefe_nuevo
	print("Un segundo peer con el jefe ya vivo no lo reemplaza de nuevo (esperado true): %s" % \
		_no_duplica_si_ya_esta_vivo_ok)

	return _informar()


func _informar() -> bool:
	var exito := _conecto_la_muerte_ok and _marca_muerto_ok and _respawnea_en_la_misma_ruta_ok \
		and _es_instancia_nueva_ok and _respawnea_en_la_misma_posicion_ok \
		and _jefe_muerto_vuelve_a_false_ok and _jefe_nuevo_muerte_conectada_ok \
		and _no_duplica_si_ya_esta_vivo_ok
	print("PRUEBA GUARDIAN REAPARICION NIVEL %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
