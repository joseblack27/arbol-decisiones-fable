# =============================================================================
# Prueba del sprite del chorro de HabilidadLanzallamas (ChorroVisual, ver
# assets/efectos/chorro_lanzallamas.svg): solo visible mientras canaliza,
# orientado hacia donde apunta, y posicionado sobre el dueño.
#
# REQUIERE RENDERING REAL (sin --headless): _actualizar_visual_chorro() se
# salta entero en DisplayServer "headless" a propósito (no tiene sentido
# gastar en jitter/posición donde nadie va a verlo — ni el servidor
# dedicado ni las pruebas headless de siempre).
#   godot --path . --script res://pruebas/prueba_lanzallamas_visual_chorro.gd
# =============================================================================
extends SceneTree

var _jugador
var _habilidad
var _fotogramas := 0

var _oculto_antes_de_apuntar := false
var _visible_apuntando_derecha := false
var _rotacion_derecha_ok := false
var _rotacion_arriba_ok := false
var _posicion_ok := false
var _oculto_al_soltar := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		5:
			_oculto_antes_de_apuntar = not _habilidad._chorro_visual.visible
			root.get_node("/root/SeñalManager").emitir("slot_0_apunte", "prueba", [Vector2.RIGHT, 1.0])
		6:
			_visible_apuntando_derecha = _habilidad._chorro_visual.visible
			# Jitter de hasta ±3° (ver _actualizar_visual_chorro) — tolerancia
			# de sobra (±10°) para no volver la prueba frágil por el azar.
			_rotacion_derecha_ok = absf(_habilidad._chorro_visual.rotation) < deg_to_rad(10.0)
			_posicion_ok = _habilidad._chorro_visual.global_position.is_equal_approx(_jugador.global_position)
		10:
			root.get_node("/root/SeñalManager").emitir("slot_0_apunte", "prueba", [Vector2.UP, 1.0])
		11:
			var esperado := -PI / 2.0
			_rotacion_arriba_ok = absf(_habilidad._chorro_visual.rotation - esperado) < deg_to_rad(10.0)
		15:
			root.get_node("/root/SeñalManager").emitir("slot_0_lanzar", "prueba", [Vector2.UP, 1.0])
		16:
			_oculto_al_soltar = not _habilidad._chorro_visual.visible
			return _informar()
	return false


func _montar() -> void:
	var sm := root.get_node("/root/SeñalManager")
	sm.registrar("slot_0_apunte", "prueba", {"direccion": TYPE_VECTOR2, "poder": TYPE_FLOAT})
	sm.registrar("slot_0_lanzar", "prueba", {"direccion": TYPE_VECTOR2, "poder": TYPE_FLOAT})
	sm.registrar("slot_0_cancelar", "prueba", {})

	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(_jugador)
	_jugador.global_position = Vector2(50, 30)

	var contenedor := Marker2D.new()
	contenedor.name = "HabilidadesPrueba"
	_jugador.add_child(contenedor)

	var escena := load("res://escenas/habilidades/lanzallamas/HabilidadLanzallamas.tscn") as PackedScene
	_habilidad = escena.instantiate()
	_habilidad.slot_index = 0
	_habilidad.set("costo_energia", 0.0)
	contenedor.add_child(_habilidad)
	_habilidad.entidad_dueña = _jugador
	_habilidad.duracion_recarga = 0.1


func _informar() -> bool:
	print("Oculto antes de apuntar: %s" % _oculto_antes_de_apuntar)
	print("Visible apuntando a la derecha: %s (rotación ~0 ok: %s)" % [
		_visible_apuntando_derecha, _rotacion_derecha_ok
	])
	print("Posicionado sobre el dueño: %s" % _posicion_ok)
	print("Rotación tras reapuntar hacia arriba (~-90°) ok: %s" % _rotacion_arriba_ok)
	print("Oculto al soltar: %s" % _oculto_al_soltar)

	var exito := _oculto_antes_de_apuntar and _visible_apuntando_derecha and _rotacion_derecha_ok \
		and _posicion_ok and _rotacion_arriba_ok and _oculto_al_soltar
	print("PRUEBA LANZALLAMAS VISUAL CHORRO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
