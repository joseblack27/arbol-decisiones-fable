# =============================================================================
# Prueba de humo: NivelSantuarioGuardian.tscn instancia sin errores y el
# Guardián Quebrado está colocado en la ruta esperada (Enemigos/
# EnemigoGuardianQuebrado), vivo desde el primer fotograma.
#   godot --headless --path . --script res://pruebas/prueba_guardian_nivel_carga.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _nivel


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas == 1:
		_montar()
	if _fotogramas == 30:
		return _informar()
	return false


var _nivel_pradera


func _montar() -> void:
	var escena := load("res://escenas/niveles/NivelSantuarioGuardian.tscn")
	_nivel = escena.instantiate()
	root.add_child(_nivel)
	current_scene = _nivel

	var escena_pradera := load("res://escenas/niveles/NivelPradera.tscn")
	_nivel_pradera = escena_pradera.instantiate()
	root.add_child(_nivel_pradera)


func _informar() -> bool:
	var jefe = _nivel.get_node_or_null("Enemigos/EnemigoGuardianQuebrado")
	var portal_salida = _nivel.get_node_or_null("PortalAPradera")
	var punto_aparicion = _nivel.get_node_or_null("PuntoAparicion")
	var portal_entrada = _nivel_pradera.get_node_or_null("PortalASantuarioGuardian")

	var jefe_ok: bool = jefe != null and is_instance_valid(jefe) and not jefe.esta_muerto()
	print("Jefe colocado y vivo en Enemigos/EnemigoGuardianQuebrado (esperado true): %s" % jefe_ok)

	var nombre_nivel_ok: bool = _nivel.nombre_nivel == "Santuario del Guardián Quebrado"
	print("Nombre del nivel correcto (esperado true): %s" % nombre_nivel_ok)

	var portal_salida_ok: bool = portal_salida != null \
		and portal_salida.ruta_nivel_destino == "res://escenas/niveles/NivelPradera.tscn"
	print("Portal de salida hacia Pradera presente (esperado true): %s" % portal_salida_ok)

	var portal_entrada_ok: bool = portal_entrada != null \
		and portal_entrada.ruta_nivel_destino == "res://escenas/niveles/NivelSantuarioGuardian.tscn"
	print("Portal de entrada desde Pradera presente (esperado true): %s" % portal_entrada_ok)

	var punto_aparicion_ok := punto_aparicion != null
	print("Punto de aparición presente (esperado true): %s" % punto_aparicion_ok)

	var exito := jefe_ok and nombre_nivel_ok and portal_salida_ok and portal_entrada_ok and punto_aparicion_ok
	print("PRUEBA GUARDIAN NIVEL CARGA %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
