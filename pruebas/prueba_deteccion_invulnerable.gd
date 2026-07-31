# =============================================================================
# Prueba: mientras un jugador es invulnerable (protección al revivir, ver
# Jugador.TIEMPO_INVULNERABILIDAD_REVIVIR) NO puede ser objetivo de ningún
# mob — y en cuanto termina esa protección, si se quedó QUIETO dentro del
# área del mob todo este tiempo (sin salir y volver a entrar físicamente,
# el caso real de un jugador que revive pegado al mob que lo mató), el mob
# SÍ debe empezar a detectarlo. Antes de este fix, VisionComponente solo
# sabía QUITAR objetivos que dejaban de ser válidos (_podar_invalidos); no
# había contraparte que agregara uno que se vuelve válido de nuevo sin un
# area_entered físico real — reportado: "cuando el jugador revive y esta
# dentro del area de un mob este no lo toma como objetivo".
#   godot --headless --path . --script res://pruebas/prueba_deteccion_invulnerable.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _vision: VisionComponente
var _vida: Area2D
var _eventos: Array[String] = []
var _eventos_al_revivir_invulnerable := 0

var _no_detecta_mientras_es_invulnerable := false
var _detecta_al_terminar_la_inmunidad_sin_moverse := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		10:
			# "Muerte": se apaga monitorable SIN mover el cuerpo (mismo
			# criterio que Jugador._morir()).
			_vida.monitorable = false
		50:
			# "Revive" EN EL MISMO LUGAR (nunca se mueve en toda la prueba) y
			# queda invulnerable un rato corto (0.3s) para no alargar la
			# prueba de más.
			_vida.monitorable = true
			_vida.activar_invulnerabilidad(0.3)
		55:
			# ~0.08s tras revivir: bien invulnerable todavía (dura 0.3s). No
			# debe haber un "detectado" nuevo mientras dure la protección.
			_eventos_al_revivir_invulnerable = _eventos.size()
			_no_detecta_mientras_es_invulnerable = _eventos == ["detectado", "perdido"]
			print("No detecta mientras es invulnerable (esperado true): %s -> %s" % [
				_no_detecta_mientras_es_invulnerable, _eventos])
		120:
			# La invulnerabilidad (0.3s = 18 fotogramas desde el 50, o sea
			# vence ~68) ya terminó hace rato, y ya pasó de sobra un ciclo de
			# _INTERVALO_PODA (0.5s) desde entonces — sin moverse ni un
			# píxel, _detectar_pendientes debe haberlo vuelto a detectar.
			_detecta_al_terminar_la_inmunidad_sin_moverse = _eventos == ["detectado", "perdido", "detectado"]
			print("Detecta de nuevo al terminar la inmunidad, sin moverse (esperado true): %s -> %s" % [
				_detecta_al_terminar_la_inmunidad_sin_moverse, _eventos])
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
	_vision.objetivo_detectado.connect(func(_a): _eventos.append("detectado"))
	_vision.objetivo_perdido.connect(func(_a): _eventos.append("perdido"))

	var jugador := Node2D.new()
	escena.add_child(jugador)
	_vida = Area2D.new()
	_vida.name = "VidaComponente"
	_vida.set_script(load("res://componentes/VidaComponente.gd"))
	var forma_j := CollisionShape2D.new()
	var circ_j := CircleShape2D.new()
	circ_j.radius = 10.0
	forma_j.shape = circ_j
	_vida.add_child(forma_j)
	jugador.add_child(_vida)


func _informar() -> bool:
	var exito := _no_detecta_mientras_es_invulnerable and _detecta_al_terminar_la_inmunidad_sin_moverse
	print("PRUEBA DETECCION INVULNERABLE %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
