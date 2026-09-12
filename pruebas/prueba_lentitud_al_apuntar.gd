# =============================================================================
# Prueba de HabilidadBase.factor_velocidad_apuntando: mientras se apunta una
# habilidad con este factor (Cepo/Trampa, 0.2), el dueño se mueve a un
# quinto de su velocidad máxima -- pedido explícito del usuario para
# obligar a pensar mejor cuándo y dónde colocarlas, y de paso reducir el
# margen real de "la posición de colocación se corre" (ver HabilidadBase.
# activar()/_al_empezar_apunte_lento). Se prueba con HabilidadCepo directo
# (factor real 0.2) y un Jugador.tscn real (tiene MovimientoComponente de
# verdad, con su _multiplicador_lentitud()).
#   godot --headless --path . --script res://pruebas/prueba_lentitud_al_apuntar.gd
# =============================================================================
extends SceneTree

var _jugador
var _habilidad
var _movimiento
var _fotogramas := 0

var _normal_antes_de_apuntar := -1.0
var _lento_al_apuntar := -1.0
var _normal_al_soltar := -1.0
var _lento_al_reapuntar := -1.0
var _normal_al_cancelar := -1.0


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			_normal_antes_de_apuntar = _movimiento._multiplicador_lentitud()
		5:
			root.get_node("/root/SeñalManager").emitir("slot_0_apunte", "prueba", [Vector2.RIGHT, 1.0])
		6:
			_lento_al_apuntar = _movimiento._multiplicador_lentitud()
		10:
			# Soltar (lanzar de verdad) — la lentitud tiene que desaparecer.
			root.get_node("/root/SeñalManager").emitir("slot_0_lanzar", "prueba", [Vector2.RIGHT, 1.0])
		11:
			_normal_al_soltar = _movimiento._multiplicador_lentitud()
			# Reapuntar de nuevo, esta vez para CANCELAR en vez de lanzar.
			root.get_node("/root/SeñalManager").emitir("slot_0_apunte", "prueba", [Vector2.UP, 1.0])
		12:
			_lento_al_reapuntar = _movimiento._multiplicador_lentitud()
		15:
			root.get_node("/root/SeñalManager").emitir("slot_0_cancelar", "prueba", [])
		16:
			_normal_al_cancelar = _movimiento._multiplicador_lentitud()
			return _informar()
	return false


func _montar() -> void:
	var sm := root.get_node("/root/SeñalManager")
	sm.registrar("slot_0_apunte", "prueba", {"direccion": TYPE_VECTOR2, "poder": TYPE_FLOAT})
	sm.registrar("slot_0_lanzar", "prueba", {"direccion": TYPE_VECTOR2, "poder": TYPE_FLOAT})
	sm.registrar("slot_0_cancelar", "prueba", {})

	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(_jugador)
	_movimiento = _jugador.componente_movimiento

	var contenedor := Marker2D.new()
	contenedor.name = "HabilidadesPrueba"
	_jugador.add_child(contenedor)

	# slot_index ANTES de add_child: HabilidadBase._ready() (que corre AL
	# agregarlo) necesita verlo ya puesto para conectar las señales del
	# slot correcto — mismo orden que ya usa prueba_lanzallamas_gira_hacia_
	# apunte.gd para el mismo problema.
	var guion := load("res://escenas/habilidades/cepo/HabilidadCepo.gd") as GDScript
	_habilidad = guion.new()
	_habilidad.slot_index = 0
	contenedor.add_child(_habilidad)
	_habilidad.entidad_dueña = _jugador


func _informar() -> bool:
	var exito := is_equal_approx(_normal_antes_de_apuntar, 1.0) \
		and is_equal_approx(_lento_al_apuntar, 0.2) \
		and is_equal_approx(_normal_al_soltar, 1.0) \
		and is_equal_approx(_lento_al_reapuntar, 0.2) \
		and is_equal_approx(_normal_al_cancelar, 1.0)
	print("Velocidad normal antes de apuntar (esperado 1.0): %.2f" % _normal_antes_de_apuntar)
	print("Velocidad reducida al apuntar Cepo (esperado 0.2): %.2f" % _lento_al_apuntar)
	print("Velocidad normal al soltar/lanzar (esperado 1.0): %.2f" % _normal_al_soltar)
	print("Velocidad reducida de nuevo al reapuntar (esperado 0.2): %.2f" % _lento_al_reapuntar)
	print("Velocidad normal al cancelar (esperado 1.0): %.2f" % _normal_al_cancelar)
	print("PRUEBA LENTITUD AL APUNTAR %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
