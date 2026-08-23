# =============================================================================
# Prueba de ProyectilFlechaCazador.gd — pedido explícito del usuario: "la
# flecha del cazador no debe hacerle daño al jugador". El Cazador no está
# en ningún grupo "jugadores"/"enemigos" (inmunidad a todo aggro, ver
# Cazador.gd), así que Combate.mismo_equipo() nunca da true contra nadie —
# sin este filtro, una flecha que de casualidad tocara a un jugador parado
# en la línea de tiro (entre el cazador y el ratón) le haría daño real.
#
# Geometría: un jugador de mentira DIRECTO en la línea de tiro (más cerca
# que el mob), y un mob de mentira detrás — si la flecha lo ignorara mal,
# ninguno de los dos recibiría el golpe (la flecha se detendría en el
# jugador sin aplicar daño, pero sin seguir de largo). Confirma las DOS
# cosas: que el jugador queda ileso Y que la flecha sigue de largo y sí le
# pega al mob real detrás.
#   godot --headless --path . --script res://pruebas/prueba_flecha_cazador_no_dana_jugador.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _cazador: Node2D
var _jugador
var _mob

var _jugador_ileso := false
var _mob_recibio_el_golpe := false


static func _script_objetivo() -> GDScript:
	var guion := GDScript.new()
	guion.source_code = """
extends CharacterBody2D
var golpes := 0
func quitar_vida(_cantidad: float, _f: Node = null, _t: int = 2, _cr: bool = false) -> void:
	golpes += 1
"""
	guion.reload()
	return guion


func _crear_objetivo(pos: Vector2, grupo: String) -> Node:
	var objetivo := CharacterBody2D.new()
	objetivo.set_script(_script_objetivo())
	objetivo.add_to_group(grupo)
	objetivo.collision_layer = 1
	objetivo.global_position = pos
	root.add_child(objetivo)
	var forma := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 8.0
	forma.shape = circ
	objetivo.add_child(forma)
	return objetivo


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas == 1:
		_montar()
	if _fotogramas == 5:
		_disparar()
	if _fotogramas == 90:
		return _informar()
	return false


func _montar() -> void:
	_cazador = Node2D.new()
	root.add_child(_cazador)
	current_scene = _cazador
	_cazador.global_position = Vector2.ZERO

	# El jugador queda MÁS CERCA que el mob, directo en la línea de tiro —
	# si la flecha lo detuviera (en vez de ignorarlo y seguir de largo), el
	# mob de atrás nunca recibiría el disparo.
	_jugador = _crear_objetivo(Vector2(100, 0), "jugadores")
	_mob = _crear_objetivo(Vector2(200, 0), "enemigos")


func _disparar() -> void:
	var proy := (load("res://escenas/habilidades/flecha/ProyectilFlechaCazador.tscn") as PackedScene).instantiate()
	root.add_child(proy)
	proy.global_position = _cazador.global_position
	proy.alcance_base = 400.0
	proy.configurar(Vector2.RIGHT, 1.0, 10.0, _cazador, Enums.Habilidad.TipoDano.FISICO)


func _informar() -> bool:
	print("Golpes -> jugador:%d mob:%d" % [_jugador.golpes, _mob.golpes])

	_jugador_ileso = _jugador.golpes == 0
	print("El jugador en la línea de tiro queda ileso (esperado true): %s" % _jugador_ileso)

	_mob_recibio_el_golpe = _mob.golpes == 1
	print("La flecha sigue de largo y le pega al mob real (esperado true): %s" % _mob_recibio_el_golpe)

	var exito := _jugador_ileso and _mob_recibio_el_golpe
	print("PRUEBA FLECHA CAZADOR NO DAÑA JUGADOR %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
