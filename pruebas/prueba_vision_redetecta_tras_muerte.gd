# =============================================================================
# Prueba: VisionComponente debe poder redetectar a un objetivo que se puso
# monitorable=false ESTANDO TODAVÍA solapado (el caso real: un jugador que
# muere pegado al mob que lo mató, sin moverse hasta reaparecer) — sin la
# poda de _podar_invalidos(), la entrada quedaba pegada en _areas_en_rango
# para siempre y el mob nunca volvía a "ver" a ese jugador, ni acercándose
# de verdad más tarde.
#   godot --headless --path . --script res://pruebas/prueba_vision_redetecta_tras_muerte.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _vision: VisionComponente
var _vida: Area2D
var _jugador: Node2D
var _eventos: Array[String] = []


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		10:
			# "Muerte": se apaga monitorable SIN mover el cuerpo (mismo
			# criterio que Jugador._morir()).
			_vida.monitorable = false
		# _INTERVALO_PODA = 0.5s -> unos 30 fotogramas de sobra a 60fps.
		45:
			# "Reaparición": vuelve monitorable y se teletransporta lejos,
			# después camina de vuelta — igual que el flujo real.
			_vida.monitorable = true
			_jugador.global_position = Vector2(3000, 3000)
		50:
			_jugador.global_position = Vector2.ZERO
		60:
			return _informar()
	return false


func _montar() -> void:
	var escena := Node2D.new()
	root.add_child(escena)
	current_scene = escena

	var mob := CharacterBody2D.new()
	escena.add_child(mob)
	_vision = VisionComponente.new()
	_vision.name = "Vision"
	var forma_v := CollisionShape2D.new()
	var circ_v := CircleShape2D.new()
	circ_v.radius = 100.0
	forma_v.shape = circ_v
	_vision.add_child(forma_v)
	mob.add_child(_vision)
	_vision.objetivo_detectado.connect(func(a): _eventos.append("detectado"))
	_vision.objetivo_perdido.connect(func(a): _eventos.append("perdido"))

	_jugador = Node2D.new()
	escena.add_child(_jugador)
	_vida = Area2D.new()
	_vida.name = "VidaComponente"
	# El script real no hace falta (VisionComponente solo pide "is VidaComponente"),
	# pero usarlo igual que en el juego real evita depender de un doble.
	_vida.set_script(load("res://componentes/VidaComponente.gd"))
	var forma_j := CollisionShape2D.new()
	var circ_j := CircleShape2D.new()
	circ_j.radius = 10.0
	forma_j.shape = circ_j
	_vida.add_child(forma_j)
	_jugador.add_child(_vida)


func _informar() -> bool:
	print("Eventos: %s" % [_eventos])
	# Se espera: detectado (montar) -> perdido (poda tras "morir") ->
	# detectado (redetección real tras alejarse y volver).
	var exito := _eventos == ["detectado", "perdido", "detectado"]
	print("PRUEBA VISION REDETECTA TRAS MUERTE %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
