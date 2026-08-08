# =============================================================================
# Prueba: elección de objetivo con VARIOS jugadores detectados a la vez (ver
# Enemigo._evaluar_objetivo / _priorizar_atacante / _retomar_mejor_objetivo).
#
# Antes, Enemigo._on_objetivo_detectado pisaba "objetivo" con el ÚLTIMO
# jugador que entraba en rango, sin comparar nada — con dos jugadores cerca,
# el mob saltaba de uno a otro según orden de detección, no por ninguna
# decisión real (pedido del usuario: "una pequeña capacidad de decisión de a
# quién atacar").
#
# Verifica, en secuencia, sobre un Lobo real:
#   1. Un solo candidato detectado → se vuelve el objetivo.
#   2. Un candidato NUEVO claramente más cerca (más que el margen de
#      histéresis) → le roba el objetivo al actual.
#   3. Un candidato apenas un poco más cerca (dentro del margen) → NO cambia
#      el objetivo (evita el temblor entre dos jugadores parecidos).
#   4. Un golpe de alguien detectado que NO es el objetivo actual → pasa a
#      serlo al instante, sin importar la distancia (prioridad al atacante).
#   5. Si el objetivo actual se va de la visión y quedan otros candidatos, el
#      mob no se queda pasivo: retoma con el más cercano de los que quedan.
#   6. Un golpe de alguien que NUNCA estuvo en su radio de visión (fuera de
#      rango, nunca detectado) NO lo convierte en objetivo a ciegas (eso
#      sería "detectarlo" con solo golpearlo) — pero tampoco sale gratis:
#      deja un aviso de "ruido" en memoria que sesga el PRÓXIMO destino de
#      AccionDeambular hacia esa dirección (pedido explícito del usuario:
#      "que el mob deambule en tu dirección, sin detectarte como objetivo,
#      acotado a su distancia máxima de deambular").
#   godot --headless --path . --script res://pruebas/prueba_objetivo_multiples_jugadores.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _mob: Node
var _jugador_a: Node2D
var _jugador_b: Node2D
var _jugador_c: Node2D

var _jugador_d: Node2D

var _un_candidato_ok := false
var _roba_objetivo_mas_cerca_ok := false
var _histeresis_ok := false
var _prioridad_atacante_ok := false
var _retoma_al_perder_objetivo_ok := false
var _ruido_sin_detectar_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		20:
			# Solo A detectado (dist 150): tiene que ser el objetivo.
			_un_candidato_ok = _objetivo() == _jugador_a
			print("Con un solo candidato, objetivo = A (esperado true): %s" % _un_candidato_ok)
			_jugador_b = _crear_jugador(Vector2(60, 0))  # mucho más cerca que A
		40:
			# B (dist 60) le roba el objetivo a A (dist 150): 90px de
			# diferencia, muy por encima del margen de histéresis.
			_roba_objetivo_mas_cerca_ok = _objetivo() == _jugador_b
			print("Candidato bien más cerca (B) roba el objetivo (esperado true): %s" % _roba_objetivo_mas_cerca_ok)
			_jugador_c = _crear_jugador(Vector2(50, 0))  # apenas más cerca que B
		60:
			# C (dist 50) está apenas 10px más cerca que B (dist 60): dentro
			# del margen de histéresis, no debería robarle el objetivo.
			_histeresis_ok = _objetivo() == _jugador_b
			print("Diferencia chica (C) NO roba el objetivo (esperado true, sigue B): %s" % _histeresis_ok)
			# A (el más lejos de los tres, y NO es el objetivo actual) golpea
			# al mob: tiene que pasar a ser el objetivo al instante.
			var bus = root.get_node("/root/BusEventos")
			bus.daño_aplicado.emit(_mob, 5.0, _jugador_a, 2, false)
		62:
			_prioridad_atacante_ok = _objetivo() == _jugador_a
			print("Atacante detectado (A) pasa a ser objetivo (esperado true): %s" % _prioridad_atacante_ok)
			# A (objetivo actual) se va lejos, fuera de la visión — deberían
			# quedar B y C, y el mob tiene que retomar con el más cerca (C).
			_jugador_a.global_position = Vector2(5000, 5000)
		95:
			_retoma_al_perder_objetivo_ok = _objetivo() == _jugador_c
			print("Al irse el objetivo actual, retoma con el más cerca que queda (C) (esperado true): %s" % _retoma_al_perder_objetivo_ok)
			# D nunca estuvo cerca del mob (radio de visión ~200px): jamás
			# pasó por _evaluar_objetivo. Golpea de todos modos — no debería
			# volverse el objetivo (no lo vio), pero tampoco puede salir
			# gratis: memoria tiene que quedar con el aviso de ruido.
			_jugador_d = _crear_jugador(Vector2(9000, 9000))
			var bus = root.get_node("/root/BusEventos")
			bus.daño_aplicado.emit(_mob, 5.0, _jugador_d, 2, false)
		97:
			var sigue_en_c: bool = _objetivo() == _jugador_c
			var dejo_ruido: bool = _mob.memoria.existe("ruido_posicion") \
				and _mob.memoria.obtener("ruido_posicion") == _jugador_d.global_position
			_ruido_sin_detectar_ok = sigue_en_c and dejo_ruido
			print("Golpe fuera de visión (D): NO se vuelve objetivo (esperado true): %s — deja ruido (esperado true): %s" % [
				sigue_en_c, dejo_ruido])
			return _informar()
	return false


func _objetivo():
	return _mob.memoria.obtener("objetivo")


func _montar() -> void:
	var escena := Node2D.new()
	root.add_child(escena)
	current_scene = escena

	_mob = (load("res://escenas/enemigos/EnemigoLobo.tscn") as PackedScene).instantiate()
	escena.add_child(_mob)
	_mob.global_position = Vector2.ZERO
	# Sin IA: acá interesa la DETECCIÓN/decisión de objetivo, no que el lobo
	# se mueva y cambie las distancias a mitad de la medición (mismo criterio
	# que prueba_camuflaje).
	(_mob.get_node("ArbolComportamiento")).activo = false

	_jugador_a = _crear_jugador(Vector2(150, 0))


## Jugador mínimo: Node2D en el grupo "jugadores" con un Area2D
## "VidaComponente" real (mismo criterio que prueba_vision_redetecta_tras_
## muerte) — VisionComponente exige ambas cosas para registrarlo.
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
	# por área.owner (mismo criterio que el "objetivo" que guarda memoria):
	# un add_child() común no fija "owner" solo, hay que hacerlo a mano.
	vida.owner = jugador

	return jugador


func _informar() -> bool:
	var exito := _un_candidato_ok and _roba_objetivo_mas_cerca_ok and _histeresis_ok \
		and _prioridad_atacante_ok and _retoma_al_perder_objetivo_ok \
		and _ruido_sin_detectar_ok
	print("  un candidato: %s" % _un_candidato_ok)
	print("  roba el objetivo si está bien más cerca: %s" % _roba_objetivo_mas_cerca_ok)
	print("  histéresis (no tiembla por diferencia chica): %s" % _histeresis_ok)
	print("  prioridad al atacante: %s" % _prioridad_atacante_ok)
	print("  retoma al perder el objetivo actual: %s" % _retoma_al_perder_objetivo_ok)
	print("  golpe fuera de visión deja ruido sin detectar: %s" % _ruido_sin_detectar_ok)
	print("PRUEBA OBJETIVO MULTIPLES JUGADORES %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
