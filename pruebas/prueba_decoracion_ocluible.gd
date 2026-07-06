# =============================================================================
# Prueba de DecoracionOcluible: un cuerpo del grupo "jugadores" DETRÁS de un
# árbol (más arriba en Y que su base) debe atenuarlo; al ponerse DELANTE
# (más abajo que la base), el árbol debe volver a ser opaco.
#   godot --headless --path . --script res://pruebas/prueba_decoracion_ocluible.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _decor: Node2D
var _cuerpo: CharacterBody2D
var _alfa_detras := 1.0
var _alfa_delante := 0.0


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		60:
			_alfa_detras = _alfa()
			# Ahora delante: por debajo de la base del árbol.
			_cuerpo.global_position = _decor.global_position + Vector2(0, 20)
		120:
			_alfa_delante = _alfa()
			print("Alfa con jugador detrás: %.2f (esperado ~0.45)" % _alfa_detras)
			print("Alfa con jugador delante: %.2f (esperado 1.0)" % _alfa_delante)
			var exito := _alfa_detras < 0.6 and _alfa_delante > 0.9
			print("PRUEBA OCLUSIÓN %s" % ("OK" if exito else "FALLIDA"))
			quit(0 if exito else 1)
			return true
	return false


func _alfa() -> float:
	return (_decor.get_node("Sprite2D") as Sprite2D).modulate.a


func _montar() -> void:
	var nivel := (load("res://niveles/NivelPradera.tscn") as PackedScene).instantiate()
	root.add_child(nivel)
	current_scene = nivel
	_decor = nivel.get_node("Decoraciones").get_child(0)

	_cuerpo = CharacterBody2D.new()
	_cuerpo.add_to_group("jugadores")
	var colision := CollisionShape2D.new()
	var forma := CircleShape2D.new()
	forma.radius = 10.0
	colision.shape = forma
	_cuerpo.add_child(colision)
	root.add_child(_cuerpo)
	# Detrás del árbol: dentro de su silueta, por encima de la base.
	_cuerpo.global_position = _decor.global_position + Vector2(0, -60)
	print("Árbol en %s, jugador detrás en %s" % [_decor.global_position, _cuerpo.global_position])
