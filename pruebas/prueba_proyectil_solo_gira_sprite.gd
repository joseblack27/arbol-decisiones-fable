# =============================================================================
# Prueba: al disparar un proyectil, solo el/los Sprite2D hijos deben rotar
# para mirar hacia la dirección del disparo — el nodo raíz (Area2D) tiene
# que quedarse en rotation=0 siempre. Antes rotaba el nodo entero, y con el
# sprite desplazado de su centro (offset para que coincida visualmente con
# el arte) eso hacía que el desplazamiento girara alrededor del origen —
# al disparar hacia la izquierda el sprite quedaba de cabeza/espejado en
# vez de solo "mirar" para el otro lado.
#   godot --headless --path . --script res://pruebas/prueba_proyectil_solo_gira_sprite.gd
# =============================================================================
extends SceneTree

func _process(_delta: float) -> bool:
	var atacante := Node2D.new()
	root.add_child(atacante)
	current_scene = atacante

	# ProyectilEsquirla: escena real con Sprite2D propio con offset.
	var proy = (load("res://escenas/habilidades/esquirla/ProyectilEsquirla.tscn") as PackedScene).instantiate()
	root.add_child(proy)
	proy.configurar(Vector2.LEFT, 1.0, 5, atacante, Enums.Habilidad.TipoDano.AGUA)

	var sprite: Sprite2D = proy.get_node("Sprite2D")
	var raiz_sin_girar := is_equal_approx(proy.rotation, 0.0)
	var sprite_girado := is_equal_approx(sprite.rotation, Vector2.LEFT.angle())
	print("Nodo raíz sin rotar tras disparar a la izquierda (esperado 0.0): %.4f" % proy.rotation)
	print("Sprite2D rotado hacia la dirección (esperado %.4f): %.4f" % [Vector2.LEFT.angle(), sprite.rotation])

	# Proyectil base (Proyectil.tscn) con ícono dinámico (SpriteIcono),
	# creado DESPUÉS de configurar() — también debe heredar la rotación.
	var proy_base = (load("res://escenas/habilidades/proyectil/Proyectil.tscn") as PackedScene).instantiate()
	root.add_child(proy_base)
	proy_base.configurar(Vector2.DOWN, 1.0, 5, atacante)
	proy_base.poner_textura_icono(load("res://icon.svg"))
	var icono: Sprite2D = proy_base.get_node("SpriteIcono")
	var raiz_base_sin_girar := is_equal_approx(proy_base.rotation, 0.0)
	var icono_girado := is_equal_approx(icono.rotation, Vector2.DOWN.angle())
	print("SpriteIcono (creado después de configurar) también rota (esperado %.4f): %.4f" % [
		Vector2.DOWN.angle(), icono.rotation,
	])

	var exito := raiz_sin_girar and sprite_girado and raiz_base_sin_girar and icono_girado
	print("PRUEBA PROYECTIL SOLO GIRA SPRITE %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
