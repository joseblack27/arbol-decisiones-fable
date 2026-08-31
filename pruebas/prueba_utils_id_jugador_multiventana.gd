# =============================================================================
# Utils.id_jugador_local() — jugadores REALES (sin PIN) en la misma PC.
# Bug reportado: "se sobreescriben y se reinician cada rato" con 2 ventanas
# de Godot en la misma máquina — antes, sin PIN, las dos terminaban leyendo
# el MISMO user://id_jugador.txt (mismo id_unico), y el servidor expulsaba
# a la vieja apenas la nueva se conectaba (Jugador._expulsar_fantasma_de_
# la_misma_identidad), que reintentaba sola y expulsaba a la nueva a su
# vez — bucle infinito.
#
# CUIDADO: esta prueba toca archivos reales bajo user:// (no hay forma de
# aislarlo, Utils.id_jugador_local() está escrito para leer/escribir ESE
# directorio a propósito). Por eso: NUNCA toca id_jugador.txt (el archivo
# real del slot 0, la identidad de verdad de quien corre esto en su PC) —
# solo "ocupa" el LOCK del slot 0 con un heartbeat fresco (sin tocar su
# contenido) para forzar a esta prueba a caer en slots más altos, y borra
# TODO lo que creó al final (locks 0-3 y el id_jugador_3.txt nuevo).
#
# Verifica:
#   1. Con los slots 0, 1 y 2 "ocupados" (lock con timestamp fresco), una
#      llamada nueva a id_jugador_local() cae en el slot 3 — no revienta ni
#      reusa un slot ocupado.
#   2. Esa llamada deja un heartbeat fresco en el lock del slot que reclamó.
#   3. Un lock VIEJO (más viejo que la ventana de tolerancia) se trata como
#      abandonado — no bloquea el slot.
#   godot --headless --path . --script res://pruebas/prueba_utils_id_jugador_multiventana.gd
# =============================================================================
extends SceneTree

var _utils
var _id_reclamado := ""

var _cae_en_slot_libre_ok := false
var _heartbeat_fresco_al_reclamar_ok := false
var _lock_viejo_se_trata_como_libre_ok := false


func _process(_delta: float) -> bool:
	_utils = root.get_node("/root/Utils")
	_ocupar_slots_0_1_2()
	_probar_cae_en_slot_libre()
	_probar_lock_viejo_es_libre()
	_limpiar()
	return _informar()


func _ocupar_slots_0_1_2() -> void:
	var ahora := Time.get_unix_time_from_system()
	for slot in [0, 1, 2]:
		var archivo := FileAccess.open("user://id_jugador_%d.lock" % slot, FileAccess.WRITE)
		archivo.store_string(str(ahora))
		archivo.close()


func _probar_cae_en_slot_libre() -> void:
	_id_reclamado = _utils.id_jugador_local()
	var id_en_slot_3 := ""
	if FileAccess.file_exists("user://id_jugador_3.txt"):
		var archivo := FileAccess.open("user://id_jugador_3.txt", FileAccess.READ)
		id_en_slot_3 = archivo.get_as_text().strip_edges()
		archivo.close()
	_cae_en_slot_libre_ok = _id_reclamado != "" and _id_reclamado == id_en_slot_3
	print("Con slots 0/1/2 ocupados, id_jugador_local() cae en el slot 3 (esperado true): %s" \
		% _cae_en_slot_libre_ok)

	var lock_reciente := false
	if FileAccess.file_exists("user://id_jugador_3.lock"):
		var archivo := FileAccess.open("user://id_jugador_3.lock", FileAccess.READ)
		var texto := archivo.get_as_text().strip_edges()
		archivo.close()
		lock_reciente = (Time.get_unix_time_from_system() - texto.to_float()) < 2.0
	_heartbeat_fresco_al_reclamar_ok = lock_reciente
	print("El slot reclamado queda con un heartbeat fresco (esperado true): %s" \
		% _heartbeat_fresco_al_reclamar_ok)


func _probar_lock_viejo_es_libre() -> void:
	var viejo := Time.get_unix_time_from_system() - 100.0  # bien pasada la ventana de tolerancia.
	var archivo := FileAccess.open("user://id_jugador_5.lock", FileAccess.WRITE)
	archivo.store_string(str(viejo))
	archivo.close()
	_lock_viejo_se_trata_como_libre_ok = not _utils._lock_de_slot_activo("user://id_jugador_5.lock")
	print("Un lock viejo (100s) se trata como abandonado, no ocupado (esperado true): %s" \
		% _lock_viejo_se_trata_como_libre_ok)


func _limpiar() -> void:
	for ruta in [
		"user://id_jugador_0.lock", "user://id_jugador_1.lock", "user://id_jugador_2.lock",
		"user://id_jugador_3.lock", "user://id_jugador_3.txt", "user://id_jugador_5.lock",
	]:
		if FileAccess.file_exists(ruta):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))


func _informar() -> bool:
	var exito := _cae_en_slot_libre_ok and _heartbeat_fresco_al_reclamar_ok \
		and _lock_viejo_se_trata_como_libre_ok
	print("PRUEBA UTILS ID JUGADOR MULTIVENTANA %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
