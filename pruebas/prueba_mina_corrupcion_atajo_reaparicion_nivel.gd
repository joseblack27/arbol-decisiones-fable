# =============================================================================
# Prueba: NivelMina repone al Heraldo de la Corrupción en la MISMA ruta de
# nodo tras morir Y abre/cierra su PROPIA compuerta (CompuertaAtajoCorrupcion)
# — mirror exacto de prueba_mina_forja_atajo_reaparicion_nivel.gd, pero para
# el TERCER bloque jefe/compuerta agregado en la rama Corrupción.
#   godot --headless --path . --script res://pruebas/prueba_mina_corrupcion_atajo_reaparicion_nivel.gd
# =============================================================================
extends SceneTree

var _nivel: Node2D
var _jefe_original
var _compuerta
var _f := 0

var _conecto_la_muerte_ok := false
var _marca_muerto_ok := false
var _compuerta_cerrada_al_inicio_ok := false
var _compuerta_se_abre_al_morir_ok := false
var _respawnea_en_la_misma_ruta_ok := false
var _respawnea_en_la_misma_posicion_ok := false
var _jefe_muerto_vuelve_a_false_ok := false
var _es_instancia_nueva_ok := false
var _jefe_nuevo_muerte_conectada_ok := false
var _no_duplica_si_ya_esta_vivo_ok := false
var _compuerta_se_cierra_al_respawnear_ok := false


func _process(_delta: float) -> bool:
	_f += 1
	match _f:
		1:
			_montar()
			_probar_conexion()
		2:
			_matar_jefe()
		3:
			_verificar_compuerta_abierta()
			_pedir_respawn()
		4:
			return _probar_respawn_y_reconexion()
	return false


func _crear_nivel_falso() -> Node2D:
	var nivel := Node2D.new()
	nivel.set_script(load("res://escenas/niveles/NivelMina.gd"))
	var enemigos := Node2D.new()
	enemigos.name = "Enemigos"
	nivel.add_child(enemigos)
	var jefe := (load("res://escenas/enemigos/EnemigoHeraldoCorrupcion.tscn") as PackedScene).instantiate()
	enemigos.add_child(jefe)

	var decoraciones := Node2D.new()
	decoraciones.name = "Decoraciones"
	nivel.add_child(decoraciones)
	var compuerta := (load("res://escenas/objetos/CompuertaAtajoMina.tscn") as PackedScene).instantiate()
	compuerta.name = "CompuertaAtajoCorrupcion"
	decoraciones.add_child(compuerta)

	return nivel


func _montar() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(34601)
	root.multiplayer.multiplayer_peer = peer

	_nivel = _crear_nivel_falso()
	root.add_child(_nivel)
	current_scene = _nivel
	_jefe_original = _nivel.get_node(_nivel._RUTA_JEFE_CORRUPCION)
	_jefe_original.global_position = Vector2(963, 741)
	_nivel._posicion_jefe_corrupcion = _jefe_original.global_position
	_compuerta = _nivel.get_node(_nivel._RUTA_COMPUERTA_CORRUPCION)


func _probar_conexion() -> void:
	_conecto_la_muerte_ok = _jefe_original.componente_vida.muerte.is_connected(_nivel._al_morir_jefe_corrupcion)
	print("El nivel escucha la muerte real del jefe de corrupción (esperado true): %s" % _conecto_la_muerte_ok)

	_compuerta_cerrada_al_inicio_ok = not _compuerta.abierta
	print("La compuerta de corrupción arranca cerrada (esperado true): %s" % _compuerta_cerrada_al_inicio_ok)


func _matar_jefe() -> void:
	_nivel.call("_al_morir_jefe_corrupcion", 0.0)
	_marca_muerto_ok = _nivel._jefe_corrupcion_muerto
	print("_jefe_corrupcion_muerto pasa a true al morir (esperado true): %s" % _marca_muerto_ok)

	_jefe_original.queue_free()


func _verificar_compuerta_abierta() -> void:
	_compuerta_se_abre_al_morir_ok = _compuerta.abierta and _compuerta.get_node("CollisionShape2D").disabled
	print("La compuerta de corrupción se abre al morir el jefe (esperado true): %s" % _compuerta_se_abre_al_morir_ok)


func _pedir_respawn() -> void:
	_nivel.call("_respawnear_jefe_corrupcion")


func _probar_respawn_y_reconexion() -> bool:
	var jefe_nuevo = _nivel.get_node_or_null(_nivel._RUTA_JEFE_CORRUPCION)
	_respawnea_en_la_misma_ruta_ok = jefe_nuevo != null
	print("Hay un jefe de nuevo en la ruta de siempre (esperado true): %s" % _respawnea_en_la_misma_ruta_ok)

	_es_instancia_nueva_ok = jefe_nuevo != null and jefe_nuevo != _jefe_original
	print("Es una instancia NUEVA, no la vieja reciclada (esperado true): %s" % _es_instancia_nueva_ok)

	_respawnea_en_la_misma_posicion_ok = jefe_nuevo != null \
		and jefe_nuevo.global_position.is_equal_approx(Vector2(963, 741))
	print("Aparece en la misma posición que el original (esperado true): %s" % \
		_respawnea_en_la_misma_posicion_ok)

	_jefe_muerto_vuelve_a_false_ok = not _nivel._jefe_corrupcion_muerto
	print("_jefe_corrupcion_muerto vuelve a false tras el respawn (esperado true): %s" % _jefe_muerto_vuelve_a_false_ok)

	_jefe_nuevo_muerte_conectada_ok = jefe_nuevo != null \
		and jefe_nuevo.componente_vida.muerte.is_connected(_nivel._al_morir_jefe_corrupcion)
	print("La muerte del jefe NUEVO también queda escuchada (esperado true): %s" % \
		_jefe_nuevo_muerte_conectada_ok)

	_compuerta_se_cierra_al_respawnear_ok = not _compuerta.abierta \
		and not _compuerta.get_node("CollisionShape2D").disabled
	print("La compuerta de corrupción se vuelve a cerrar al reponer al jefe (esperado true): %s" % \
		_compuerta_se_cierra_al_respawnear_ok)

	_nivel.call("_al_peer_listo", 2)
	var jefe_tras_segundo_peer = _nivel.get_node_or_null(_nivel._RUTA_JEFE_CORRUPCION)
	_no_duplica_si_ya_esta_vivo_ok = jefe_tras_segundo_peer == jefe_nuevo
	print("Un segundo peer con el jefe ya vivo no lo reemplaza de nuevo (esperado true): %s" % \
		_no_duplica_si_ya_esta_vivo_ok)

	return _informar()


func _informar() -> bool:
	var exito := _conecto_la_muerte_ok and _marca_muerto_ok \
		and _compuerta_cerrada_al_inicio_ok and _compuerta_se_abre_al_morir_ok \
		and _respawnea_en_la_misma_ruta_ok and _es_instancia_nueva_ok \
		and _respawnea_en_la_misma_posicion_ok and _jefe_muerto_vuelve_a_false_ok \
		and _jefe_nuevo_muerte_conectada_ok and _no_duplica_si_ya_esta_vivo_ok \
		and _compuerta_se_cierra_al_respawnear_ok
	print("PRUEBA MINA CORRUPCION ATAJO REAPARICION NIVEL %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
