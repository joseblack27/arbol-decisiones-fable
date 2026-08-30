# =============================================================================
# Regresión: "el muro lo sigue lanzando en otra posición en lugar de encima
# del jugador" — HabilidadMuroGuardian._ejecutar() colocaba el muro siempre
# a distancia_muro (130px) FIJOS del jefe, sin importar qué tan cerca
# estuviera el objetivo real — si el jugador estaba a menos de 130px, el
# muro se pasaba de largo; si estaba más lejos (hasta rango_maximo=170px
# antes del fix), quedaba corto. Ahora usa la MENOR entre distancia_muro y
# la distancia real al objetivo, así el muro converge sobre el jugador en
# vez de una posición fija.
#
# Prueba con el jugador a 80px (bien dentro de los 130) — el centro del
# muro debería caer cerca del jugador, no a 130px de distancia.
#   godot --headless --path . --script res://pruebas/prueba_guardian_muro_sobre_jugador.gd
# =============================================================================
extends SceneTree

var _jefe
var _jugador
var _muro_habilidad


func _process(_delta: float) -> bool:
	_montar()
	_jefe.memoria.establecer("objetivo", _jugador)
	_muro_habilidad.activar(Vector2.RIGHT, 1.0)

	# El muro se obtiene de GestorPiscinas, puede no ser hijo directo de la
	# escena — se lee directo del diccionario interno de la habilidad.
	var activos: Dictionary = _muro_habilidad._muros_activos
	var ok := false
	if activos.size() > 0:
		var muro = activos.values()[0]
		var distancia_al_jugador: float = muro.global_position.distance_to(_jugador.global_position)
		print("Posición del muro: %s, jugador: %s, distancia entre ambos: %.1f" % [
			muro.global_position, _jugador.global_position, distancia_al_jugador])
		# Con el jugador a 80px y distancia_muro=130 (tope), el muro debería
		# quedar cerca del jugador (no a 130px de él, que sería el bug viejo).
		ok = distancia_al_jugador < 20.0
	else:
		print("No se instanció ningún muro (activos.size()=0)")
	print("PRUEBA GUARDIAN MURO SOBRE JUGADOR %s" % ("OK" if ok else "FALLIDA"))
	quit(0 if ok else 1)
	return true


func _montar() -> void:
	var raiz := Node2D.new()
	root.add_child(raiz)
	current_scene = raiz

	var escena_jefe := load("res://escenas/enemigos/EnemigoGuardianQuebrado.tscn")
	_jefe = escena_jefe.instantiate()
	raiz.add_child(_jefe)
	_jefe.global_position = Vector2.ZERO

	var escena_jugador := load("res://escenas/jugador/Jugador.tscn") as PackedScene
	_jugador = escena_jugador.instantiate()
	_jugador.name = "1"
	raiz.add_child(_jugador)
	_jugador.global_position = Vector2(80, 0)
	var vida_jugador = _jugador.get_node("VidaComponente")
	vida_jugador.salud_maxima = 100000.0
	vida_jugador.salud_actual = 100000.0
	vida_jugador.cancelar_invulnerabilidad()

	_muro_habilidad = _jefe.get_node("Habilidades/HabilidadMuroGuardian")
