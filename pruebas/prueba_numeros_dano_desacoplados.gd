# =============================================================================
# Prueba de la separación salud/presentación:
#   1. VidaComponente.quitar_vida() por sí solo (sin pasar por el bus) NO
#      muestra ningún número: ya no es su responsabilidad.
#   2. Emitir BusEventos.daño_aplicado SÍ hace aparecer un NumeroDaño activo
#      (lo escucha GestorNumerosDano, capa de presentación pura).
#   godot --headless --path . --script res://pruebas/prueba_numeros_dano_desacoplados.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _entidad: Node2D
var _vida: Area2D
var _bus: Node
var _contenedor_piscina: Node


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		3:
			# Daño "silencioso": solo el componente, sin pasar por el bus.
			_vida.call("quitar_vida", 10.0)
		5:
			_verificar_sin_numero()
			# Ahora sí, por el camino real: el bus.
			_bus.emit_signal("daño_aplicado", _entidad, 10.0, _entidad, 2, false)
		7:
			return _verificar_con_numero()
	return false


func _montar() -> void:
	_bus = root.get_node("/root/BusEventos")
	_contenedor_piscina = root.get_node("/root/GestorPiscinas/InstanciasPiscina")

	_entidad = Node2D.new()
	# GestorNumerosDano ahora solo muestra el número si el jugador LOCAL
	# está involucrado (objetivo o fuente — pedido del usuario: nada de
	# golpes ajenos). Utils.jugador_local() sin red busca el primer nodo
	# del grupo "jugadores" — sin este grupo, el gate de abajo bloquearía
	# TODO número, incluido el de esta prueba (que usa _entidad como
	# objetivo Y fuente a la vez).
	_entidad.add_to_group("jugadores")
	root.add_child(_entidad)
	_vida = (load("res://componentes/VidaComponente.gd") as GDScript).new()
	_entidad.add_child(_vida)


func _numeros_activos() -> int:
	var cuenta := 0
	for hijo in _contenedor_piscina.get_children():
		if hijo is NumeroDaño and hijo.visible:
			cuenta += 1
	return cuenta


func _verificar_sin_numero() -> void:
	var cuenta := _numeros_activos()
	print("Números activos tras daño SOLO por componente (esperado 0): %d" % cuenta)
	if cuenta != 0:
		print("PRUEBA NUMEROS DESACOPLADOS FALLIDA")
		quit(1)


func _verificar_con_numero() -> bool:
	var cuenta := _numeros_activos()
	print("Números activos tras BusEventos.daño_aplicado (esperado 1): %d" % cuenta)
	var exito := cuenta == 1
	print("PRUEBA NUMEROS DESACOPLADOS %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
