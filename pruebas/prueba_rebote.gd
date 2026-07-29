# =============================================================================
# Prueba de HabilidadRebote/ProyectilRebote (sin red): el proyectil pega al
# primer enemigo y, en vez de detenerse, sigue de largo hacia el enemigo
# válido más cercano que todavía no haya golpeado, hasta rebotes_maximos
# veces o hasta quedarse sin objetivos nuevos dentro de
# radio_busqueda_rebote.
#
# Geometría: MobA(100,0), MobB(100,30), MobC(100,60) en cadena (cada uno es
# el más cercano al punto de impacto anterior), y MobD(100,300) fuera de
# radio_busqueda_rebote (200) desde MobC — con rebotes_maximos=5 (de sobra)
# esto confirma que el rebote se corta por FALTA DE OBJETIVOS EN RANGO, no
# por agotar el contador, y que nunca vuelve a pegarle a un blanco ya
# golpeado.
#   godot --headless --path . --script res://pruebas/prueba_rebote.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _atacante: Node2D
var _mob_a
var _mob_b
var _mob_c
var _mob_d

var _golpeo_a_los_tres_en_cadena := false
var _no_golpeo_al_fuera_de_rango := false
var _nadie_golpeado_dos_veces := false


static func _script_mob() -> GDScript:
	var guion := GDScript.new()
	guion.source_code = """
extends CharacterBody2D
var golpes := 0
func quitar_vida(_cantidad: float, _f: Node = null, _t: int = 2, _cr: bool = false) -> void:
	golpes += 1
"""
	guion.reload()
	return guion


func _crear_mob(pos: Vector2) -> Node:
	var mob := CharacterBody2D.new()
	mob.set_script(_script_mob())
	mob.add_to_group("enemigos")
	mob.collision_layer = 2
	mob.global_position = pos
	root.add_child(mob)
	var forma := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 8.0
	forma.shape = circ
	mob.add_child(forma)
	return mob


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas == 1:
		_montar()
	if _fotogramas == 5:
		_disparar()
	if _fotogramas == 90:
		_verificar()
		return _informar()
	return false


func _montar() -> void:
	_atacante = Node2D.new()
	_atacante.add_to_group("jugadores")
	root.add_child(_atacante)
	current_scene = _atacante
	_atacante.global_position = Vector2.ZERO

	_mob_a = _crear_mob(Vector2(100, 0))
	_mob_b = _crear_mob(Vector2(100, 30))
	_mob_c = _crear_mob(Vector2(100, 60))
	_mob_d = _crear_mob(Vector2(100, 300))  # fuera de radio_busqueda_rebote (200) desde C.


func _disparar() -> void:
	var proy = (load("res://escenas/habilidades/rebote/ProyectilRebote.tscn") as PackedScene).instantiate()
	root.add_child(proy)
	proy.global_position = _atacante.global_position
	proy.alcance_base = 400.0
	proy.configurar(Vector2.RIGHT, 1.0, 10.0, _atacante, Enums.Habilidad.TipoDano.FISICO)
	proy.preparar_rebotes(5, 200.0)


func _verificar() -> void:
	print("Golpes por mob -> A:%d B:%d C:%d D:%d" % [_mob_a.golpes, _mob_b.golpes, _mob_c.golpes, _mob_d.golpes])
	_golpeo_a_los_tres_en_cadena = _mob_a.golpes == 1 and _mob_b.golpes == 1 and _mob_c.golpes == 1
	print("Rebota en cadena A->B->C, un golpe cada uno (esperado true): %s" % _golpeo_a_los_tres_en_cadena)
	_no_golpeo_al_fuera_de_rango = _mob_d.golpes == 0
	print("No llega al que está fuera de radio_busqueda_rebote (esperado true): %s" % _no_golpeo_al_fuera_de_rango)
	_nadie_golpeado_dos_veces = _mob_a.golpes <= 1 and _mob_b.golpes <= 1 and _mob_c.golpes <= 1 and _mob_d.golpes <= 1
	print("Ningún blanco golpeado dos veces (esperado true): %s" % _nadie_golpeado_dos_veces)


func _informar() -> bool:
	var exito := _golpeo_a_los_tres_en_cadena and _no_golpeo_al_fuera_de_rango and _nadie_golpeado_dos_veces
	print("PRUEBA REBOTE %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
