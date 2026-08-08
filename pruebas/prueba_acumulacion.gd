# =============================================================================
# Prueba de HabilidadAcumulacion/AcumulacionDanoComponente:
#   1. Al activarla, anota TODO el daño que RECIBE el jugador (sin reducirlo).
#   2. Presionarla una segunda vez ANTES de tiempo (duracion_acumulacion se
#      deja bien larga a propósito, para forzar este camino y no el
#      vencimiento natural — que es el mismo _detonar() por dentro, ver
#      AcumulacionDanoComponente) detona YA, devolviendo el porcentaje
#      configurado a los enemigos cercanos, y esa segunda presión no cuesta
#      energía.
#   3. La recarga real arranca recién al detonar, no al activarla — mientras
#      está acumulando, la habilidad se puede volver a presionar.
#   godot --headless --path . --script res://pruebas/prueba_acumulacion.gd
# =============================================================================
extends SceneTree

var _f := 0
var _jugador: CharacterBody2D
var _energia
var _enemigo: CharacterBody2D
var _acumulacion
var _bus

var _acumula_dano_recibido_ok := false
var _detona_y_golpea_cercanos_ok := false
var _detonar_antes_no_cuesta_energia_ok := false
var _recarga_arranca_al_detonar_ok := false
var _indicador_zona_ok := false
var _fase_eventos: Array = []
var _emite_fase_activa_ok := false
var _emite_fase_inactiva_al_detonar_ok := false


func _process(_d: float) -> bool:
	_f += 1
	match _f:
		1:
			_montar()
		2:
			# Activarla: primera presión, sí cuesta energía.
			_acumulacion.activar(Vector2.ZERO, 1.0)
		4:
			_emite_fase_activa_ok = _fase_eventos.size() == 1 and _fase_eventos[0] == true
			print("Emite habilidad_fase_cambiada(activa=true) al activarla (esperado true): %s (%s)" % [
				_emite_fase_activa_ok, _fase_eventos])
			print("Energía tras activar (esperado 80, costaba 20 de 100): %.0f" % _energia.obtener_energia())
			# El jugador recibe 3 golpes de 10 mientras está acumulando.
			for i in 3:
				_bus.daño_aplicado.emit(_jugador, 10.0, _enemigo, 2, false)
		6:
			var comp = _jugador.get_node_or_null("AcumulacionDanoComponente")
			_acumula_dano_recibido_ok = comp != null and is_equal_approx(comp.acumulado(), 30.0)
			print("Acumuló los 30 de daño recibidos (esperado true): %s (acumulado=%.0f)" % [
				_acumula_dano_recibido_ok, comp.acumulado() if comp else -1.0])

			# Segunda presión ANTES de tiempo: detona ya, y no debería
			# gastar energía (quedaba 80).
			_acumulacion.activar(Vector2.ZERO, 1.0)
		8:
			var vida_enemigo := _enemigo.get_node("VidaComponente")
			# 30 acumulado * 30% = 9 de daño esperado (sin variación de
			# atributos: ni jugador ni enemigo tienen AtributosComponente acá).
			var vida_restante: float = vida_enemigo.obtener_vida()
			_detona_y_golpea_cercanos_ok = vida_restante < 100.0
			print("El enemigo cercano recibió la explosión (esperado true, vida=%.1f de 100): %s" % [
				vida_restante, _detona_y_golpea_cercanos_ok])

			_detonar_antes_no_cuesta_energia_ok = is_equal_approx(_energia.obtener_energia(), 80.0)
			print("Detonar antes de tiempo no costó energía (esperado true, sigue en 80): %s (%.0f)" % [
				_detonar_antes_no_cuesta_energia_ok, _energia.obtener_energia()])

			_recarga_arranca_al_detonar_ok = _acumulacion.obtener_recarga_restante() > 0.0
			print("La recarga real recién arrancó al detonar (esperado true, > 0): %s (%.1f)" % [
				_recarga_arranca_al_detonar_ok, _acumulacion.obtener_recarga_restante()])

			# Feedback visual del radio real (pedido del usuario) — tiene que
			# aparecer en la escena, centrado en el jugador, con el radio real.
			var indicador: Node = null
			for hijo in current_scene.get_children():
				if hijo.get_script() == load("res://escenas/efectos/IndicadorZonaEfecto.gd"):
					indicador = hijo
					break
			_indicador_zona_ok = indicador != null \
				and indicador.global_position.distance_to(_jugador.global_position) < 0.01 \
				and is_equal_approx(indicador.radio, _acumulacion.radio_detonacion)
			print("Aparece el indicador de zona (esperado true): %s" % _indicador_zona_ok)

			_emite_fase_inactiva_al_detonar_ok = _fase_eventos.size() == 2 and _fase_eventos[1] == false
			print("Emite habilidad_fase_cambiada(activa=false) al detonar (esperado true): %s (%s)" % [
				_emite_fase_inactiva_al_detonar_ok, _fase_eventos])
			return _informar()
	return false


