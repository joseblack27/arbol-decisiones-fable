# =============================================================================
# Regresión: al entrar en fase 4 ("Quiebre Final"), el Heraldo de la
# Corrupción recarga TODAS sus habilidades multiplicador_furia_final (1.4)
# veces más rápido — mismo mecanismo que las 2 ramas anteriores. Mirror
# exacto de prueba_forja_furia_final.gd.
#   godot --headless --path . --script res://pruebas/prueba_corrupcion_furia_final.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _jefe
var _ok := true


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
			_jefe.get_node("VidaComponente").quitar_vida(700.0)  # 2400 -> 1700 (0.708) -> fase 2.
		500:
			_jefe.get_node("VidaComponente").quitar_vida(600.0)  # 1700 -> 1100 (0.458) -> fase 3.
		1000:
			_jefe.get_node("VidaComponente").quitar_vida(600.0)  # 1100 -> 500 (0.208) -> fase 4.
		1600:
			return _informar()
	return false


func _montar() -> void:
	var raiz := Node2D.new()
	root.add_child(raiz)
	current_scene = raiz

	_jefe = (load("res://escenas/enemigos/EnemigoHeraldoCorrupcion.tscn") as PackedScene).instantiate()
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
	print("Todas las habilidades quedan con multiplicador_recarga=%.1f al entrar Quiebre Final (esperado true): %s" % [
		_jefe.multiplicador_furia_final, _ok])
	print("PRUEBA CORRUPCION FURIA FINAL %s" % ("OK" if _ok else "FALLIDA"))
	quit(0 if _ok else 1)
	return true
