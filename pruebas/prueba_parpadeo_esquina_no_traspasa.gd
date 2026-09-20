# =============================================================================
# Regresión (bug reportado en juego real, 20 sep 2026, sobre todo cerca de
# esquinas del Hormiguero): "cuando me acerco y uso por ejemplo parpadeo
# contra la pared, no me deja moverme despues se queda fijo". Causa real:
# HabilidadParpadeo.gd chequeaba obstáculos con un RAYO (ancho cero) desde
# el CENTRO del jugador -- un rayo puede pasar limpio justo al lado de una
# esquina/borde que el CUERPO REAL (con su radio, ver CollisionShape2D)
# sí toca, así que el teletransporte terminaba en un punto que el rayo veía
# libre pero que en los hechos se solapaba con la pared: desde ahí
# move_and_slide() ya no puede resolver ningún movimiento (exactamente el
# síntoma reportado).
#
# Geometría del caso: un muro a la altura y=[2,22] (por encima de la línea
# recta y=0 por la que viaja el parpadeo) -- un rayo exacto en y=0 nunca
# toca ese rango, pero un círculo de radio 10 centrado en y=0 SÍ se solapa
# con el muro en cuanto su centro entra en x=[80,120] (la distancia vertical
# al borde del muro, 2px, es mucho menor que el radio). Confirma:
#   1. El destino final NO queda superpuesto con el muro (a diferencia del
#      bug real, donde el rayo no detectaba nada y dejaba pasar el destino
#      tal cual, terminando adentro).
#   2. El jugador puede seguir moviéndose después (move_and_slide real
#      avanza), prueba de que no quedó "trabado" en la geometría.
#   godot --headless --path . --script res://pruebas/prueba_parpadeo_esquina_no_traspasa.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _entidad: CharacterBody2D
var _habilidad: Node
var _muro: StaticBody2D

var _no_quedo_dentro_del_muro_ok := false
var _puede_seguir_moviendose_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		3:
			_habilidad.activar(Vector2.RIGHT, 1.0)
		4:
			_verificar_no_traspaso()
		5:
			_verificar_puede_moverse()
			return _informar()
	return false


func _montar() -> void:
	var escena := Node2D.new()
	root.add_child(escena)
	current_scene = escena

	_entidad = CharacterBody2D.new()
	_entidad.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	escena.add_child(_entidad)
	var forma := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 10.0  # Mismo radio que Jugador.tscn (CircleShape2D_8vwo7, default).
	forma.shape = circ
	forma.name = "CollisionShape2D"
	_entidad.add_child(forma)

	var contenedor := Marker2D.new()
	contenedor.name = "Habilidades"
	_entidad.add_child(contenedor)

	var guion := load("res://escenas/habilidades/parpadeo/HabilidadParpadeo.gd") as GDScript
	_habilidad = guion.new()
	_habilidad.set("distancia_parpadeo", 100.0)
	_habilidad.set("duracion_recarga", 0.0)
	contenedor.add_child(_habilidad)
	_habilidad.entidad_dueña = _entidad

	# Muro por ENCIMA de la línea recta (y=0) por la que viaja el parpadeo --
	# un rayo exacto a lo largo de y=0 nunca lo toca, pero el cuerpo real
	# (radio 10) sí se solapa apenas su centro entra en x=[80,120].
	_muro = StaticBody2D.new()
	_muro.collision_layer = 1
	_muro.global_position = Vector2(100, 12)
	var forma_muro := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 20)  # y en [2,22] relativo al mundo.
	forma_muro.shape = rect
	_muro.add_child(forma_muro)
	current_scene.add_child(_muro)


func _verificar_no_traspaso() -> void:
	var pos := _entidad.global_position
	print("Posición final del parpadeo: %s" % pos)
	# El muro real ocupa x=[80,120], y=[2,22] -- "no quedó dentro" significa
	# que el círculo de radio 10 centrado en pos no se solapa con ese
	# rectángulo (chequeo geométrico directo, no depende de otro código).
	var punto_mas_cercano := Vector2(clampf(pos.x, 80.0, 120.0), clampf(pos.y, 2.0, 22.0))
	var distancia := pos.distance_to(punto_mas_cercano)
	_no_quedo_dentro_del_muro_ok = distancia >= 10.0
	print("El destino final NO se solapa con el muro (esperado true, distancia=%.1f): %s" % [
		distancia, _no_quedo_dentro_del_muro_ok])


func _verificar_puede_moverse() -> void:
	var antes := _entidad.global_position
	# IMPORTANTE: probar hacia la IZQUIERDA (de vuelta por donde vino), no
	# hacia la derecha -- seguir empujando hacia el muro real frenaría
	# igual que cualquier pared normal (no sería un bug, sería el muro
	# haciendo su trabajo). Lo que hay que confirmar es que el jugador NO
	# quedó embebido/trabado en la geometría (el síntoma real reportado:
	# "no me deja moverme", en NINGUNA dirección) -- moverse en una
	# dirección totalmente libre de obstáculos alcanza para probarlo.
	for i in 10:
		_entidad.velocity = Vector2.LEFT * 100.0
		_entidad.move_and_slide()
	var avance := _entidad.global_position.distance_to(antes)
	# Umbral bajo a propósito: lo que importa distinguir es "0px, atascado
	# de verdad" (el bug real) de "avanza algo" -- el valor exacto por paso
	# en este arnés de prueba sincrónico (10 llamadas a move_and_slide()
	# dentro de un mismo _process()) no tiene por qué calzar con el cálculo
	# de un físico real a 60 Hz.
	_puede_seguir_moviendose_ok = avance > 0.5
	print("Después del parpadeo, el jugador sigue pudiendo moverse (esperado true, avanzó %.1fpx en 10 pasos): %s" % [
		avance, _puede_seguir_moviendose_ok])


func _informar() -> bool:
	var exito := _no_quedo_dentro_del_muro_ok and _puede_seguir_moviendose_ok
	print("PRUEBA PARPADEO ESQUINA NO TRASPASA %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
