# =============================================================================
# Prueba de la animación de mordida (embestida) del Lobo/Lobo Feroz:
#   El árbol de animación ya tenía IDLE -> MORDIDA_PREPARACION -> MORDIDA_
#   DASH -> IDLE armado, pero EnemigoLobo.gd nunca disparaba esas 3
#   condiciones (escribía "debeCargar", que no existe en ese árbol) — la
#   embestida se veía con caminar/idle en vez de su propia animación.
#   Verifica que las 3 fases de HabilidadCarga (preparación -> dash ->
#   terminada) muevan las condiciones correctas del AnimationTree, para
#   ambos mobs que comparten este árbol.
#   godot --headless --path . --script res://pruebas/prueba_animacion_mordida_lobo.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _mob
var _habilidad_carga
var _tree: AnimationTree
var _prep_ok := false
var _dash_ok := false
var _fin_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar("res://escenas/enemigos/EnemigoLobo.tscn")
		2:
			_habilidad_carga.activar(Vector2.RIGHT, 1.0)
		# duracion_preparacion=1.0s en Lobo -> justo antes de que termine.
		55:
			_prep_ok = _tree.get("parameters/conditions/debeMordidaPrep") == true \
				and _tree.get("parameters/conditions/debeMordidaDash") == false
			print("Tras iniciar la carga, en fase de preparación (esperado true/false): %s/%s" % [
				_tree.get("parameters/conditions/debeMordidaPrep"),
				_tree.get("parameters/conditions/debeMordidaDash"),
			])
		# Pasado duracion_preparacion (60 frames) ya debería estar en el dash.
		65:
			_dash_ok = _tree.get("parameters/conditions/debeMordidaPrep") == false \
				and _tree.get("parameters/conditions/debeMordidaDash") == true
			print("Tras terminar la preparación, en fase de dash (esperado false/true): %s/%s" % [
				_tree.get("parameters/conditions/debeMordidaPrep"),
				_tree.get("parameters/conditions/debeMordidaDash"),
			])
		# El dash es corto (distancia_maxima_dash a multiplicador alto) — para
		# cuando llegue acá ya debería haber terminado solo.
		140:
			_fin_ok = _tree.get("parameters/conditions/debeMordidaDash") == false \
				and _tree.get("parameters/conditions/debeSalirMordida") == true \
				and _tree.get("parameters/conditions/debeIdle") == true
			print("Tras terminar el dash, vuelve a idle (esperado false/true/true): %s/%s/%s" % [
				_tree.get("parameters/conditions/debeMordidaDash"),
				_tree.get("parameters/conditions/debeSalirMordida"),
				_tree.get("parameters/conditions/debeIdle"),
			])
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


func _informar() -> bool:
	var exito := _prep_ok and _dash_ok and _fin_ok
	print("PRUEBA ANIMACIÓN MORDIDA LOBO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
