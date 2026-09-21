# =============================================================================
# Regresión (bug reportado en juego real, 20 sep 2026, DESPUÉS de ya
# haberle subido el contraste al placeholder): "estos no se ven" -- las
# larvas/huevos de la Reina seguían invisibles en la práctica. Causa real:
# no era contraste, era tamaño -- 22x28px es más chico que un solo tile
# (32x32) y mucho más chico que una hormiga real en pantalla (guardián
# ~96x96px). Arreglo: escalar el placeholder x2.2 (~48x62px reales).
#   godot --headless --path . --script res://pruebas/prueba_huevo_hormiga_tamano_visible.gd
# =============================================================================
extends SceneTree

func _process(_delta: float) -> bool:
	var huevo = (load("res://escenas/objetos/huevo_hormiga/HuevoHormiga.tscn") as PackedScene).instantiate()
	root.add_child(huevo)

	var sprite: Sprite2D = huevo.get_node("Sprite2D")
	var tamano_real := Vector2(sprite.texture.get_size()) * sprite.scale

	# Más grande que un tile (32x32) en las dos dimensiones -- antes
	# (22x28, escala 1.0) el ancho ya perdía contra un solo tile.
	var mas_grande_que_un_tile := tamano_real.x > 32.0 and tamano_real.y > 32.0
	print("Tamaño real en pantalla del huevo (esperado > 32x32): %s (%s): %s" % [
		tamano_real, "más grande que un tile" if mas_grande_que_un_tile else "sigue siendo sub-tile", \
		mas_grande_que_un_tile])

	print("PRUEBA HUEVO HORMIGA TAMANO VISIBLE %s" % ("OK" if mas_grande_que_un_tile else "FALLIDA"))
	quit(0 if mas_grande_que_un_tile else 1)
	return true
