# =============================================================================
# Prueba: transición de la Araña Reina a FASE 3 al cruzar 35% de vida —
# invoca 3 refuerzos mixtos (Araña + Lobo Feroz + Esqueleto Arquero), suma
# Marca/Charco/Escupitajo al repertorio a distancia, y activa "Furia final"
# (multiplicador_recarga permanente) al limpiar el último refuerzo.
#   godot --headless --path . --script res://pruebas/prueba_arana_reina_fase3.gd
# =============================================================================
extends SceneTree

var _reina
var _f := 0

var _entra_en_fase2 := false
var _entra_en_fase3 := false
var _invoca_3_mixtos := false
var _suma_las_tres_habilidades := false
var _escudo_activo_fase3 := false
var _escudo_cae_tras_matarlos := false
var _furia_activada := false
var _multiplicador_aplicado := false


func _process(_d: float) -> bool:
	_f += 1
	match _f:
		1:
			_montar()
		2:
			var maxima = _reina.get_node("VidaComponente").obtener_vida_maxima()
			# Primer golpe: cruza 70%, entra en fase 2 (65%).
			_reina.get_node("VidaComponente").quitar_vida(maxima * 0.35)
		100:
			_entra_en_fase2 = _reina._fase == 2
			print("Entra en fase 2 con el primer golpe (esperado true): %s" % _entra_en_fase2)
			for lobo in _reina._adds.duplicate():
				lobo.get_node("VidaComponente").quitar_vida(99999.0)
		165:
			# Escudo de fase 2 ya caído: segundo golpe, cruza 35% (queda ~30%).
			var maxima = _reina.get_node("VidaComponente").obtener_vida_maxima()
			_reina.get_node("VidaComponente").quitar_vida(maxima * 0.35)
		265:
			_entra_en_fase3 = _reina._fase == 3
			print("Entra en fase 3 con el segundo golpe (esperado true): %s" % _entra_en_fase3)

			_invoca_3_mixtos = _reina._adds.size() == 3
			print("Invoca 3 refuerzos mixtos (esperado true, %d): %s" % [
				_reina._adds.size(), _invoca_3_mixtos])

			var selector = _reina.get_node(
				"ArbolComportamiento/Selector/AtaqueADistancia/AtacarLejos/SelectorTelaraña")
			_suma_las_tres_habilidades = selector.habilidades.has(_reina.habilidad_marca_bt) \
				and selector.habilidades.has(_reina.habilidad_charco_bt) \
				and selector.habilidades.has(_reina.habilidad_disparo_linea_bt)
			print("Suma Marca+Charco+Escupitajo al repertorio a distancia (esperado true): %s" % \
				_suma_las_tres_habilidades)

			var escudo = _reina.get_node_or_null("EscudoComponente")
			_escudo_activo_fase3 = escudo != null and escudo.esta_activo()
			print("Escudo activo mientras viven los refuerzos de fase 3 (esperado true): %s" % \
				_escudo_activo_fase3)

			for add in _reina._adds.duplicate():
				add.get_node("VidaComponente").quitar_vida(99999.0)
		330:
			var escudo = _reina.get_node_or_null("EscudoComponente")
			_escudo_cae_tras_matarlos = escudo == null or not escudo.esta_activo()
			print("Escudo cae tras matar a los 3 refuerzos (esperado true): %s" % \
				_escudo_cae_tras_matarlos)

			_furia_activada = _reina._furia_activada
			print("Furia final activada (esperado true): %s" % _furia_activada)

			_multiplicador_aplicado = true
			for hijo in _reina.get_node("Habilidades").get_children():
				if hijo is HabilidadBase and not is_equal_approx(hijo.multiplicador_recarga, 1.4):
					_multiplicador_aplicado = false
			print("multiplicador_recarga=1.4 en todas las habilidades (esperado true): %s" % \
				_multiplicador_aplicado)
			return _informar()
	return false


func _montar() -> void:
	var contenedor := Node2D.new()
	contenedor.name = "Enemigos"
	root.add_child(contenedor)
	current_scene = contenedor

	var escena_reina := load("res://escenas/enemigos/EnemigoArañaReina.tscn") as PackedScene
	_reina = escena_reina.instantiate()
	contenedor.add_child(_reina)
	_reina.global_position = Vector2.ZERO


func _informar() -> bool:
	var exito := _entra_en_fase2 and _entra_en_fase3 and _invoca_3_mixtos \
		and _suma_las_tres_habilidades and _escudo_activo_fase3 and _escudo_cae_tras_matarlos \
		and _furia_activada and _multiplicador_aplicado
	print("PRUEBA ARAÑA REINA FASE 3 %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
