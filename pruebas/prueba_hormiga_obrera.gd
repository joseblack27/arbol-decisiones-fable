# =============================================================================
# Prueba de EnemigoHormigaObrera tras el rediseño de habilidades (14 sep
# 2026, pedido del usuario: "solo esas dos habilidades", sin escape):
# stats propios (HormigaObrera.tres), extiende Enemigo DIRECTO (ya no
# EnemigoLobo -- ese combo entero se reemplazó), kit de exactamente dos
# habilidades (Mordida + Mordida Ácida, nada de Carga/Proyectil/Arañazo),
# y sin rama de huida en el árbol.
#
# Sin tipo estático "EnemigoHormigaObrera" en ningún lado (ni siquiera para
# la variable ni para un "is"): referenciar por tipo una clase recién creada
# desde el propio script de entrada --script es justo lo que causó el
# cuelgue investigado en prueba_ticket_consumible_xp.gd (ver memoria del
# proyecto) -- duck typing evita el problema de raíz.
#   godot --headless --path . --script res://pruebas/prueba_hormiga_obrera.gd
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
	# Cargar Jugador.tscn PRIMERO fuerza que los autoloads (Utils,
	# GestorPiscinas, SeñalManager...) ya estén resueltos antes de tocar
	# cualquier habilidad de proyectil/piscina -- sin esto, el primer load
	# de este --script nuevo falla en silencio (ver memoria del proyecto).
	(load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	_mob = (load("res://escenas/enemigos/EnemigoHormigaObrera.tscn") as PackedScene).instantiate()
	root.add_child(_mob)


func _informar() -> bool:
	var guion_ok: bool = _mob.get_script() != null \
		and _mob.get_script().resource_path.ends_with("EnemigoHormigaObrera.gd")
	print("Script propio EnemigoHormigaObrera.gd (esperado true): %s" % guion_ok)

	# extends Enemigo directo, no EnemigoLobo -- get_base_script() sube un
	# nivel en la cadena de herencia del propio script (no confundir con
	# get_script(), que da el de la instancia).
	var base_ok: bool = _mob.get_script().get_base_script() != null \
		and _mob.get_script().get_base_script().resource_path.ends_with("Enemigo.gd")
	print("Extiende Enemigo directo, no EnemigoLobo (esperado true): %s" % base_ok)

	var datos_ok: bool = _mob.datos != null and _mob.datos.nombre_tipo == "Hormiga Obrera" \
		and _mob.datos.vida_maxima == 70.0
	print("EnemigoDatos propio (esperado true, 'Hormiga Obrera'/70 vida): %s" % datos_ok)

	var vida_aplicada: bool = is_equal_approx(_mob.componente_vida.obtener_vida(), 70.0)
	print("Vida real aplicada desde datos (esperado true, 70.0): %s (real=%.1f)" % [
		vida_aplicada, _mob.componente_vida.obtener_vida()])

	var sprite := _mob.get_node_or_null("Sprite2D") as Sprite2D
	var tinte_ok := sprite != null and not sprite.modulate.is_equal_approx(Color.WHITE)
	print("Sprite con tinte propio (esperado true): %s" % tinte_ok)

	var mordida: Node = _mob.get_node_or_null("Habilidades/HabilidadMordida")
	var mordida_acida: Node = _mob.get_node_or_null("Habilidades/HabilidadMordidaAcida")
	var kit_nuevo_ok: bool = mordida != null and mordida.get_script() != null \
		and mordida_acida != null and mordida_acida.get_script() != null
	print("Tiene Mordida + Mordida Ácida, con su script real (esperado true): %s" % kit_nuevo_ok)

	var sin_kit_viejo_ok: bool = _mob.get_node_or_null("Habilidades/HabilidadArañazo") == null \
		and _mob.get_node_or_null("Habilidades/HabilidadCarga") == null \
		and _mob.get_node_or_null("Habilidades/HabilidadProyectil") == null
	print("Sin Arañazo/Carga/Proyectil del Lobo (esperado true): %s" % sin_kit_viejo_ok)

	var sin_huida_ok: bool = _mob.get_node_or_null("ArbolComportamiento/Selector/SecuenciaHuida") == null
	print("Sin rama de huida en el árbol (esperado true): %s" % sin_huida_ok)

	var mordida_datos_ok: bool = mordida.datos != null \
		and mordida.datos.dano_base_min == 6 and mordida.datos.dano_base_max == 10
	print("Mordida tiene daño real configurado (esperado true, 6-10): %s" % mordida_datos_ok)

	var mordida_acida_ok: bool = is_equal_approx(mordida_acida.get("daño"), 6.0) \
		and is_equal_approx(mordida_acida.get("dano_por_tick"), 2.0) \
		and is_equal_approx(mordida_acida.get("factor_lentitud"), 0.8)
	print("Mordida Ácida tiene daño+veneno+lentitud configurados (esperado true): %s" % mordida_acida_ok)

	var exito := guion_ok and base_ok and datos_ok and vida_aplicada and tinte_ok \
		and kit_nuevo_ok and sin_kit_viejo_ok and sin_huida_ok and mordida_datos_ok and mordida_acida_ok
	print("PRUEBA HORMIGA OBRERA %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