func _montar() -> void:
	var escena := Node2D.new()
	root.add_child(escena)
	current_scene = escena

	_bus = root.get_node("/root/BusEventos")

	_jugador = CharacterBody2D.new()
	_jugador.add_to_group("jugadores")
	escena.add_child(_jugador)
	_jugador.global_position = Vector2.ZERO

	var vida_jugador = (load("res://componentes/VidaComponente.gd") as GDScript).new()
	vida_jugador.name = "VidaComponente"
	vida_jugador.intervalo_regeneracion = 0.0
	_jugador.add_child(vida_jugador)
	vida_jugador.cancelar_invulnerabilidad()

	_energia = (load("res://componentes/EnergiaComponente.gd") as GDScript).new()
	_energia.name = "EnergiaComponente"
	_energia.energia_maxima = 100.0
	_jugador.add_child(_energia)

	# Enemigo cerca, dentro del radio de detonación (60px en esta prueba).
	_enemigo = CharacterBody2D.new()
	_enemigo.add_to_group("enemigos")
	escena.add_child(_enemigo)
	_enemigo.global_position = Vector2(20, 0)
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 10.0
	forma.shape = circulo
	_enemigo.add_child(forma)
	var vida_enemigo = (load("res://componentes/VidaComponente.gd") as GDScript).new()
	vida_enemigo.name = "VidaComponente"
	vida_enemigo.intervalo_regeneracion = 0.0
	_enemigo.add_child(vida_enemigo)

	var contenedor := Marker2D.new()
	contenedor.name = "HabilidadesPrueba"
	_jugador.add_child(contenedor)

	var guion := load("res://escenas/habilidades/acumulacion/HabilidadAcumulacion.gd") as GDScript
	_acumulacion = guion.new()
	_acumulacion.slot_index = 0
	_acumulacion.costo_energia = 20.0
	_acumulacion.duracion_recarga = 5.0
	_acumulacion.duracion_acumulacion = 999.0  # no vence sola en esta prueba
	_acumulacion.porcentaje_detonacion = 0.3
	_acumulacion.radio_detonacion = 60.0
	contenedor.add_child(_acumulacion)
	_acumulacion.entidad_dueña = _jugador

	_bus.habilidad_fase_cambiada.connect(func(entidad, slot_idx, activa):
		if entidad == _jugador and slot_idx == 0:
			_fase_eventos.append(activa)
	)


func _informar() -> bool:
	var exito := _acumula_dano_recibido_ok and _detona_y_golpea_cercanos_ok \
		and _detonar_antes_no_cuesta_energia_ok and _recarga_arranca_al_detonar_ok \
		and _indicador_zona_ok and _emite_fase_activa_ok and _emite_fase_inactiva_al_detonar_ok
	print("  acumula el daño recibido: %s" % _acumula_dano_recibido_ok)
	print("  detona y golpea a los cercanos: %s" % _detona_y_golpea_cercanos_ok)
	print("  detonar antes es gratis: %s" % _detonar_antes_no_cuesta_energia_ok)
	print("  la recarga real arranca al detonar: %s" % _recarga_arranca_al_detonar_ok)
	print("  indicador de zona: %s" % _indicador_zona_ok)
	print("  emite fase activa al activar: %s" % _emite_fase_activa_ok)
	print("  emite fase inactiva al detonar: %s" % _emite_fase_inactiva_al_detonar_ok)
	print("PRUEBA ACUMULACION %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
