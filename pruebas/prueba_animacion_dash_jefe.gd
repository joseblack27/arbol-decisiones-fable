# =============================================================================
# Prueba de la animación del Jefe Esqueleto durante HabilidadCarga: mismo
# bug y mismo fix que EnemigoCaballeroEsqueleto (AnimationTree idéntico,
# solo IDLE/CAMINAR, sin sprites propios de embestida) — ver
# prueba_animacion_dash_caballero.gd para el porqué de cada detalle del
# setup (arrancar caminando de verdad, BT apagado, animation_tree.active
# forzado a true, estado real vía playback.get_current_node()).
#
# A diferencia del Caballero, EnemigoJefeEsqueleto._ready() antes ni
# siquiera se suscribía a preparacion_iniciada/carga_iniciada — quedaba
# muda esa parte del cableado, no solo con condiciones muertas.
#   godot --headless --path . --script res://pruebas/prueba_animacion_dash_jefe.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _fotogramas_desde_activar := -1
var _mob
var _habilidad_carga
var _tree: AnimationTree
var _playback: AnimationNodeStateMachinePlayback
var _prep_ok := false
var _dash_ok := false
var _fin_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas_desde_activar >= 0:
		_fotogramas_desde_activar += 1

	if _fotogramas == 1:
		_mob = (load("res://escenas/enemigos/EnemigoJefeEsqueleto.tscn") as PackedScene).instantiate()
		root.add_child(_mob)
		current_scene = _mob
		_habilidad_carga = _mob.get_node("Habilidades/HabilidadCarga")
		_tree = _mob.get_node("AnimacionComponente/AnimationTree")
		_playback = _tree.get("parameters/playback")
	elif _fotogramas == 2:
		_tree.active = true
	elif _fotogramas == 5:
		var arbol = _mob.get_node_or_null("ArbolComportamiento")
		if arbol:
			arbol.activo = false
		_mob.get_node("MovimientoComponente").comandar_direccion(Vector2.RIGHT, 50.0)
	elif _fotogramas == 20:
		print("Arranca en CAMINAR (esperado true): %s" % (_playback.get_current_node() == "CAMINAR"))
		_habilidad_carga.activar(Vector2.RIGHT, 1.0)
		_fotogramas_desde_activar = 0
	# duracion_preparacion del Jefe (1.3s+ en algunas configuraciones) — 50
	# frames alcanza para estar bien adentro de la preparación de sobra.
	elif _fotogramas_desde_activar == 50:
		_prep_ok = _playback.get_current_node() == "CAMINAR"
		print("Durante la preparación, sigue mostrando CAMINAR (esperado true): %s (estado real: %s)" % [
			_prep_ok, _playback.get_current_node()])
	elif _fotogramas_desde_activar == 90:
		_dash_ok = _playback.get_current_node() == "CAMINAR"
		print("Durante el dash, sigue mostrando CAMINAR (esperado true): %s (estado real: %s)" % [
			_dash_ok, _playback.get_current_node()])
	elif _fotogramas_desde_activar == 170:
		_fin_ok = _playback.get_current_node() == "CAMINAR"
		print("Tras terminar, sigue mostrando CAMINAR (esperado true): %s (estado real: %s)" % [
			_fin_ok, _playback.get_current_node()])
		return _informar()
	return false


func _informar() -> bool:
	var exito := _prep_ok and _dash_ok and _fin_ok
	print("PRUEBA ANIMACIÓN DASH JEFE %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
