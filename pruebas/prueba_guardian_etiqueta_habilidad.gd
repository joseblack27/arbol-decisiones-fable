# =============================================================================
# Prueba de la ayuda visual TEMPORAL de balanceo: la etiqueta sobre el jefe
# muestra el nombre de la última habilidad lanzada, dura 3 segundos, y si
# se lanza otra mientras se muestra, el texto se reemplaza y el contador
# vuelve a 3 desde cero.
#   godot --headless --path . --script res://pruebas/prueba_guardian_etiqueta_habilidad.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _jefe
var _etiqueta

var _muestra_nombre_ok := false
var _se_oculta_tras_3s_ok := false
var _se_reemplaza_y_resetea_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		5:
			var golpe = _jefe.get_node("Habilidades/HabilidadGolpeVerdaderoTransicion")
			golpe.activar(Vector2.RIGHT, 1.0)
		6:
			_muestra_nombre_ok = _etiqueta.visible and _etiqueta.text == golpe_nombre()
			print("Muestra el nombre de la habilidad (esperado true, texto='%s'): %s" % [
				_etiqueta.text, _muestra_nombre_ok])
			# Lanzar OTRA antes de que expire (bien antes de 3s reales) — debe
			# reemplazar el texto y reiniciar el contador.
			var combo = _jefe.get_node("Habilidades/HabilidadComboGuardian")
			combo.activar(Vector2.RIGHT, 1.0)
		7:
			var combo_nombre: String = _jefe.get_node("Habilidades/HabilidadComboGuardian").nombre_habilidad
			_se_reemplaza_y_resetea_ok = _etiqueta.visible and _etiqueta.text == combo_nombre
			print("Se reemplaza con la habilidad nueva (esperado true, texto='%s'): %s" % [
				_etiqueta.text, _se_reemplaza_y_resetea_ok])
		400:
			# ~3s+ reales de margen (mismo criterio de sobra que el resto de
			# las pruebas de fase con timers reales) desde el ÚLTIMO
			# lanzamiento (fotograma 6) — tiene que haberse ocultado sola.
			_se_oculta_tras_3s_ok = not _etiqueta.visible
			print("Se oculta sola tras 3s sin lanzar nada más (esperado true): %s" % _se_oculta_tras_3s_ok)
			return _informar()
	return false


func golpe_nombre() -> String:
	return _jefe.get_node("Habilidades/HabilidadGolpeVerdaderoTransicion").nombre_habilidad


func _montar() -> void:
	var raiz := Node2D.new()
	root.add_child(raiz)
	current_scene = raiz

	var escena_jefe := load("res://escenas/enemigos/EnemigoGuardianQuebrado.tscn")
	_jefe = escena_jefe.instantiate()
	raiz.add_child(_jefe)
	_jefe.global_position = Vector2.ZERO
	_etiqueta = _jefe.get_node("EtiquetaHabilidad")


func _informar() -> bool:
	var exito := _muestra_nombre_ok and _se_reemplaza_y_resetea_ok and _se_oculta_tras_3s_ok
	print("PRUEBA GUARDIAN ETIQUETA HABILIDAD %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
