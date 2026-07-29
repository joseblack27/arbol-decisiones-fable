# =============================================================================
# Prueba de Utils.formatear_segundos() — helper compartido extraído de
# HabilidadAura (usado ahora también por EfectoVeneno y HabilidadCuracion)
# para que ninguna descripción de buff repita el bug ya encontrado en Aura:
# "%.0f" redondeaba un intervalo fraccionario (0.5) a un entero engañoso
# ("1s"). Verifica:
#   1. Un valor fraccionario (0.5) muestra su decimal ("0.5s").
#   2. Un valor redondo (1.0) muestra "1s" sin decimal (no "1.0s").
#   3. Otro valor redondo mayor (6.0) también sin decimal ("6s").
#   godot --headless --path . --script res://pruebas/prueba_utils_formatear_segundos.gd
# =============================================================================
extends SceneTree

func _process(_delta: float) -> bool:
	var utils = root.get_node("/root/Utils")

	var fraccionario: String = utils.formatear_segundos(0.5)
	var ok_fraccionario: bool = fraccionario == "0.5s"
	print("0.5 -> '0.5s' (esperado true): %s (\"%s\")" % [ok_fraccionario, fraccionario])

	var redondo: String = utils.formatear_segundos(1.0)
	var ok_redondo: bool = redondo == "1s"
	print("1.0 -> '1s' sin decimal (esperado true): %s (\"%s\")" % [ok_redondo, redondo])

	var redondo_mayor: String = utils.formatear_segundos(6.0)
	var ok_redondo_mayor: bool = redondo_mayor == "6s"
	print("6.0 -> '6s' sin decimal (esperado true): %s (\"%s\")" % [ok_redondo_mayor, redondo_mayor])

	var exito: bool = ok_fraccionario and ok_redondo and ok_redondo_mayor
	print("PRUEBA UTILS FORMATEAR SEGUNDOS %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
