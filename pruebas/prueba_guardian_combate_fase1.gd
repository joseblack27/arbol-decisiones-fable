# =============================================================================
# Prueba de integración: el Guardián Quebrado, con un jugador real cerca,
# lo detecta (VisionComponente), se acerca/ataca por su cuenta (Arbol de
# Comportamiento real, IA completa) y le baja la vida de verdad — primera
# vez que se prueba el pipeline entero de fase 1 de punta a punta, no cada
# pieza por separado.
#
# Se mide el MÍNIMO de vida observado a lo largo de toda la corrida, no solo
# la foto final: el Jugador.tscn real tiene regeneración pasiva de vida, que
# en varios segundos alcanza a tapar un daño chico contra una vida máxima
# artificialmente alta — comparar solo inicio vs. final daba un falso
# negativo (el árbol atacaba con éxito en TODOS los ticks, según el log de
# debug, pero la vida ya se había regenerado de vuelta para cuando se leía).
#   godot --headless --path . --script res://pruebas/prueba_guardian_combate_fase1.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _jefe
var _jugador
var _vida_jugador
var _vida_inicial := 0.0
var _vida_minima := 0.0


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas == 1:
		_montar()
	if _fotogramas == 2:
		_vida_inicial = _vida_jugador.salud_actual
		_vida_minima = _vida_inicial
	if _fotogramas >= 2:
		_vida_minima = minf(_vida_minima, _vida_jugador.salud_actual)
	if _fotogramas == 600:
		return _informar()
	return false


func _montar() -> void:
	var raiz := Node2D.new()
	root.add_child(raiz)
	current_scene = raiz

	var escena_jefe := load("res://escenas/enemigos/EnemigoGuardianQuebrado.tscn")
	_jefe = escena_jefe.instantiate()
	raiz.add_child(_jefe)
	_jefe.global_position = Vector2.ZERO

	var escena_jugador := load("res://escenas/jugador/Jugador.tscn") as PackedScene
	_jugador = escena_jugador.instantiate()
	_jugador.name = "1"
	raiz.add_child(_jugador)
	_jugador.global_position = Vector2(150, 0)
	_vida_jugador = _jugador.get_node("VidaComponente")
	_vida_jugador.salud_maxima = 100000.0
	_vida_jugador.salud_actual = 100000.0
	_vida_jugador.cancelar_invulnerabilidad()


func _informar() -> bool:
	var perdida: float = _vida_inicial - _vida_minima
	var exito: bool = perdida > 0.0
	print("Vida inicial del jugador: %.1f" % _vida_inicial)
	print("Vida mínima observada durante los 10s de combate real: %.1f" % _vida_minima)
	print("El jefe conectó daño real por su cuenta (esperado > 0): %.1f" % perdida)
	print("PRUEBA GUARDIAN COMBATE FASE1 %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
