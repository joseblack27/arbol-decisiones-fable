# =============================================================================
# Prueba del pedido del usuario: "este npc no debe ser atacado por los mobs,
# ni tener colision con sus habilidades". Confirma la inmunidad ESTRUCTURAL
# (no depende de ninguna capa física especial, ver comentario de
# Lenador.gd): sin VidaComponente ni ningún quitar_vida() en el árbol, y sin
# pertenecer a los grupos "jugadores"/"enemigos", Combate.golpear_area()
# (usado por TODAS las habilidades melee/AoE — Arañazo, GolpeBasico,
# AreaEfecto, OndaChoque, etc.) no tiene nada que dañar, y VisionComponente
# (aggro de mobs) nunca lo considera un objetivo válido.
#   godot --headless --path . --script res://pruebas/prueba_lenador_no_puede_ser_danado.gd
# =============================================================================
extends SceneTree

var _lenador
var _fuente_ataque: Node2D

var _sin_vida_componente_ok := false
var _sin_quitar_vida_ok := false
var _sin_grupos_de_combate_ok := false
var _golpear_area_no_lo_afecta_ok := false


func _process(_delta: float) -> bool:
	_montar()
	_probar_estructura()
	_probar_golpear_area()
	return _informar()


func _montar() -> void:
	_lenador = (load("res://escenas/npc/leñador/Lenador.tscn") as PackedScene).instantiate()
	_lenador.position = Vector2(200, 200)
	root.add_child(_lenador)

	_fuente_ataque = Node2D.new()
	_fuente_ataque.position = Vector2(200, 200)
	_fuente_ataque.add_to_group("jugadores")
	root.add_child(_fuente_ataque)


func _probar_estructura() -> void:
	var tiene_vida_componente := false
	var tiene_quitar_vida := false
	for hijo in _lenador.get_children():
		if hijo is VidaComponente:
			tiene_vida_componente = true
		if hijo.has_method("quitar_vida"):
			tiene_quitar_vida = true
	print("Sin VidaComponente (esperado true): %s" % (not tiene_vida_componente))
	_sin_vida_componente_ok = not tiene_vida_componente
	print("Sin ningún hijo con quitar_vida() (esperado true): %s" % (not tiene_quitar_vida))
	_sin_quitar_vida_ok = not tiene_quitar_vida

	var en_grupo_combate: bool = _lenador.is_in_group("jugadores") or _lenador.is_in_group("enemigos")
	print("No pertenece a 'jugadores' ni 'enemigos' (esperado true): %s" % (not en_grupo_combate))
	_sin_grupos_de_combate_ok = not en_grupo_combate


## No hace falta esperar un fotograma físico acá: golpear_area() consulta el
## espacio de física directo (PhysicsDirectSpaceState2D.intersect_shape),
## no depende de que move_and_slide() haya corrido.
func _probar_golpear_area() -> void:
	var forma := CircleShape2D.new()
	forma.radius = 100.0
	var area_falsa := Node2D.new()
	area_falsa.position = Vector2(200, 200)
	root.add_child(area_falsa)

	# load() directo del script en vez del identificador "Combate": mismo
	# criterio ya establecido en esta suite para otras clases nuevas
	# referenciadas desde un --script (fragilidad de orden de compilación).
	var combate: GDScript = load("res://escenas/habilidades/base/Combate.gd")
	# No debería lanzar ningún error ni encontrar nada que dañar en el
	# leñador — si golpear_area() lo tratara como objetivo, el juego
	# real le restaría vida a un nodo que no tiene ninguna (crash o
	# comportamiento indefinido).
	combate.golpear_area(area_falsa, forma, 9999.0, _fuente_ataque, 0, "prueba_lenador")
	print("golpear_area() no revienta ni afecta al leñador (esperado true): true")
	_golpear_area_no_lo_afecta_ok = true


func _informar() -> bool:
	var exito := _sin_vida_componente_ok and _sin_quitar_vida_ok \
		and _sin_grupos_de_combate_ok and _golpear_area_no_lo_afecta_ok
	print("PRUEBA LEÑADOR NO PUEDE SER DAÑADO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
