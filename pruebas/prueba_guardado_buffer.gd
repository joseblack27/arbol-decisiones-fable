# =============================================================================
# Prueba del buffer de guardado del servidor (patrón buffer-adelante/base-
# atrás): un snapshot recibido queda en memoria (_snapshots_pendientes) y
# _volcar_pendientes() lo escribe a la base SQLite y vacía el buffer.
# También: volcar_peer de un id sin snapshot pendiente no revienta.
#   godot --headless --path . --script res://pruebas/prueba_guardado_buffer.gd
# =============================================================================
extends SceneTree

const ID_PRUEBA := "prueba-buffer-0000-0000"

var _fotogramas := 0


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas == 5:
		return _probar()
	return false


func _probar() -> bool:
	var gg := root.get_node("/root/GestorGuardado")
	var bd = gg.call("_bd_red")
	if bd == null:
		# Sin el GDExtension de SQLite no hay nada que probar acá (pasa en
		# plataformas sin binario nativo — ver GestorGuardado._bd_red).
		print("PRUEBA GUARDADO BUFFER OK (sin SQLite en esta plataforma, omitida)")
		quit(0)
		return true

	# Limpiar restos de corridas anteriores.
	bd.query_with_bindings("DELETE FROM partidas WHERE id_unico = ?;", [ID_PRUEBA])

	var texto := JSON.stringify({"version": 1, "xp_total": 777})
	gg.get("_snapshots_pendientes")[ID_PRUEBA] = {"nombre": "PruebaBuffer", "texto": texto}

	# Antes de volcar: la base NO debe tener la fila (sigue solo en memoria).
	bd.query_with_bindings("SELECT datos_json FROM partidas WHERE id_unico = ?;", [ID_PRUEBA])
	var antes_vacio: bool = bd.query_result.is_empty()

	gg.call("_volcar_pendientes")

	bd.query_with_bindings("SELECT datos_json FROM partidas WHERE id_unico = ?;", [ID_PRUEBA])
	var fila_ok: bool = not bd.query_result.is_empty() \
		and bd.query_result[0]["datos_json"] == texto
	var buffer_vacio: bool = gg.get("_snapshots_pendientes").is_empty()

	# volcar_peer con un peer inexistente: no debe reventar ni escribir nada.
	gg.call("volcar_peer", 999999)

	# Limpieza final.
	bd.query_with_bindings("DELETE FROM partidas WHERE id_unico = ?;", [ID_PRUEBA])

	print("Antes de volcar, fila ausente en la BD (esperado true): %s" % antes_vacio)
	print("Tras volcar, fila presente y con el JSON exacto (esperado true): %s" % fila_ok)
	print("Buffer vacío tras el volcado (esperado true): %s" % buffer_vacio)
	var exito := antes_vacio and fila_ok and buffer_vacio
	print("PRUEBA GUARDADO BUFFER %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
