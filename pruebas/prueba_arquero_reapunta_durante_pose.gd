# =============================================================================
# Prueba de HabilidadFlechaArquero: durante la pose (antes de que salga la
# flecha), el arquero debe seguir apuntando al objetivo — si el jugador se
# mueve mientras dura la pose, la flecha tiene que salir hacia la posición
# NUEVA, no la que tenía cuando arrancó el disparo. Pedido explícito del
# usuario: "quiero que el arquero apunte hasta la última posición donde
# estuvo el jugador hasta que salga la flecha, porque si no es muy fácil
# esquivarlo".
#
# memoria["objetivo"] tiene que estar seteado (igual que en juego real, vía
# VisionComponente/AccionAtacar) para que _process() de la habilidad tenga
# a quién reapuntar — sin esto, _ejecutar() directo alcanzaba para las
# otras pruebas de esta habilidad, pero acá específicamente hace falta.
#   godot --headless --path . --script res://pruebas/prueba_arquero_reapunta_durante_pose.gd
# =============================================================================
extends SceneTree

var _jugador
var _mob
var _habilidad
var _gestor_piscinas: Node
var _ruta_proyectil: String
var _fase := 0
var _contador := 0

var _ok_apunta_inicial := false
var _ok_reapunta_tras_moverse := false
var _ok_flecha_sale_hacia_posicion_nueva := false


func _process(_delta: float) -> bool:
	if _fase > 0 and not (_habilidad.get("escena_proyectil") is PackedScene):
		# Falla rápido y con mensaje claro en vez de quedarse llamando
		# métodos rotos cada fotograma para siempre — un script relacionado
		# que no compila deja el nodo con propiedades inválidas, no null
		# limpio (ver memoria del proyecto).
		push_error("HabilidadFlecha sin escena_proyectil válida — ¿algún script relacionado no compila?")
		quit(1)
		return true
	match _fase:
		0:
			_montar()
			_fase = 1
		1:
			# Jugador arranca a la derecha del arquero (300,0 vs mob en 0,0):
			# dirección inicial esperada (1,0).
			_habilidad._ejecutar(Vector2.RIGHT, 1.0)
			_ok_apunta_inicial = _mob.direccion_mirada.is_equal_approx(Vector2.RIGHT)
			print("Al disparar, apunta a la posición inicial del jugador (esperado (1,0)): %s (%s)" % [
				_mob.direccion_mirada, _ok_apunta_inicial
			])
			_fase = 2
		2:
			# El jugador se mueve MIENTRAS dura la pose: ahora queda ARRIBA
			# del arquero en vez de a la derecha.
			_jugador.global_position = Vector2(0, -300)
			_contador = 0
			_fase = 3
		3:
			_contador += 1
			if _contador < 5:  # unos fotogramas para que _process() de la habilidad reaccione.
				return false
			_ok_reapunta_tras_moverse = _mob.direccion_mirada.is_equal_approx(Vector2.UP)
			print("Tras moverse el jugador, reapunta hacia la posición nueva (esperado (0,-1)): %s (%s)" % [
				_mob.direccion_mirada, _ok_reapunta_tras_moverse
			])
			_contador = 0
			_fase = 4
		4:
			# Esperar el resto de la pose (duracion_pose_ataque=1.2s por
			# defecto) para que la flecha realmente salga.
			_contador += 1
			if _contador < 80:  # ~1.33s: de sobra para pasar 1.2s.
				return false
			var proyectiles := _proyectiles_activos()
			_ok_flecha_sale_hacia_posicion_nueva = proyectiles.size() == 1 \
				and (proyectiles[0]._direccion as Vector2).is_equal_approx(Vector2.UP)
			print("La flecha sale hacia la posición nueva, no la inicial (esperado (0,-1)): %s (%s proyectiles)" % [
				proyectiles[0]._direccion if proyectiles.size() == 1 else "?", proyectiles.size()
			])
			return _informar()
	return false


func _montar() -> void:
	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(_jugador)
	_jugador.global_position = Vector2(300, 0)

	_mob = (load("res://escenas/enemigos/EnemigoEsqueletoArquero.tscn") as PackedScene).instantiate()
	root.add_child(_mob)
	_mob.global_position = Vector2.ZERO
	_mob.memoria.establecer("objetivo", _jugador)

	_habilidad = _mob.get_node("Habilidades/HabilidadFlecha")
	_ruta_proyectil = _habilidad.escena_proyectil.resource_path
	# get_node("/root/...") en vez del identificador global GestorPiscinas:
	# ver prueba_animacion_disparo_arquero.gd para el porqué.
	_gestor_piscinas = root.get_node("/root/GestorPiscinas")


func _proyectiles_activos() -> Array:
	var resultado: Array = []
	for nodo in _gestor_piscinas._activos:
		if nodo.scene_file_path == _ruta_proyectil:
			resultado.append(nodo)
	return resultado


func _informar() -> bool:
	var exito := _ok_apunta_inicial and _ok_reapunta_tras_moverse and _ok_flecha_sale_hacia_posicion_nueva
	print("PRUEBA ARQUERO REAPUNTA DURANTE POSE %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
