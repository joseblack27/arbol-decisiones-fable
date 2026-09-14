# =============================================================================
# Prueba de EnemigoHormigaSoldado: confirma que el reskin de EnemigoLoboFeroz
# quedó bien armado -- stats propios (HormigaSoldado.tres), sprite con tinte
# propio, y el combo arañazo+carga intacto (mismo comportamiento que Lobo
# Feroz, ya probado aparte -- acá solo se verifica que el reskin no rompió
# nada).
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

	var datos_ok: bool = _mob.datos != null and _mob.datos.nombre_tipo == "Hormiga Soldado" \
		and _mob.datos.vida_maxima == 180.0
	print("EnemigoDatos propio (esperado true, 'Hormiga Soldado'/180 vida): %s" % datos_ok)

	var vida_aplicada: bool = is_equal_approx(_mob.componente_vida.obtener_vida(), 180.0)
	print("Vida real aplicada desde datos (esperado true, 180.0): %s (real=%.1f)" % [
		vida_aplicada, _mob.componente_vida.obtener_vida()])

	var sprite := _mob.get_node_or_null("Sprite2D") as Sprite2D
	var tinte_ok := sprite != null and not sprite.modulate.is_equal_approx(Color.WHITE)
	print("Sprite con tinte propio, distinto del Lobo Feroz sin tintar (esperado true): %s" % tinte_ok)

	var arañazo: Node = _mob.get_node_or_null("Habilidades/HabilidadArañazo")
	var carga: Node = _mob.get_node_or_null("Habilidades/HabilidadCarga")
	var kit_ok: bool = arañazo != null and arañazo.get_script() != null \
		and carga != null and carga.get_script() != null
	print("Conserva Arañazo + Carga del Lobo Feroz, con su script real (esperado true): %s" % kit_ok)

	var exito := guion_ok and datos_ok and vida_aplicada and tinte_ok and kit_ok
	print("PRUEBA HORMIGA SOLDADO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
