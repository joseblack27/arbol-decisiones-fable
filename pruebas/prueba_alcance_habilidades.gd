# =============================================================================
# Prueba: TODA habilidad de proyectil tiene alcance configurado en su .tres.
#
# HabilidadProyectil.aplicar_datos() calcula su alcance como
# `d.alcance_metros * ESCALA_METROS_PIXEL`, y ese número se usa para DOS cosas:
#   • proy.alcance_base — cuánto viaja el proyectil.
#   • IndicadorApunte._draw_proyectil() — el corredor de apuntado.
#
# Si el .tres se crea sin "alcance_metros", queda en 0 y la habilidad no falla
# ruidosamente: simplemente no viaja y no dibuja nada. Pasó de verdad con la
# Marca detonable (reportado: "no sale el indicador"), y el indicador fue lo
# único que se notó — el proyectil tampoco salía.
#
# Se recorren TODOS los .tres de recursos/habilidades para que cualquier
# habilidad futura quede cubierta sin tener que acordarse de agregarla acá.
#   godot --headless --path . --script res://pruebas/prueba_alcance_habilidades.gd
# =============================================================================
extends SceneTree

const CARPETA := "res://recursos/habilidades"


func _process(_d: float) -> bool:
	var revisadas := 0
	var fallidas: Array[String] = []

	var dir := DirAccess.open(CARPETA)
	if dir == null:
		print("FALLO: no se pudo abrir %s" % CARPETA)
		quit(1)
		return true

	for archivo in dir.get_files():
		if not archivo.ends_with(".tres"):
			continue
		var datos = load("%s/%s" % [CARPETA, archivo])
		if datos == null or datos.escena == null:
			continue
		var hab = datos.escena.instantiate()
		# Sólo aplica a las que TIENEN alcance (las de proyectil). Un
		# self-buff como Escudo o Camuflaje no expone esta propiedad y no
		# tiene por qué llevar alcance.
		if not ("alcance_maximo" in hab):
			hab.free()
			continue
		hab.aplicar_datos(datos)
		revisadas += 1
		var alcance: float = hab.get("alcance_maximo")
		if alcance <= 0.0:
			fallidas.append("%s (alcance_metros=%d -> %.0f px)" % [
				archivo, datos.alcance_metros, alcance])
		else:
			print("  %-26s alcance = %.0f px" % [archivo, alcance])
		hab.free()

	print("Habilidades de proyectil revisadas: %d" % revisadas)
	for f in fallidas:
		print("  SIN ALCANCE: %s" % f)
	var exito := revisadas > 0 and fallidas.is_empty()
	print("PRUEBA ALCANCE HABILIDADES %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
