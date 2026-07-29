# =============================================================================
# Prueba de DatosItem.id_recurso en los ítems equipables:
#   EquipoComponente._sincronizar_equipo_red() manda id_recurso al servidor
#   para reconstruir qué tiene puesto cada jugador (ver ese archivo) — un
#   ítem con id_recurso vacío se descarta en silencio del lado del
#   servidor: el equipo cambia solo en la vista previa del cliente, nunca
#   en el servidor real (bug reportado: "al desequipar/equipar un item no
#   se actualizan los atributos"). Verifica que TODOS los .tres equipables
#   tengan id_recurso seteado, apuntando a su propia ruta.
#   godot --headless --path . --script res://pruebas/prueba_id_recurso_equipables.gd
# =============================================================================
extends SceneTree

const _CARPETA := "res://recursos/items/equipables/"

func _process(_delta: float) -> bool:
	var dir := DirAccess.open(_CARPETA)
	if dir == null:
		print("PRUEBA ID_RECURSO EQUIPABLES FALLIDA (no se pudo abrir la carpeta)")
		quit(1)
		return true

	var archivos: Array[String] = []
	dir.list_dir_begin()
	var nombre := dir.get_next()
	while nombre != "":
		if nombre.ends_with(".tres"):
			archivos.append(nombre)
		nombre = dir.get_next()
	dir.list_dir_end()

	var todos_ok := true
	for archivo in archivos:
		var ruta := _CARPETA + archivo
		var item := load(ruta) as DatosItem
		var ok := item != null and item.id_recurso == ruta
		if not ok:
			todos_ok = false
		print("%s -> id_recurso='%s' (esperado '%s'): %s" % [
			archivo, item.id_recurso if item else "???", ruta, ok,
		])

	print("Total equipables revisados: %d" % archivos.size())
	print("PRUEBA ID_RECURSO EQUIPABLES %s" % ("OK" if todos_ok and archivos.size() > 0 else "FALLIDA"))
	quit(0 if (todos_ok and archivos.size() > 0) else 1)
	return true
