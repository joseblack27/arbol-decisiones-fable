# =============================================================================
# Prueba de EnemigoJefeEsqueleto (2 fases):
#   1. Arranca con embestida + golpe básico (cuerpo a cuerpo, corto alcance)
#      en su repertorio — sin abanico todavía.
#   2. Con la vida por encima del 50%, nada cambia.
#   3. Al bajar la vida a <=50%: se congela el árbol de comportamiento
#      (respiro telegrafiado) y se detiene el movimiento — todavía SIN el
#      abanico agregado.
#   4. Pasada la pausa (pausa_cambio_fase): el árbol se reactiva Y el
#      abanico se suma al repertorio de SelectorHabilidades.
#   5. Bajar la vida de nuevo (ya en fase 2) NO debe repetir el proceso
#      (agregar el abanico dos veces, volver a congelar).
#   godot --headless --path . --script res://pruebas/prueba_jefe_esqueleto_fases.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _jefe
var _vida
var _selector
var _arbol
var _tras_pausa_congelado_ok := false
var _abanico_no_estaba_antes := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		5:
			_abanico_no_estaba_antes = _selector.habilidades.size() == 2
			print("Repertorio inicial: embestida + golpe básico (esperado 2 habilidades): %d" % _selector.habilidades.size())
			# Vida por encima del 50 % — no debe pasar nada.
			_vida.quitar_vida(30.0)  # 400 -> 370, 92.5%
		6:
			print("Sigue activo con vida > 50%% (esperado true): %s" % _arbol.activo)
			# Bajar a justo 50% de golpe.
			_vida.quitar_vida(170.0)  # 370 -> 200, exactamente 50%
		7:
			print("Árbol congelado al cruzar 50%% (esperado false): %s" % _arbol.activo)
			print("Abanico TODAVÍA no agregado (esperado 2 habilidades): %d" % _selector.habilidades.size())
		# pausa_cambio_fase = 1.3s ≈ 78 fotogramas desde el 6.
		90:
			_tras_pausa_congelado_ok = _arbol.activo
			print("Árbol reactivado tras la pausa (esperado true): %s" % _arbol.activo)
			print("Abanico agregado tras la pausa (esperado 3 habilidades): %d" % _selector.habilidades.size())
		91:
			# Ya en fase 2: bajar la vida de nuevo no debe re-disparar nada.
			_vida.quitar_vida(50.0)
		95:
			print("No se re-congeló ni se duplicó el abanico (esperado true / 3): %s / %d" \
				% [_arbol.activo, _selector.habilidades.size()])
			return _informar()
	return false


func _montar() -> void:
	var escena := (load("res://escenas/enemigos/EnemigoJefeEsqueleto.tscn") as PackedScene).instantiate()
	root.add_child(escena)
	current_scene = escena
	_jefe = escena
	_vida = _jefe.get_node("VidaComponente")
	_selector = _jefe.get_node("ArbolComportamiento/Selector/Atacar/SelectorHabilidades")
	_arbol = _jefe.get_node("ArbolComportamiento")


func _informar() -> bool:
	var repertorio_final: int = _selector.habilidades.size()
	var sin_duplicados_ok: bool = repertorio_final == 3
	var arbol_activo_final: bool = _arbol.activo
	print("PRUEBA JEFE ESQUELETO FASES %s" % (
		"OK" if (_abanico_no_estaba_antes and _tras_pausa_congelado_ok and sin_duplicados_ok and arbol_activo_final)
		else "FALLIDA"
	))
	quit(0 if (_abanico_no_estaba_antes and _tras_pausa_congelado_ok and sin_duplicados_ok and arbol_activo_final) else 1)
	return true
