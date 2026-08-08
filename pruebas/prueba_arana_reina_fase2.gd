# =============================================================================
# Prueba: transición de la Araña Reina a FASE 2 al cruzar 70% de vida —
# pausa telegrafiada, invoca 2 Lobos, activa el escudo del 70% mientras
# vivan, y suma el Golpe de Veneno Paralizante al repertorio de melee.
# La prueba de integración completa (3 fases) vive en
# prueba_arana_reina_fases.gd.
#   godot --headless --path . --script res://pruebas/prueba_arana_reina_fase2.gd
# =============================================================================
extends SceneTree

var _reina
var _f := 0

var _entra_en_fase2 := false
var _invoca_2_lobos := false
var _suma_veneno_paralizante := false
var _escudo_activo_con_adds := false
var _escudo_cae_tras_matarlos := false


func _process(_d: float) -> bool:
	_f += 1
	match _f:
		1:
			_montar()
		2:
			var maxima = _reina.get_node("VidaComponente").obtener_vida_maxima()
			# Cruza el umbral de 70%: la deja en 65%.
			_reina.get_node("VidaComponente").quitar_vida(maxima * 0.35)
		# pausa_cambio_fase=1.3s (~78 fotogramas) + margen de sobra.
		100:
			_entra_en_fase2 = _reina._fase == 2
			print("Entra en fase 2 al cruzar 70%% (esperado true): %s" % _entra_en_fase2)

			_invoca_2_lobos = _reina._adds.size() == 2
			print("Invoca 2 Lobos (esperado true, %d): %s" % [_reina._adds.size(), _invoca_2_lobos])

			var selector = _reina.get_node("ArbolComportamiento/Selector/AtacarMelee/SelectorArañazo")
			_suma_veneno_paralizante = selector.habilidades.has(_reina.habilidad_veneno_paralizante_bt)
			print("Suma Veneno Paralizante al repertorio de melee (esperado true): %s" % \
				_suma_veneno_paralizante)
		102:
			var escudo = _reina.get_node_or_null("EscudoComponente")
			_escudo_activo_con_adds = escudo != null and escudo.esta_activo() \
				and is_equal_approx(escudo.aplicar(100.0), 30.0)
			print("Escudo activo al 70%% mientras viven los Lobos (esperado true): %s" % \
				_escudo_activo_con_adds)
			for lobo in _reina._adds.duplicate():
				lobo.get_node("VidaComponente").quitar_vida(99999.0)
		165:
			var escudo = _reina.get_node_or_null("EscudoComponente")
			_escudo_cae_tras_matarlos = escudo == null or not escudo.esta_activo()
			print("Escudo cae tras matar a los Lobos (esperado true): %s" % _escudo_cae_tras_matarlos)
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
	var exito := _entra_en_fase2 and _invoca_2_lobos and _suma_veneno_paralizante \
		and _escudo_activo_con_adds and _escudo_cae_tras_matarlos
	print("PRUEBA ARAÑA REINA FASE 2 %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
