# =============================================================================
# Historia de este archivo (los dos bugs que ya cubrió, y el pedido actual):
#
# 1. "cuando mato a la reina araña, salgo de la cueva y vuelvo a entrar, la
#    reina araña aparece bugueada, no se mueve, no ataca y no recibe daño" —
#    causa: el CLIENTE reinstancia la escena entera al (re)cargar un nivel
#    (ver GestorNiveles._cargar), y como la reina está horneada en el .tscn,
#    resucitaba una copia LOCAL sin servidor real detrás.
#
# 2. El primer arreglo ocultaba esa copia fantasma reusando Enemigo.
#    _despawn_red() (el desvanecido de "murió peleando") — pero acá nunca
#    hubo pelea: se leía como "vuelvo a entrar y se muere sola,
#    instantáneamente" (reportado después).
#
# 3. Pedido actual del usuario ("como aun son pruebas, quiero que respawnee
#    cada vez que entre a la cueva"): en vez de ocultar la copia fantasma
#    para siempre, el servidor ahora le REPONE una reina fresca, en la MISMA
#    ruta (Enemigos/EnemigoArañaReina), al primer peer que confirme haber
#    cargado el nivel tras su muerte. Con una reina real de nuevo en esa
#    ruta, la sincronización genérica de Enemigo.gd (por ruta de nodo, no
#    por MultiplayerSpawner) vuelve a andar sola — ver el comentario de
#    NivelNidoArañaReina.gd para el porqué completo.
#
# 4. "Aparece en la misma posición que la original" salía intermitente
#    (~1 de cada 2-3 corridas): la verificación vivía en el fotograma
#    SIGUIENTE al del respawn, y en ese único fotograma físico de por medio
#    la reina recién nacida ya tiene IA activa — su deambular (con pausa
#    corta, ver AccionDeambular) a veces alcanza a correrla unos px antes
#    de que is_equal_approx() la comparara. _respawnear_reina() ya deja
#    todo resuelto en forma síncrona (posición, árbol, señales) apenas
#    vuelve, así que no hacía falta ESPERAR nada — se verifica en el MISMO
#    fotograma en vez de en el siguiente, y la carrera desaparece.
#
# No arma una red real de 2 peers conectados (mismo motivo que
# prueba_arana_reina_invocacion_solo_servidor.gd: lento/flaky) — alcanza con
# un ENetMultiplayerPeer en modo SERVIDOR (sin que nadie se conecte) para que
# Utils.en_red()==true y multiplayer.is_server()==true, lo necesario para que
# NivelNidoArañaReina._ready() arme la escucha de la muerte real.
#   godot --headless --path . --script res://pruebas/prueba_arana_reina_reaparicion_nivel.gd
# =============================================================================
extends SceneTree

var _nivel: Node2D
var _reina_original
var _f := 0

var _conecto_la_muerte_ok := false
var _marca_muerta_ok := false
var _respawnea_en_la_misma_ruta_ok := false
var _respawnea_en_la_misma_posicion_ok := false
var _reina_muerta_vuelve_a_false_ok := false
var _es_instancia_nueva_ok := false
var _reina_nueva_muerte_conectada_ok := false
var _no_duplica_si_ya_esta_viva_ok := false


func _process(_delta: float) -> bool:
	_f += 1
	match _f:
		1:
			_montar()
			_probar_conexion()
		2:
			_matar_reina_y_pedir_respawn()
			# Mismo fotograma, no el siguiente — ver punto 4 del historial
			# arriba: esperar un fotograma le daba tiempo a la IA de la
			# reina nueva de moverla antes de este chequeo.
			return _probar_respawn_y_reconexion()
	return false


func _crear_nivel_falso() -> Node2D:
	var nivel := Node2D.new()
	nivel.set_script(load("res://escenas/niveles/NivelNidoArañaReina.gd"))
	var enemigos := Node2D.new()
	enemigos.name = "Enemigos"
	nivel.add_child(enemigos)
	var reina := (load("res://escenas/enemigos/EnemigoArañaReina.tscn") as PackedScene).instantiate()
	enemigos.add_child(reina)
	return nivel


