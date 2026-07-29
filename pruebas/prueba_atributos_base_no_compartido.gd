# =============================================================================
# Prueba de que AtributosComponente.base NO se comparte entre distintas
# instancias de Jugador.tscn — hallazgo relacionado al bug "gravísimo" de
# energía compartida entre jugadores: un sub-resource EMBEBIDO en una
# escena sin resource_local_to_scene=true se comparte —el MISMO objeto en
# memoria— entre TODAS las instancias de esa escena vivas en el mismo
# proceso (el servidor dedicado, que tiene a todos los jugadores
# conectados a la vez).
#
# AtributosComponente.recalcular_con_equipo() (ver ese archivo) MUTA
# "base" en su sitio A PROPÓSITO (para que quien ya tenga una referencia
# cacheada vea el cambio reflejado) — si el recurso fuera compartido entre
# jugadores, equipar un ítem o subir de nivel en UN jugador pisaría el
# daño/defensa/crítico/resistencias/regeneración de TODOS los demás.
# Jugador.tscn embebía este sub-resource sin el flag — se agregó acá.
#   godot --headless --path . --script res://pruebas/prueba_atributos_base_no_compartido.gd
# =============================================================================
extends SceneTree

var _jugador_a
var _jugador_b
var _fotogramas := 0


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			return _informar()
	return false


func _montar() -> void:
	var escena := load("res://escenas/jugador/Jugador.tscn") as PackedScene
	_jugador_a = escena.instantiate()
	_jugador_b = escena.instantiate()
	root.add_child(_jugador_a)
	root.add_child(_jugador_b)


func _informar() -> bool:
	var atrib_a := _jugador_a.get_node("AtributosComponente") as AtributosComponente
	var atrib_b := _jugador_b.get_node("AtributosComponente") as AtributosComponente

	var recursos_distintos := atrib_a.base != atrib_b.base
	print("AtributosBase de jugador A y B son objetos DISTINTOS (esperado true): %s" % recursos_distintos)

	var danos_originales_b := atrib_b.base.danos
	atrib_a.base.danos += 999.0
	var no_se_contagia := is_equal_approx(atrib_b.base.danos, danos_originales_b)
	print("Mutar el daño base de A NO afecta el de B (esperado true): %s" % no_se_contagia)

	var exito := recursos_distintos and no_se_contagia
	print("PRUEBA ATRIBUTOS BASE NO COMPARTIDO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
