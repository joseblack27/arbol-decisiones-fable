# =============================================================================
# Prueba de la réplica visual del chorro a espectadores (pedido del
# usuario: "¿la animación del lanzallamas se ve desde los demás
# jugadores?" -> no, y pidió agregarlo).
#
# No arma una red real de 2 clientes + servidor (probado a mano: la
# cantidad de reintentos de spawn de mobs en este entorno hace que el
# proceso tarde demasiado en encontrar su propio jugador, sin relación con
# este cambio) — en cambio, llama DIRECTO los receptores RPC
# (_recibir_inicio_visual_chorro_red / _actualizar.../_fin...), el mismo
# patrón que ya usan otras pruebas de este proyecto para probar lógica de
# red sin levantar transporte real (ver prueba_lanzallamas.gd). Confirma:
#   1. Sin aviso: _chorro_visual oculto (nadie canalizando, ni local ni
#      remoto).
#   2. Tras el aviso de "inicio": se muestra y rota hacia la dirección
#      avisada, aunque _canalizando (la simulación real) siga en false.
#   3. Tras el aviso de "actualización": rota hacia la nueva dirección.
#   4. Tras el aviso de "fin": vuelve a ocultarse.
# REQUIERE RENDERING REAL (sin --headless), mismo motivo que
# prueba_lanzallamas_visual_chorro.gd.
#   godot --path . --script res://pruebas/prueba_lanzallamas_visual_remoto.gd
# =============================================================================
extends SceneTree

var _jugador
var _habilidad
var _fotogramas := 0

var _oculto_al_inicio := false
var _visible_tras_aviso_inicio := false
var _rotacion_inicio_ok := false
var _rotacion_actualizacion_ok := false
var _oculto_tras_fin := false
var _canalizando_sigue_false := true


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		5:
			_oculto_al_inicio = not _habilidad._chorro_visual.visible
			_habilidad._recibir_inicio_visual_chorro_red(Vector2.RIGHT)
		6:
			_visible_tras_aviso_inicio = _habilidad._chorro_visual.visible
			_rotacion_inicio_ok = absf(_habilidad._chorro_visual.rotation) < deg_to_rad(1.0)
			_canalizando_sigue_false = _canalizando_sigue_false and not _habilidad._canalizando
			_habilidad._recibir_actualizacion_visual_chorro_red(Vector2.UP)
		7:
			var esperado := -PI / 2.0
			_rotacion_actualizacion_ok = absf(_habilidad._chorro_visual.rotation - esperado) < deg_to_rad(1.0)
			_canalizando_sigue_false = _canalizando_sigue_false and not _habilidad._canalizando
			_habilidad._recibir_fin_visual_chorro_red()
		8:
			_oculto_tras_fin = not _habilidad._chorro_visual.visible
			return _informar()
	return false


func _montar() -> void:
	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(_jugador)
	_jugador.global_position = Vector2(50, 30)

	var contenedor := Marker2D.new()
	contenedor.name = "HabilidadesPrueba"
	_jugador.add_child(contenedor)

	var escena := load("res://escenas/habilidades/lanzallamas/HabilidadLanzallamas.tscn") as PackedScene
	_habilidad = escena.instantiate()
	_habilidad.slot_index = 0
	contenedor.add_child(_habilidad)
	_habilidad.entidad_dueña = _jugador


func _informar() -> bool:
	print("Oculto sin ningún aviso: %s" % _oculto_al_inicio)
	print("Visible tras aviso de inicio (rotación ~0 ok: %s): %s" % [
		_rotacion_inicio_ok, _visible_tras_aviso_inicio
	])
	print("Rotación tras aviso de actualización (~-90°) ok: %s" % _rotacion_actualizacion_ok)
	print("Oculto tras aviso de fin: %s" % _oculto_tras_fin)
	print("_canalizando (la simulación real) se mantuvo en false todo el tiempo: %s" % _canalizando_sigue_false)

	var exito := _oculto_al_inicio and _visible_tras_aviso_inicio and _rotacion_inicio_ok \
		and _rotacion_actualizacion_ok and _oculto_tras_fin and _canalizando_sigue_false
	print("PRUEBA LANZALLAMAS VISUAL REMOTO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
