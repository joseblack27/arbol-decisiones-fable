# =============================================================================
# Prueba de la animación del Caballero Esqueleto durante HabilidadCarga
# (embestida): a diferencia del Lobo, este mob NO tiene sprites propios de
# preparación/dash — el pedido del usuario fue explícito: que se vea
# caminando durante toda la preparación + el dash, en vez de quedar
# congelado (bug real: Enemigo._aplicar_presentacion() deja de tocar
# debeCaminar/debeIdle mientras memoria["ataque_en_curso"] es true, y antes
# nada forzaba el AnimationTree a quedarse en CAMINAR mientras tanto).
#
# Mismo criterio que prueba_animacion_mordida_lobo.gd (leer ese archivo para
# el porqué de cada detalle del setup): arranca caminando de verdad (no una
# condición a mano, que Enemigo._aplicar_presentacion() pisa todos los
# fotogramas), con el árbol de comportamiento apagado (si no, compite por
# el control del cuerpo), animation_tree.active forzado a true (en headless
# queda en false a propósito) y verificando el ESTADO REAL de la máquina
# (playback.get_current_node()), no solo las condiciones booleanas.
#   godot --headless --path . --script res://pruebas/prueba_animacion_dash_caballero.gd
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
		_montar("res://escenas/enemigos/EnemigoCaballeroEsqueleto.tscn")
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
	# duracion_preparacion=1.0s en el Caballero -> justo antes de que termine.
	elif _fotogramas_desde_activar == 50:
		_prep_ok = _playback.get_current_node() == "CAMINAR"
		print("Durante la preparación, sigue mostrando CAMINAR (esperado true): %s (estado real: %s)" % [
			_prep_ok, _playback.get_current_node()])
	# Pasado duracion_preparacion (60 frames) ya debería estar en el dash.
	elif _fotogramas_desde_activar == 70:
		_dash_ok = _playback.get_current_node() == "CAMINAR"
		print("Durante el dash, sigue mostrando CAMINAR (esperado true): %s (estado real: %s)" % [
			_dash_ok, _playback.get_current_node()])
	# El dash es corto — para cuando llegue acá ya debería haber terminado solo.
	elif _fotogramas_desde_activar == 150:
		_fin_ok = _playback.get_current_node() == "CAMINAR"
		print("Tras terminar, sigue mostrando CAMINAR (esperado true): %s (estado real: %s)" % [
			_fin_ok, _playback.get_current_node()])
		return _informar()
	return false


func _montar(ruta: String) -> void:
	var jugador := Node2D.new()
	jugador.add_to_group("jugadores")
	root.add_child(jugador)
	current_scene = jugador
	jugador.global_position = Vector2(500, 0)

	_mob = (load(ruta) as PackedScene).instantiate()
	root.add_child(_mob)
	_mob.global_position = Vector2.ZERO
	_mob.memoria.establecer("objetivo", jugador)

	_habilidad_carga = _mob.get_node("Habilidades/HabilidadCarga")
	_tree = _mob.get_node("AnimacionComponente/AnimationTree")
	_playback = _tree.get("parameters/playback")


func _informar() -> bool:
	var exito := _prep_ok and _dash_ok and _fin_ok
	print("PRUEBA ANIMACIÓN DASH CABALLERO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
