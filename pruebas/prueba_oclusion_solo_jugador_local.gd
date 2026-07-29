# =============================================================================
# Prueba de que DecoracionOcluible.gd solo se transparenta por el jugador
# LOCAL, nunca por otro jugador que pase detrás (bug reportado: el árbol
# se veía transparente en TODAS las pantallas apenas cualquiera quedaba
# detrás, revelando su posición a cualquiera con línea de vista).
#
# Arma una decoración real (StaticBody2D + Area2D + CollisionShape2D) y
# dos "jugadores" (CharacterBody2D con capa 8, la del cuerpo real —ver
# Enemigo.CAPA_OBSTACULOS_HABILIDAD/Jugador.tscn) para que la física real
# del motor detecte el solape — no se puede simular a mano, hace falta
# dejar correr varios fotogramas físicos de verdad.
#   godot --headless --path . --script res://pruebas/prueba_oclusion_solo_jugador_local.gd
# =============================================================================
extends SceneTree

const CAPA_CUERPO_JUGADOR := 8

var _decoracion
var _sprite: Sprite2D
var _jugador_local
var _jugador_ajeno
var _fotogramas := 0

var _alfa_con_jugador_local := 1.0
var _alfa_con_solo_ajeno := 1.0


static func _script_jugador_falso() -> GDScript:
	var guion := GDScript.new()
	guion.source_code = """
extends CharacterBody2D
var peer_id_dueño: int = -1
"""
	guion.reload()
	return guion


func _crear_jugador_falso(id_dueño: int, posicion: Vector2) -> Node:
	var cuerpo := CharacterBody2D.new()
	cuerpo.set_script(_script_jugador_falso())
	cuerpo.peer_id_dueño = id_dueño
	cuerpo.add_to_group("jugadores")
	cuerpo.collision_layer = CAPA_CUERPO_JUGADOR
	cuerpo.collision_mask = 0
	cuerpo.global_position = posicion
	var forma := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 8.0
	forma.shape = circ
	cuerpo.add_child(forma)
	root.add_child(cuerpo)
	return cuerpo


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		30:
			_alfa_con_jugador_local = _sprite.modulate.a
			# Ahora solo queda el jugador AJENO detrás (se saca al local).
			_jugador_local.queue_free()
		60:
			_alfa_con_solo_ajeno = _sprite.modulate.a
			return _informar()
	return false


func _montar() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(0)
	root.multiplayer.multiplayer_peer = peer
	var mi_id := root.multiplayer.get_unique_id()

	_decoracion = StaticBody2D.new()
	_decoracion.set_script(load("res://escenas/niveles/DecoracionOcluible.gd"))

	_sprite = Sprite2D.new()
	_decoracion.add_child(_sprite)

	var area := Area2D.new()
	var forma_area := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 40.0
	forma_area.shape = circ
	area.add_child(forma_area)
	_decoracion.add_child(area)

	# Asignar ANTES de entrar al árbol: _ready() corre apenas add_child() lo
	# mete en escena, y necesita sprite/area_oclusion ya en su lugar (si no,
	# se rinde temprano — ver el guard al principio de _ready()).
	_decoracion.sprite = _sprite
	_decoracion.area_oclusion = area
	_decoracion.global_position = Vector2(0, 100)
	root.add_child(_decoracion)

	# Detrás del árbol (Y menor que el de la decoración, 100) y dentro del
	# radio del área (40px) — ambos jugadores en la misma posición relativa,
	# la única diferencia es de quién es cada uno.
	_jugador_local = _crear_jugador_falso(mi_id, Vector2(0, 80))
	_jugador_ajeno = _crear_jugador_falso(mi_id + 999, Vector2(10, 80))


func _informar() -> bool:
	print("Alfa con el jugador LOCAL detrás (esperado <1.0, transparente): %.3f" % _alfa_con_jugador_local)
	print("Alfa con SOLO el jugador ajeno detrás (esperado 1.0, opaco): %.3f" % _alfa_con_solo_ajeno)

	var exito := _alfa_con_jugador_local < 0.9 and is_equal_approx(_alfa_con_solo_ajeno, 1.0)
	print("PRUEBA OCLUSION SOLO JUGADOR LOCAL %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
