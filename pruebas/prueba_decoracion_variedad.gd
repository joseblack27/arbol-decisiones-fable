# =============================================================================
# Prueba de la nueva variedad de decoración: confirma que las decoraciones
# nuevas existen, están dentro de los límites del nivel y no se superponen
# con ningún enemigo ni con el punto de aparición.
#   godot --headless --path . --script res://pruebas/prueba_decoracion_variedad.gd
# =============================================================================
extends SceneTree

const DISTANCIA_MINIMA := 60.0


func _initialize() -> void:
	var fallos := 0
	fallos += _revisar_nivel("res://escenas/niveles/NivelPradera.tscn",
		["Arbusto1", "Arbusto2", "Tocon1", "Roca1", "Hongo1", "Arbolito1"])
	fallos += _revisar_nivel("res://escenas/niveles/NivelCueva.tscn", ["Roca1", "Roca2", "Hongo1"])
	print("PRUEBA VARIEDAD DECORACION %s" % ("OK" if fallos == 0 else "FALLIDA"))
	quit(0 if fallos == 0 else 1)


func _revisar_nivel(ruta: String, nombres: Array) -> int:
	var nivel := (load(ruta) as PackedScene).instantiate()
	root.add_child(nivel)
	var fallos := 0
	var limites: Rect2 = (nivel as NivelBase).limites_camara()
	var puntos_ocupados: Array[Vector2] = []
	var aparicion := (nivel as NivelBase).punto_aparicion()
	if aparicion != null:
		puntos_ocupados.append(aparicion.global_position)
	var enemigos := nivel.get_node_or_null("Enemigos")
	if enemigos != null:
		for hijo in enemigos.get_children():
			puntos_ocupados.append(hijo.global_position)

	var contenedor := nivel.get_node_or_null("Decoraciones")
	if contenedor == null:
		print("%s: FALLO, sin nodo Decoraciones." % ruta)
		nivel.free()
		return 1

	for nombre in nombres:
		var decor := contenedor.get_node_or_null(nombre)
		if decor == null:
			print("%s: FALLO, falta '%s'." % [ruta, nombre])
			fallos += 1
			continue
		if not limites.has_point(decor.global_position):
			print("%s: FALLO, '%s' fuera de límites (%s)." % [ruta, nombre, decor.global_position])
			fallos += 1
		for punto in puntos_ocupados:
			if decor.global_position.distance_to(punto) < DISTANCIA_MINIMA:
				print("%s: FALLO, '%s' demasiado cerca de %s." % [ruta, nombre, punto])
				fallos += 1

	print("%s: %d decoraciones nuevas verificadas, %d fallos." % [ruta, nombres.size(), fallos])
	nivel.free()
	return fallos
