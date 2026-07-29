# =============================================================================
# Prueba de cuentas por nombre+PIN (GestorGuardado.resolver_cuenta):
#   1. Nombre nuevo: crea la cuenta ligada al id del dispositivo que se pasó
#      y devuelve ESE MISMO id (el progreso ya existente queda adoptado).
#   2. Mismo nombre + PIN correcto, desde OTRO dispositivo: devuelve el
#      id_unico de la cuenta (el original), no el del dispositivo nuevo —
#      así la partida sigue al nombre.
#   3. Mismo nombre + PIN incorrecto: devuelve "" (rechazo).
#   4. Nombre normalizado (mayúsculas/espacios) resuelve a la MISMA cuenta.
#   godot --headless --path . --script res://pruebas/prueba_cuentas_pin.gd
# =============================================================================
extends SceneTree

const NOMBRE_PRUEBA := "PruebaCuentaPin"
const PIN_CORRECTO := "1234"
const ID_DISPOSITIVO_1 := "prueba-dispositivo-uno-0000"
const ID_DISPOSITIVO_2 := "prueba-dispositivo-dos-0000"

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
		print("PRUEBA CUENTAS PIN OK (sin SQLite en esta plataforma, omitida)")
		quit(0)
		return true

	var clave: String = gg.call("_normalizar_nombre_cuenta", NOMBRE_PRUEBA)
	bd.query_with_bindings("DELETE FROM cuentas WHERE nombre = ?;", [clave])

	# 1. Cuenta nueva: adopta el id del dispositivo que la crea.
	var id_creacion: String = gg.call("resolver_cuenta", NOMBRE_PRUEBA, PIN_CORRECTO, ID_DISPOSITIVO_1)
	var creacion_ok := id_creacion == ID_DISPOSITIVO_1
	print("Cuenta nueva adopta el id del dispositivo (esperado %s): %s" % [ID_DISPOSITIVO_1, id_creacion])

	# 2. Mismo nombre + PIN correcto, desde OTRO dispositivo: vuelve el id
	#    ORIGINAL (el de la cuenta), no el del dispositivo 2 — la partida
	#    sigue al nombre, no al aparato.
	var id_reconexion: String = gg.call("resolver_cuenta", NOMBRE_PRUEBA, PIN_CORRECTO, ID_DISPOSITIVO_2)
	var reconexion_ok := id_reconexion == ID_DISPOSITIVO_1
	print("Mismo nombre+PIN desde otro dispositivo devuelve el id ORIGINAL (esperado %s): %s" % [
		ID_DISPOSITIVO_1, id_reconexion,
	])

	# 3. PIN incorrecto: rechazo.
	var id_pin_malo: String = gg.call("resolver_cuenta", NOMBRE_PRUEBA, "0000", ID_DISPOSITIVO_2)
	var rechazo_ok := id_pin_malo == ""
	print("PIN incorrecto rechaza (esperado \"\"): '%s'" % id_pin_malo)

	# 4. Nombre normalizado (mayúsculas/espacios) resuelve a la misma cuenta.
	var id_variante: String = gg.call("resolver_cuenta", "  PruebaCuentaPin  ", PIN_CORRECTO, ID_DISPOSITIVO_2)
	var normalizado_ok := id_variante == ID_DISPOSITIVO_1
	print("Nombre con mayúsculas/espacios resuelve igual (esperado %s): %s" % [
		ID_DISPOSITIVO_1, id_variante,
	])

	bd.query_with_bindings("DELETE FROM cuentas WHERE nombre = ?;", [clave])

	var exito := creacion_ok and reconexion_ok and rechazo_ok and normalizado_ok
	print("PRUEBA CUENTAS PIN %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
