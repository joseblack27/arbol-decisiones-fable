# =============================================================================
# Regresión (bug reportado en juego real, 20 sep 2026): "estos no se ven"
# -- las larvas/huevos de la Reina seguían invisibles en la práctica
# incluso después de subirle el contraste Y el tamaño al placeholder
# generado por código. Reemplazado por un sprite real
# (ant_larva_48x48_v4.png, asignado a mano en HuevoHormiga.tscn) --
# confirma que la escena usa ESE archivo real (no
# volvió a caer en el placeholder por algún desliz al asignarlo) y que el
# tamaño resultante sigue siendo más grande que un tile (32x32).
#   godot --headless --path . --script res://pruebas/prueba_huevo_hormiga_tamano_visible.gd
# =============================================================================
extends SceneTree

func _process(_delta: float) -> bool:
	var huevo = (load("res://escenas/objetos/huevo_hormiga/HuevoHormiga.tscn") as PackedScene).instantiate()
	root.add_child(huevo)

	var sprite: Sprite2D = huevo.get_node("Sprite2D")

	# Por NOMBRE de archivo, no ruta completa -- el usuario reorganizó
	# assets/sprites/ en subcarpetas (ant_larva_48x48_v4.png terminó en
	# assets/sprites/enemigos/) y una ruta hardcodeada quedaba obsoleta con
	# el primer reordenamiento del editor, aunque la escena siguiera
	# apuntando bien al archivo real.
	var usa_sprite_real := sprite.texture != null \
		and sprite.texture.resource_path.get_file() == "ant_larva_48x48_v4.png"
	print("Usa el sprite real de la larva, no el placeholder (esperado true, ruta=%s): %s" % [
		sprite.texture.resource_path if sprite.texture else "null", usa_sprite_real])

	var tamano_real := Vector2(sprite.texture.get_size()) * sprite.scale
	# Más grande que un tile (32x32) en las dos dimensiones.
	var mas_grande_que_un_tile := tamano_real.x > 32.0 and tamano_real.y > 32.0
	print("Tamaño real en pantalla del huevo (esperado > 32x32): %s (%s): %s" % [
		tamano_real, "más grande que un tile" if mas_grande_que_un_tile else "sigue siendo sub-tile", \
		mas_grande_que_un_tile])

	var exito := usa_sprite_real and mas_grande_que_un_tile
	print("PRUEBA HUEVO HORMIGA TAMANO VISIBLE %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
