# =============================================================================
# Prueba de que el log de daño ("A hizo X daño a B", antes en PanelTablero
# "Actividad Reciente") ahora vive en GestorLogRed — pedido del usuario:
# "quiero moverlo al panel de logs de red". Verifica:
#   1. BusEventos.daño_aplicado (single-player/servidor) agrega una línea
#      "X hizo N daño a Y" a GestorLogRed.lineas.
#   2. BusEventos.daño_replicado (cliente puro, con el nombre del atacante
#      ya resuelto como texto, incluso invisible) también agrega su línea.
#   3. Daño recibido por un NO-jugador (un mob) no se registra — mismo
#      criterio de siempre, solo interesa el daño que reciben jugadores.
#   godot --headless --path . --script res://pruebas/prueba_log_red_dano.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _jugador
var _mob
var _gestor_log_red
var _bus
var _lineas_antes := 0

var _registra_dano_aplicado := false
var _registra_dano_replicado := false
var _no_registra_dano_a_mob := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			_lineas_antes = _gestor_log_red.lineas.size()
			_bus.daño_aplicado.emit(_jugador, 12.0, null, 2, false)
		3:
			var nuevas: Array = _gestor_log_red.lineas.slice(_lineas_antes)
			_registra_dano_aplicado = nuevas.size() == 1 and nuevas[0].contains("12 daño")
			print("Registra daño_aplicado (esperado true): %s -> %s" % [_registra_dano_aplicado, nuevas])
			_lineas_antes = _gestor_log_red.lineas.size()
			_bus.daño_replicado.emit(_jugador, 7.0, "EnemigoAraña@5 [invisible]")
		4:
			var nuevas: Array = _gestor_log_red.lineas.slice(_lineas_antes)
			_registra_dano_replicado = nuevas.size() == 1 and nuevas[0].contains("7 daño") \
				and nuevas[0].contains("[invisible]")
			print("Registra daño_replicado, con atacante invisible (esperado true): %s -> %s" % [
				_registra_dano_replicado, nuevas])
			_lineas_antes = _gestor_log_red.lineas.size()
			_bus.daño_aplicado.emit(_mob, 5.0, null, 2, false)
		5:
			var nuevas: Array = _gestor_log_red.lineas.slice(_lineas_antes)
			_no_registra_dano_a_mob = nuevas.is_empty()
			print("No registra daño recibido por un mob (esperado true): %s" % _no_registra_dano_a_mob)
			return _informar()
	return false


func _montar() -> void:
	_gestor_log_red = root.get_node("/root/GestorLogRed")
	_bus = root.get_node("/root/BusEventos")
	_jugador = CharacterBody2D.new()
	_jugador.add_to_group("jugadores")
	root.add_child(_jugador)
	_mob = CharacterBody2D.new()
	_mob.add_to_group("enemigos")
	root.add_child(_mob)


func _informar() -> bool:
	var exito := _registra_dano_aplicado and _registra_dano_replicado and _no_registra_dano_a_mob
	print("PRUEBA LOG RED DANO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
