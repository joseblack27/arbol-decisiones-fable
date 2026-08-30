# =============================================================================
# Regresión: al ajustar rango_maximo de las habilidades de fase 1 (ver
# prueba_guardian_rango_vs_alcance.gd) quedó una "zona muerta" entre el
# alcance real de Atacar (ahora 140, el mayor entre Combo/Barrido/Amague) y
# distancia_ataque de Acercarse (seguía en 200, valor viejo): a esa
# distancia intermedia, Atacar se negaba a actuar (fuera de SU rango) pero
# Acercarse también se negaba a moverse (creía que ya estaba en rango) — el
# jefe se quedaba congelado para siempre, sin acercarse ni atacar, con el
# jugador QUIETO. Confirmado con un jefe real a 150px (justo en esa franja):
# se quedaba clavado sin moverse ni un pixel durante 5s reales.
#
# Esta prueba deja al jugador quieto exactamente en esa franja (150px, entre
# el 140 de Atacar y el 200 viejo de Acercarse) y confirma que el jefe se
# mueve de verdad hacia él en vez de congelarse.
#   godot --headless --path . --script res://pruebas/prueba_guardian_no_zona_muerta_acercamiento.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _jefe
var _jugador
var _distancia_inicial := 0.0


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas == 1:
		_montar()
		_distancia_inicial = _jefe.global_position.distance_to(_jugador.global_position)
	if _fotogramas == 120:
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
	var vida_jugador = _jugador.get_node("VidaComponente")
	vida_jugador.salud_maxima = 100000.0
	vida_jugador.salud_actual = 100000.0
	vida_jugador.cancelar_invulnerabilidad()


func _informar() -> bool:
	var distancia_final: float = _jefe.global_position.distance_to(_jugador.global_position)
	var se_acerco: bool = distancia_final < _distancia_inicial - 5.0
	print("Distancia inicial: %.1f" % _distancia_inicial)
	print("Distancia tras 2s (esperado que baje de verdad): %.1f" % distancia_final)
	print("PRUEBA GUARDIAN NO ZONA MUERTA ACERCAMIENTO %s" % ("OK" if se_acerco else "FALLIDA"))
	quit(0 if se_acerco else 1)
	return true
