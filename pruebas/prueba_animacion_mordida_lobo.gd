# =============================================================================
# Prueba de la animación de mordida (embestida) del Lobo/Lobo Feroz:
#   El árbol de animación ya tenía IDLE -> MORDIDA_PREPARACION -> MORDIDA_
#   DASH -> IDLE armado, pero EnemigoLobo.gd nunca disparaba esas 3
#   condiciones (escribía "debeCargar", que no existe en ese árbol) — la
#   embestida se veía con caminar/idle en vez de su propia animación.
#   Verifica que las 3 fases de HabilidadCarga (preparación -> dash ->
#   terminada) muevan las condiciones correctas del AnimationTree, para
#   ambos mobs que comparten este árbol.
#
#   OJO con esta prueba en particular: chequear solo las condiciones
#   booleanas (como hacía la versión vieja) NO alcanza — establecer_
#   condicion() las deja puestas igual aunque el grafo no tenga arista de
#   salida desde el estado actual (el bug real: el mob se queda pegado en
#   CAMINAR con debeMordidaPrep=true sin viajar nunca a MORDIDA_
#   PREPARACION). Por eso acá también se lee playback.get_current_node()
#   — y arrancando la prueba a propósito desde CAMINAR (no desde el IDLE
#   por defecto), que es el caso común que de verdad rompía (ver
#   EnemigoLobo._on_carga_preparacion). Además, animation_tree.active
#   queda en false en headless (ver AnimacionComponente._ready) — sin
#   forzarlo a true acá, get_current_node() nunca se actualizaría y la
#   prueba no distinguiría el fix real de un falso positivo.
#   godot --headless --path . --script res://pruebas/prueba_animacion_mordida_lobo.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
# Frames transcurridos desde activar() — separado de _fotogramas para que
# el setup previo (forzar CAMINAR) no desalinee los checkpoints, como pasó
# en un intento anterior de esta misma prueba.
var _fotogramas_desde_activar := -1
var _mob
var _habilidad_carga
var _tree: AnimationTree
var _playback: AnimationNodeStateMachinePlayback
var _prep_ok := false
var _prep_estado_ok := false
var _dash_ok := false
var _dash_estado_ok := false
var _fin_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas_desde_activar >= 0:
		_fotogramas_desde_activar += 1

	if _fotogramas == 1:
		_montar("res://escenas/enemigos/EnemigoLobo.tscn")
	# Establece el punto de partida real del bug: caminando, no en reposo.
	# Con margen (no en el mismo frame que active=true) porque forzar un
	# travel() antes de que el árbol procese ni un fotograma activo tiró
	# "looped transitions... aborted" en un intento previo de esta prueba.
	elif _fotogramas == 2:
		_tree.active = true
	elif _fotogramas == 5:
		# Apagar el árbol de comportamiento ANTES de comandar movimiento a
		# mano: si no, su propio tick (10/s) compite por el control del
		# cuerpo y pisa el comando de esta prueba (mismo mecanismo que usa
		# Enemigo._on_muerte para apagarlo: "arbol.activo = false").
		var arbol = _mob.get_node_or_null("ArbolComportamiento")
		if arbol:
			arbol.activo = false
		# Ni condición a mano ni travel(): Enemigo._aplicar_presentacion()
		# corre TODOS los fotogramas y pisa debeCaminar/debeIdle según la
		# velocidad REAL del cuerpo (Enemigo.gd:326, "velocity != ZERO") —
		# poner la condición a mano se perdía al fotograma siguiente. Hay
		# que hacerlo caminar de verdad, con la misma API que usa el BT.
		_mob.get_node("MovimientoComponente").comandar_direccion(Vector2.RIGHT, 50.0)
	elif _fotogramas == 20:
		print("Arranca en CAMINAR (esperado true): %s" % (_playback.get_current_node() == "CAMINAR"))
		_habilidad_carga.activar(Vector2.RIGHT, 1.0)
		_fotogramas_desde_activar = 0
	# duracion_preparacion=1.0s en Lobo -> justo antes de que termine.
	elif _fotogramas_desde_activar == 50:
		_prep_ok = _tree.get("parameters/conditions/debeMordidaPrep") == true \
			and _tree.get("parameters/conditions/debeMordidaDash") == false
		_prep_estado_ok = _playback.get_current_node() == "MORDIDA_PREPARACION"
		print("Tras iniciar la carga, en fase de preparación (esperado true/false): %s/%s | estado real (esperado MORDIDA_PREPARACION): %s" % [
			_tree.get("parameters/conditions/debeMordidaPrep"),
			_tree.get("parameters/conditions/debeMordidaDash"),
			_playback.get_current_node(),
		])
	# Pasado duracion_preparacion (60 frames) ya debería estar en el dash.
	elif _fotogramas_desde_activar == 70:
		_dash_ok = _tree.get("parameters/conditions/debeMordidaPrep") == false \
			and _tree.get("parameters/conditions/debeMordidaDash") == true
		_dash_estado_ok = _playback.get_current_node() == "MORDIDA_DASH"
		print("Tras terminar la preparación, en fase de dash (esperado false/true): %s/%s | estado real (esperado MORDIDA_DASH): %s" % [
			_tree.get("parameters/conditions/debeMordidaPrep"),
			_tree.get("parameters/conditions/debeMordidaDash"),
			_playback.get_current_node(),
		])
	# El dash es corto (distancia_maxima_dash a multiplicador alto) — para
	# cuando llegue acá ya debería haber terminado solo. El mob nunca dejó
	# de tener comandada la caminata (a propósito, ver frame 5, y el BT que
	# se lo pisaría está apagado) — el desenlace correcto NO es IDLE acá,
	# es que retome CAMINAR solo apenas ataque_en_curso se libera
	# (_aplicar_presentacion vuelve a mandar según la velocidad real del
	# cuerpo, que nunca dejó de ser != ZERO).
	elif _fotogramas_desde_activar == 150:
		_fin_ok = _tree.get("parameters/conditions/debeMordidaDash") == false \
			and _tree.get("parameters/conditions/debeSalirMordida") == true \
			and _playback.get_current_node() == "CAMINAR"
		print("Tras terminar el dash, retoma la caminata que traía (esperado false/true/CAMINAR): %s/%s/%s" % [
			_tree.get("parameters/conditions/debeMordidaDash"),
			_tree.get("parameters/conditions/debeSalirMordida"),
			_playback.get_current_node(),
		])
		return _informar()
	return false


func _montar(ruta: String) -> void:
	var jugador := Node2D.new()
	jugador.add_to_group("jugadores")
	root.add_child(jugador)
	current_scene = jugador
	jugador.global_position = Vector2(500, 0)

	_mob = (load(ruta) as PackedScene).instantiate()
	root.add_child(_mob)
	_mob.global_position = Vector2.ZERO
	_mob.memoria.establecer("objetivo", jugador)

	_habilidad_carga = _mob.get_node("Habilidades/HabilidadCarga")
	_tree = _mob.get_node("AnimacionComponente/AnimationTree")
	_playback = _tree.get("parameters/playback")


func _informar() -> bool:
	var exito := _prep_ok and _prep_estado_ok and _dash_ok and _dash_estado_ok and _fin_ok
	print("PRUEBA ANIMACIÓN MORDIDA LOBO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
