# =============================================================================
# Regresión: "no todas las habilidades escriben su nombre" — el Amague
# resuelve a barrido o golpe verdadero SIN pasar por activar() (golpear()
# es estático, _golpear_unico() usa la hitbox pooled directo), así que la
# etiqueta se quedaba pegada en "Amague" sin decir en qué terminó. Ahora
# HabilidadAmagueGuardian._al_terminar_pose() reemite habilidad_activada
# a mano con el nombre real de lo que pasó.
#   godot --headless --path . --script res://pruebas/prueba_guardian_amague_etiqueta.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _jefe
var _etiqueta
var _amague

var _muestra_amague_al_arrancar_ok := false
var _actualiza_a_resultado_real_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		5:
			_amague.activar(Vector2.RIGHT, 1.0)
		6:
			_muestra_amague_al_arrancar_ok = _etiqueta.visible and _etiqueta.text == "Amague"
			print("Muestra 'Amague' al arrancar la pose (esperado true, texto='%s'): %s" % [
				_etiqueta.text, _muestra_amague_al_arrancar_ok])
			# Forzar la resolución directo (mismo id, sin esperar el timer
			# real de la pose — el mecanismo de pose+timer ya está probado
			# por separado, ver prueba_guardian_fase1_amague.gd).
			_amague.call("_al_terminar_pose", _amague._id_ataque, Vector2.RIGHT, null)
		7:
			var texto: String = _etiqueta.text
			_actualiza_a_resultado_real_ok = texto == "Amague (golpe verdadero)" \
				or texto == "Amague (barrido)"
			print("Se actualiza al resultado real, no se queda en 'Amague' (esperado true, texto='%s'): %s" % [
				texto, _actualiza_a_resultado_real_ok])
			return _informar()
	return false


func _montar() -> void:
	var raiz := Node2D.new()
	root.add_child(raiz)
	current_scene = raiz

	var escena_jefe := load("res://escenas/enemigos/EnemigoGuardianQuebrado.tscn")
	_jefe = escena_jefe.instantiate()
	raiz.add_child(_jefe)
	_jefe.global_position = Vector2.ZERO
	_etiqueta = _jefe.get_node("EtiquetaHabilidad")
	_amague = _jefe.get_node("Habilidades/HabilidadAmagueGuardian")


func _informar() -> bool:
	var exito := _muestra_amague_al_arrancar_ok and _actualiza_a_resultado_real_ok
	print("PRUEBA GUARDIAN AMAGUE ETIQUETA %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
