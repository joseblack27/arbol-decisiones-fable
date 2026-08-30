# =============================================================================
# Prueba de HabilidadComboGuardian: encadena varios golpes de área reales
# (GolpeBasico pooled) con una pausa entre cada uno — solo hace falta
# confirmar que el objetivo recibe MÁS de un golpe (no que se quedó en el
# primero), dejando correr fotogramas reales para que los timers entre
# golpes disparen de verdad.
#
# Sin tipos estáticos hacia HabilidadComboGuardian/GolpeBasico (ver cabecera
# de prueba_area_no_daña_aliados.gd) — todo por load() + duck typing.
#   godot --headless --path . --script res://pruebas/prueba_guardian_combo.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _jefe: CharacterBody2D
var _jugador: CharacterBody2D
var _vida_jugador: VidaComponente
var _combo


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		5:
			_combo.cantidad_golpes = 3
			_combo.dano_por_golpe = 10.0
			_combo.intervalo_entre_golpes = 0.1
			_combo.duracion_golpe = 0.1
			_combo._ejecutar(Vector2.RIGHT, 1.0)
		300:
			return _informar()
	return false


func _crear_entidad(pos: Vector2, grupo: String) -> CharacterBody2D:
	var e := CharacterBody2D.new()
	e.add_to_group(grupo)
	e.collision_layer = 2
	root.add_child(e)
	e.global_position = pos
	var vida = (load("res://componentes/VidaComponente.gd") as GDScript).new()
	vida.name = "VidaComponente"
	vida.salud_maxima = 200.0
	e.add_child(vida)
	vida.salud_actual = 200.0
	var forma := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 12.0
	forma.shape = circ
	vida.add_child(forma)
	return e


func _montar() -> void:
	var raiz := Node2D.new()
	root.add_child(raiz)
	current_scene = raiz

	_jefe = _crear_entidad(Vector2.ZERO, "enemigos")
	_jugador = _crear_entidad(Vector2(60, 0), "jugadores")
	_vida_jugador = _jugador.get_node("VidaComponente") as VidaComponente

	_combo = (load("res://escenas/habilidades/combo_guardian/HabilidadComboGuardian.gd") as GDScript).new()
	_combo.entidad_dueña = _jefe
	_combo.alcance_golpe = 60.0
	_combo.radio_golpe = 56.0
	_jefe.add_child(_combo)


func _informar() -> bool:
	var perdida := 200.0 - _vida_jugador.salud_actual
	# 3 golpes de 10 -> hasta 30 si conectan todos; alcanza con confirmar que
	# pegó MÁS de un golpe (>10), no que el primero solo.
	var exito := perdida > 10.0
	print("Combo conecta más de un golpe (esperado > 10 de daño total): %.1f" % perdida)
	print("PRUEBA GUARDIAN COMBO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
