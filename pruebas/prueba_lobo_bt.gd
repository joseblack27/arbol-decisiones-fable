# =============================================================================
# Prueba de humo del lobo refactorizado (solo BT, sin máquina de estados).
# Instancia EnemigoLobo, lo deja decidir ~4 segundos y verifica que deambula
# (se mueve solo) sin errores de script.
#   godot --headless --path . --script res://pruebas/prueba_lobo_bt.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _lobo: Node2D
var _posicion_inicial := Vector2.ZERO
var _se_movio := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas == 1:
		var escena := load("res://escenas/enemigos/EnemigoLobo.tscn") as PackedScene
		_lobo = escena.instantiate()
		root.add_child(_lobo)
		_lobo.global_position = Vector2(300, 300)
		_posicion_inicial = _lobo.global_position
		return false
	if _fotogramas > 10 and _lobo.global_position.distance_to(_posicion_inicial) > 15.0:
		_se_movio = true
	if _fotogramas > 250:
		var memoria = _lobo.get("memoria")
		print("Posición: %s -> %s" % [_posicion_inicial, _lobo.global_position])
		print("Se movió deambulando: %s" % _se_movio)
		print("Objetivo en memoria (debe ser <null>): %s" % str(memoria.obtener("objetivo")))
		print("PRUEBA LOBO %s" % ("OK" if _se_movio else "FALLIDA"))
		quit(0 if _se_movio else 1)
		return true
	return false
