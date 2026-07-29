# =============================================================================
# Prueba de la regresión reportada en juego real: "Invalid type... argument 1
# (previously freed)" en Combate.mismo_equipo al resolver un rebote — quien
# disparó murió y su nodo se liberó (queue_free) ANTES de que la cadena de
# rebotes terminara de resolverse. Mismo criterio que
# prueba_dot_fuente_liberada.gd: is_instance_valid(entidad_fuente) tanto en
# Proyectil._resolver_colision como en ProyectilRebote._al_impactar_de_verdad
# (antes de pasarlo a Combate.buscar_enemigo_mas_cercano) arreglan esto.
#
# Se libera al atacante justo DESPUÉS de disparar, con el proyectil todavía
# en vuelo sin haber golpeado a nadie — la cadena completa (A->B->C) debe
# seguir aplicando daño sin reventar aunque la fuente ya no exista para
# ninguno de los 3 golpes.
#   godot --headless --path . --script res://pruebas/prueba_rebote_fuente_liberada.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _atacante: Node2D
var _mob_a
var _mob_b
var _mob_c


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
	if _fotogramas == 6:
		# El atacante muere y se libera con el proyectil todavía volando,
		# antes de golpear a nadie — mismo momento que reportó el usuario
		# ("no se si fue que yo mori antes del ultimo rebote").
		_atacante.queue_free()
	if _fotogramas == 90:
		return _informar()
	return false


func _montar() -> void:
	_atacante = Node2D.new()
	_atacante.add_to_group("jugadores")
	root.add_child(_atacante)
	_atacante.global_position = Vector2.ZERO

	_mob_a = _crear_mob(Vector2(100, 0))
	_mob_b = _crear_mob(Vector2(100, 30))
	_mob_c = _crear_mob(Vector2(100, 60))


func _disparar() -> void:
	var proy = (load("res://escenas/habilidades/rebote/ProyectilRebote.tscn") as PackedScene).instantiate()
	root.add_child(proy)
	proy.global_position = _atacante.global_position
	proy.alcance_base = 400.0
	proy.configurar(Vector2.RIGHT, 1.0, 10.0, _atacante, Enums.Habilidad.TipoDano.FISICO)
	proy.preparar_rebotes(5, 200.0)


func _informar() -> bool:
	print("Golpes por mob (fuente liberada a mitad de vuelo) -> A:%d B:%d C:%d" % [
		_mob_a.golpes, _mob_b.golpes, _mob_c.golpes])
	var exito: bool = _mob_a.golpes == 1 and _mob_b.golpes == 1 and _mob_c.golpes == 1
	print("Rebota en cadena completa sin reventar aunque la fuente ya no exista (esperado true): %s" % exito)
	print("PRUEBA REBOTE FUENTE LIBERADA %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
