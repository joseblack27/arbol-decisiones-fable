# =============================================================================
# Prueba: "atacar por probabilidad a quien tenga menos vida" — Enemigo.
# _tienta_por_vida_baja, usado desde _evaluar_objetivo (robo de objetivo al
# entrar en rango) y _retomar_mejor_objetivo (al perder al actual). Pedido
# de diseño explícito: SUMA un criterio nuevo al de distancia de siempre
# (ver prueba_objetivo_multiples_jugadores), no lo reemplaza — casi siempre
# debería seguir ganando el más cercano, salvo que un candidato herido
# "tiente" al mob por probabilidad.
#
# probabilidad_rematar_vida_baja se fuerza a 1.0 en el mob de prueba (en vez
# de dejar el 0.5 por defecto) para que la prueba sea determinística — no
# depende de la semilla de randf(). El control negativo NO usa probabilidad
# 0.0 (randf() <= 0.0 podría, en teoría, dar true si randf() cae justo en
# 0.0) sino un candidato con vida por ENCIMA del umbral, que ni siquiera
# llega a tirar el dado — cero superficie de intermitencia.
#   godot --headless --path . --script res://pruebas/prueba_objetivo_vida_baja.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _mob: Node
var _jugador_a: Node2D
var _jugador_b: Node2D
var _jugador_c: Node2D
var _jugador_d: Node2D

var _un_candidato_ok := false
var _roba_objetivo_por_vida_baja_ok := false
var _no_tienta_sobre_el_umbral_ok := false
var _retoma_por_vida_baja_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		20:
			# Solo A detectado (dist 100, sano): tiene que ser el objetivo.
			_un_candidato_ok = _objetivo() == _jugador_a
			print("Con un solo candidato, objetivo = A (esperado true): %s" % _un_candidato_ok)
			_jugador_b = _crear_jugador(Vector2(150, 0))  # más lejos que A, pero adentro del radio de visión (~200)
			_herir(_jugador_b, 0.2)  # 20% de vida, bajo el umbral (0.35)
			_mob.probabilidad_rematar_vida_baja = 1.0
		40:
			# B está más lejos que A (150 vs 100 px) — por distancia sola
			# jamás le robaría el objetivo (nunca se roba por estar más
			# lejos). Con vida baja + probabilidad 1.0, tiene que robárselo
			# igual.
			_roba_objetivo_por_vida_baja_ok = _objetivo() == _jugador_b
			print("Candidato herido y lejos roba el objetivo con probabilidad 1.0 (esperado true): %s" % _roba_objetivo_por_vida_baja_ok)
			_jugador_c = _crear_jugador(Vector2(170, 0))  # aún más lejos, siempre adentro del radio
			_herir(_jugador_c, 0.4)  # 40% > 35% de umbral: NO debería tentar
		60:
			# C está "herido" pero por ENCIMA del umbral configurado: no
			# tienta aunque la probabilidad siga en 1.0 — sigue B.
			_no_tienta_sobre_el_umbral_ok = _objetivo() == _jugador_b
			print("Vida por ENCIMA del umbral no tienta aunque la probabilidad sea 1.0 (esperado true, sigue B): %s" % _no_tienta_sobre_el_umbral_ok)
			# B (objetivo actual) se va lejos, fuera de la visión. Quedan
			# detectados A (dist 100, sano), C (dist 170, 40%, no tienta) y
			# ahora D (dist 180, 15%, sí tienta) — _retomar_mejor_objetivo
			# tiene que preferir a D aunque A esté mucho más cerca.
			_jugador_b.global_position = Vector2(9000, 9000)
			_jugador_d = _crear_jugador(Vector2(180, 0))
			_herir(_jugador_d, 0.15)
		100:
			_retoma_por_vida_baja_ok = _objetivo() == _jugador_d
			print("Al retomar tras perder el objetivo, prefiere al herido D sobre el más cercano A/C (esperado true): %s" % _retoma_por_vida_baja_ok)
			return _informar()
	return false


func _objetivo():
	return _mob.memoria.obtener("objetivo")


func _herir(jugador: Node2D, fraccion: float) -> void:
	var vida := jugador.get_node("VidaComponente")
	vida.salud_actual = vida.salud_maxima * fraccion


func _montar() -> void:
	var escena := Node2D.new()
	root.add_child(escena)
	current_scene = escena

	_mob = (load("res://escenas/enemigos/EnemigoLobo.tscn") as PackedScene).instantiate()
	escena.add_child(_mob)
	_mob.global_position = Vector2.ZERO
	# Sin IA: acá interesa la DECISIÓN de objetivo, no que el lobo se mueva y
	# cambie las distancias a mitad de la medición (mismo criterio que
	# prueba_objetivo_multiples_jugadores).
	(_mob.get_node("ArbolComportamiento")).activo = false
	_mob.umbral_vida_tentadora = 0.35

	_jugador_a = _crear_jugador(Vector2(100, 0))


## Jugador mínimo: Node2D en el grupo "jugadores" con un Area2D
## "VidaComponente" real (mismo criterio que prueba_objetivo_multiples_
## jugadores) — VisionComponente exige ambas cosas para registrarlo, y
## _tienta_por_vida_baja necesita esa misma área (VidaComponente extends
## Area2D) para leer salud_actual/salud_maxima.
func _crear_jugador(pos: Vector2) -> Node2D:
	var jugador := Node2D.new()
	jugador.add_to_group("jugadores")
	current_scene.add_child(jugador)
	jugador.global_position = pos

	var vida := Area2D.new()
	vida.name = "VidaComponente"
	vida.set_script(load("res://componentes/VidaComponente.gd"))
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 10.0
	forma.shape = circulo
	vida.add_child(forma)
	jugador.add_child(vida)
	# Enemigo._evaluar_objetivo/_priorizar_atacante identifican al candidato
	# por área.owner: un add_child() común no fija "owner" solo, hay que
	# hacerlo a mano.
	vida.owner = jugador

	return jugador


func _informar() -> bool:
	var exito := _un_candidato_ok and _roba_objetivo_por_vida_baja_ok \
		and _no_tienta_sobre_el_umbral_ok and _retoma_por_vida_baja_ok
	print("  un candidato: %s" % _un_candidato_ok)
	print("  roba objetivo por vida baja (prob 1.0): %s" % _roba_objetivo_por_vida_baja_ok)
	print("  no tienta sobre el umbral: %s" % _no_tienta_sobre_el_umbral_ok)
	print("  retoma por vida baja al perder el objetivo: %s" % _retoma_por_vida_baja_ok)
	print("PRUEBA OBJETIVO VIDA BAJA %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
