# =============================================================================
# Prueba de EnemigoHormigaSoldado tras el rediseño de habilidades (14 sep
# 2026, pedido del usuario: "solo esas dos habilidades", sin escape):
# stats propios (HormigaSoldado.tres), extiende Enemigo DIRECTO (ya no
# EnemigoLoboFeroz -- ese combo+esquiva reactiva entero se reemplazó), kit
# de exactamente dos habilidades (Mordida + Mordida Ácida, nada de Carga/
# Proyectil/Arañazo/Parpadeo), y sin rama de huida en el árbol.
#
# Sin tipo estático "EnemigoHormigaSoldado" en ningún lado: mismo criterio
# que prueba_hormiga_obrera.gd (ver ese comentario) -- duck typing evita el
# cuelgue de compilación ya documentado en la memoria del proyecto.
#   godot --headless --path . --script res://pruebas/prueba_hormiga_soldado.gd
# =============================================================================
extends SceneTree

var _mob
var _fotogramas := 0


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas == 1:
		_montar()
		return false
	if _fotogramas < 3:
		return false
	return _informar()


func _montar() -> void:
	(load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	_mob = (load("res://escenas/enemigos/EnemigoHormigaSoldado.tscn") as PackedScene).instantiate()
	root.add_child(_mob)


func _informar() -> bool:
	var guion_ok: bool = _mob.get_script() != null \
		and _mob.get_script().resource_path.ends_with("EnemigoHormigaSoldado.gd")
	print("Script propio EnemigoHormigaSoldado.gd (esperado true): %s" % guion_ok)

	var base_ok: bool = _mob.get_script().get_base_script() != null \
		and _mob.get_script().get_base_script().resource_path.ends_with("Enemigo.gd")
	print("Extiende Enemigo directo, no EnemigoLoboFeroz (esperado true): %s" % base_ok)

	var datos_ok: bool = _mob.datos != null and _mob.datos.nombre_tipo == "Hormiga Soldado" \
		and _mob.datos.vida_maxima == 180.0
	print("EnemigoDatos propio (esperado true, 'Hormiga Soldado'/180 vida): %s" % datos_ok)

	var vida_aplicada: bool = is_equal_approx(_mob.componente_vida.obtener_vida(), 180.0)
	print("Vida real aplicada desde datos (esperado true, 180.0): %s (real=%.1f)" % [
		vida_aplicada, _mob.componente_vida.obtener_vida()])

	# Pedido del usuario (18 sep 2026): mismo spritesheet que la Obrera, sin
	# el tinte oscuro/rojizo que traía de fábrica -- distinto de la Obrera,
	# que sí conserva su propio tinte.
	var sprite := _mob.get_node_or_null("Sprite2D") as Sprite2D
	var sin_tinte_ok := sprite != null and sprite.modulate.is_equal_approx(Color.WHITE)
	print("Sprite SIN tinte, color natural del spritesheet (esperado true): %s" % sin_tinte_ok)

	var obrera := (load("res://escenas/enemigos/EnemigoHormigaObrera.tscn") as PackedScene).instantiate()
	var sprite_obrera := obrera.get_node("Sprite2D") as Sprite2D
	var mismo_sprite_ok := sprite.texture == sprite_obrera.texture \
		and sprite.hframes == sprite_obrera.hframes and sprite.vframes == sprite_obrera.vframes
	print("Usa el mismo spritesheet que la Obrera (esperado true): %s" % mismo_sprite_ok)
	obrera.queue_free()

	var mordida: Node = _mob.get_node_or_null("Habilidades/HabilidadMordida")
	var mordida_acida: Node = _mob.get_node_or_null("Habilidades/HabilidadMordidaAcida")
	var kit_nuevo_ok: bool = mordida != null and mordida.get_script() != null \
		and mordida_acida != null and mordida_acida.get_script() != null
	print("Tiene Mordida + Mordida Ácida, con su script real (esperado true): %s" % kit_nuevo_ok)

	var sin_kit_viejo_ok: bool = _mob.get_node_or_null("Habilidades/HabilidadArañazo") == null \
		and _mob.get_node_or_null("Habilidades/HabilidadCarga") == null \
		and _mob.get_node_or_null("Habilidades/HabilidadProyectil") == null \
		and _mob.get_node_or_null("Habilidades/HabilidadParpadeo") == null
	print("Sin Arañazo/Carga/Proyectil/Parpadeo del Lobo Feroz (esperado true): %s" % sin_kit_viejo_ok)

	var sin_huida_ok: bool = _mob.get_node_or_null("ArbolComportamiento/Selector/SecuenciaHuida") == null
	print("Sin rama de huida en el árbol (esperado true): %s" % sin_huida_ok)

	var mordida_datos_ok: bool = mordida.datos != null \
		and mordida.datos.dano_base_min == 12 and mordida.datos.dano_base_max == 18
	print("Mordida tiene daño real configurado (esperado true, 12-18): %s" % mordida_datos_ok)

	var mordida_acida_ok: bool = is_equal_approx(mordida_acida.get("daño"), 10.0) \
		and is_equal_approx(mordida_acida.get("dano_por_tick"), 4.0) \
		and is_equal_approx(mordida_acida.get("factor_lentitud"), 0.8)
	print("Mordida Ácida tiene daño+veneno+lentitud configurados (esperado true): %s" % mordida_acida_ok)

	var exito := guion_ok and base_ok and datos_ok and vida_aplicada and sin_tinte_ok and mismo_sprite_ok \
		and kit_nuevo_ok and sin_kit_viejo_ok and sin_huida_ok and mordida_datos_ok and mordida_acida_ok
	print("PRUEBA HORMIGA SOLDADO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
