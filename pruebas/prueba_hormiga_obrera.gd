# =============================================================================
# Prueba de EnemigoHormigaObrera: confirma que el reskin de EnemigoLobo quedó
# bien armado -- stats propios (HormigaObrera.tres), sprite con tinte propio,
# y el combo arañazo+carga intacto (mismo comportamiento que Lobo, ya
# probado aparte -- acá solo se verifica que el reskin no rompió nada).
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

	var datos_ok: bool = _mob.datos != null and _mob.datos.nombre_tipo == "Hormiga Obrera" \
		and _mob.datos.vida_maxima == 70.0
	print("EnemigoDatos propio (esperado true, 'Hormiga Obrera'/70 vida): %s" % datos_ok)

	var vida_aplicada: bool = is_equal_approx(_mob.componente_vida.obtener_vida(), 70.0)
	print("Vida real aplicada desde datos (esperado true, 70.0): %s (real=%.1f)" % [
		vida_aplicada, _mob.componente_vida.obtener_vida()])

	var sprite := _mob.get_node_or_null("Sprite2D") as Sprite2D
	var tinte_ok := sprite != null and not sprite.modulate.is_equal_approx(Color.WHITE)
	print("Sprite con tinte propio, distinto del Lobo sin tintar (esperado true): %s" % tinte_ok)

	var arañazo: Node = _mob.get_node_or_null("Habilidades/HabilidadArañazo")
	var carga: Node = _mob.get_node_or_null("Habilidades/HabilidadCarga")
	var kit_ok: bool = arañazo != null and arañazo.get_script() != null \
		and carga != null and carga.get_script() != null
	print("Conserva Arañazo + Carga del Lobo, con su script real (esperado true): %s" % kit_ok)

	var exito := guion_ok and datos_ok and vida_aplicada and tinte_ok and kit_ok
	print("PRUEBA HORMIGA OBRERA %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