func _montar() -> void:
	# Simula ser el SERVIDOR (nadie tiene que conectarse de verdad — mismo
	# criterio que prueba_arana_reina_invocacion_solo_servidor.gd, pero en
	# modo servidor en vez de cliente): NivelNidoArañaReina._ready() solo
	# arma la escucha de la muerte con Utils.en_red() y multiplayer.
	# is_server() los dos en true.
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(34599)
	root.multiplayer.multiplayer_peer = peer

	_nivel = _crear_nivel_falso()
	root.add_child(_nivel)
	current_scene = _nivel
	_reina_original = _nivel.get_node(_nivel._RUTA_REINA)
	_reina_original.global_position = Vector2(123, 456)
	# _ready() ya corrió al hacer add_child() — _posicion_reina se capturó
	# ANTES de este reposicionamiento manual, así que se la fuerza de nuevo
	# a mano para que la prueba de "misma posición" de abajo sea exacta.
	_nivel._posicion_reina = _reina_original.global_position


func _probar_conexion() -> void:
	_conecto_la_muerte_ok = _reina_original.componente_vida.muerte.is_connected(_nivel._al_morir_reina)
	print("El nivel escucha la muerte real de la reina (esperado true): %s" % _conecto_la_muerte_ok)


func _matar_reina_y_pedir_respawn() -> void:
	_nivel.call("_al_morir_reina", 0.0)
	_marca_muerta_ok = _nivel._reina_muerta
	print("_reina_muerta pasa a true al morir (esperado true): %s" % _marca_muerta_ok)

	# _al_morir_reina() no libera el nodo (eso lo hace el desvanecido real
	# de 0.8s, Enemigo._desvanecer_y_eliminar) — se la deja en cola para
	# simular que la muerte real ya casi terminó de resolverse cuando el
	# respawn intenta correr (el caso que _respawnear_reina() cubre a
	# propósito con su chequeo de "vieja").
	_reina_original.queue_free()

	# _respawnear_reina() directo, no _al_peer_listo(): ese último también
	# consulta GestorNiveles.nivel_de_peer(), que no conoce a este nivel de
	# prueba sintético (mismo motivo por el que otras pruebas de este mismo
	# archivo, ver prueba_arana_reina_invocacion_solo_servidor.gd, llaman a
	# la lógica real directo en vez de simular la red de punta a punta).
	_nivel.call("_respawnear_reina")


func _probar_respawn_y_reconexion() -> bool:
	var reina_nueva = _nivel.get_node_or_null(_nivel._RUTA_REINA)
	_respawnea_en_la_misma_ruta_ok = reina_nueva != null
	print("Hay una reina de nuevo en la ruta de siempre (esperado true): %s" % _respawnea_en_la_misma_ruta_ok)

	_es_instancia_nueva_ok = reina_nueva != null and reina_nueva != _reina_original
	print("Es una instancia NUEVA, no la vieja reciclada (esperado true): %s" % _es_instancia_nueva_ok)

	_respawnea_en_la_misma_posicion_ok = reina_nueva != null \
		and reina_nueva.global_position.is_equal_approx(Vector2(123, 456))
	print("Aparece en la misma posición que la original (esperado true): %s" % \
		_respawnea_en_la_misma_posicion_ok)

	_reina_muerta_vuelve_a_false_ok = not _nivel._reina_muerta
	print("_reina_muerta vuelve a false tras el respawn (esperado true): %s" % _reina_muerta_vuelve_a_false_ok)

	_reina_nueva_muerte_conectada_ok = reina_nueva != null \
		and reina_nueva.componente_vida.muerte.is_connected(_nivel._al_morir_reina)
	print("La muerte de la reina NUEVA también queda escuchada (esperado true): %s" % \
		_reina_nueva_muerte_conectada_ok)

	# Un segundo peer que "llega" con la reina YA viva no debe tocar nada.
	_nivel.call("_al_peer_listo", 2)
	var reina_tras_segundo_peer = _nivel.get_node_or_null(_nivel._RUTA_REINA)
	_no_duplica_si_ya_esta_viva_ok = reina_tras_segundo_peer == reina_nueva
	print("Un segundo peer con la reina ya viva no la reemplaza de nuevo (esperado true): %s" % \
		_no_duplica_si_ya_esta_viva_ok)

	return _informar()


func _informar() -> bool:
	var exito := _conecto_la_muerte_ok and _marca_muerta_ok and _respawnea_en_la_misma_ruta_ok \
		and _es_instancia_nueva_ok and _respawnea_en_la_misma_posicion_ok \
		and _reina_muerta_vuelve_a_false_ok and _reina_nueva_muerte_conectada_ok \
		and _no_duplica_si_ya_esta_viva_ok
	print("PRUEBA ARAÑA REINA REAPARICION NIVEL %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
