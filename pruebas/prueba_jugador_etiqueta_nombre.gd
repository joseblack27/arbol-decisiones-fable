# =============================================================================
# Feature A del plan MMO ("nombre sobre el jugador"): nombre_visible ya se
# replicaba a todos los peers (MultiplayerSynchronizer) pero nunca se
# dibujaba en ningún lado. Ahora es una propiedad con setter que mantiene
# sincronizado el nodo real "EtiquetaNombre" (mismo patrón que "NombreJefe"
# en EnemigoGuardianQuebrado — Label real, no dibujado por código).
#
# Verifica:
#   1. Dos jugadores con nombre_visible distinto muestran cada uno el suyo.
#   2. Reasignar nombre_visible en runtime (lo que hace la replicación real)
#      actualiza el Label de inmediato.
#   godot --headless --path . --script res://pruebas/prueba_jugador_etiqueta_nombre.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _jugador_a
var _jugador_b

var _nombres_iniciales_ok := false
var _reasignacion_en_runtime_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas == 1:
		_montar()
		return false
	if _fotogramas == 2:
		return _informar()
	return false


func _montar() -> void:
	var escena := load("res://escenas/jugador/Jugador.tscn") as PackedScene

	_jugador_a = escena.instantiate()
	_jugador_a.name = "1"
	root.add_child(_jugador_a)
	_jugador_a.nombre_visible = "Guerrero"

	_jugador_b = escena.instantiate()
	_jugador_b.name = "2"
	root.add_child(_jugador_b)
	_jugador_b.nombre_visible = "Maga"

	var etiqueta_a: Label = _jugador_a.get_node("EtiquetaNombre")
	var etiqueta_b: Label = _jugador_b.get_node("EtiquetaNombre")
	print("Etiqueta de A tras asignar (esperado 'Guerrero'): %s" % etiqueta_a.text)
	print("Etiqueta de B tras asignar (esperado 'Maga'): %s" % etiqueta_b.text)
	_nombres_iniciales_ok = etiqueta_a.text == "Guerrero" and etiqueta_b.text == "Maga"

	# Simula lo que hace la replicación real: el MultiplayerSynchronizer
	# reasigna la variable en runtime cuando le llega un cambio del dueño.
	_jugador_a.nombre_visible = "Guerrero Nv.5"
	var etiqueta_a_actualizada: Label = _jugador_a.get_node("EtiquetaNombre")
	print("Etiqueta de A tras reasignar en runtime (esperado 'Guerrero Nv.5'): %s" % etiqueta_a_actualizada.text)
	_reasignacion_en_runtime_ok = etiqueta_a_actualizada.text == "Guerrero Nv.5"


func _informar() -> bool:
	var exito := _nombres_iniciales_ok and _reasignacion_en_runtime_ok
	print("PRUEBA JUGADOR ETIQUETA NOMBRE %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
