# =============================================================================
# Regresión: al entrar en fase 4 ("Quiebre"), el jefe ahora recarga TODAS
# sus habilidades multiplicador_furia_final (1.4) veces más rápido —
# mismo mecanismo que EnemigoArañaReina._activar_furia_final. Pedido del
# usuario: "una IA un poco más inteligente" (más agresivo en la fase
# final, no solo con habilidades nuevas).
#
# Baja la vida del jefe directo a fase 4 (sin pasar por fase 2/3 una por
# una, no hace falta para esto) y confirma que multiplicador_recarga
# queda en 1.4 en TODAS las habilidades del contenedor "Habilidades".
#   godot --headless --path . --script res://pruebas/prueba_guardian_furia_final.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _jefe
var _ok := true


func _process(_delta: float) -> bool:
	_fotogramas += 1
	# _on_vida_cambiada es un if/elif por FASE ACTUAL — una sola quitar_vida()
	# gigante solo cruzaría el primer umbral (_fase pasa a 2 recién ahí).
	# Hacen falta 3 golpes por separado, bien espaciados (cada _entrar_fase
	# deja invulnerabilidad por pausa_cambio_fase=1.3s ~78 fotogramas; 500
	# fotogramas de margen es de sobra, mismo criterio que prueba_guardian_
	# fase4.gd para el mismo problema).
	match _fotogramas:
		1:
			_montar()
			_jefe.get_node("VidaComponente").quitar_vida(750.0)  # 2200 -> 1450 (0.659) -> fase 2.
		500:
			_jefe.get_node("VidaComponente").quitar_vida(400.0)  # 1450 -> 1050 (0.477) -> fase 3.
		1000:
			_jefe.get_node("VidaComponente").quitar_vida(500.0)  # 1050 -> 550 (0.25) -> fase 4.
		1600:
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


func _informar() -> bool:
	var habilidades: Node = _jefe.get_node_or_null("Habilidades")
	if habilidades == null:
		_ok = false
	else:
		for hijo in habilidades.get_children():
			if hijo.has_method("puede_usarse") and "multiplicador_recarga" in hijo:
				var mult: float = hijo.multiplicador_recarga
				if mult != _jefe.multiplicador_furia_final:
					print("  -> %s quedó con multiplicador_recarga=%.2f (esperado %.2f)" % [
						hijo.name, mult, _jefe.multiplicador_furia_final])
					_ok = false
	print("Todas las habilidades quedan con multiplicador_recarga=%.1f al entrar Quiebre (esperado true): %s" % [
		_jefe.multiplicador_furia_final, _ok])
	print("PRUEBA GUARDIAN FURIA FINAL %s" % ("OK" if _ok else "FALLIDA"))
	quit(0 if _ok else 1)
	return true
