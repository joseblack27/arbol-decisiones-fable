# =============================================================================
# Prueba: un mob RECIÉN MUERTO (durante el fundido de 0.4s, antes de que
# queue_free() lo saque de escena) no debe seguir "chocando" con las
# habilidades del jugador — reportado: "aun chocan con las habilidades".
#
# EnemigoRaton usa el caso que exponía el bug: su VidaComponente (Area2D
# hijo) tiene FORMA de colisión propia, independiente del cuerpo — apagar
# solo collision_layer/mask del CharacterBody2D no bastaba, ese Area2D
# seguía "golpeable" hasta que el nodo se liberaba de verdad.
#   godot --headless --path . --script res://pruebas/prueba_muerto_no_bloquea_habilidades.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _raton: Node
var _proyectil


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		10:
			# Matar de un golpe — igual que prueba_muerte_mobs.gd.
			var vida := _raton.get_node("VidaComponente")
			vida.quitar_vida(9999.0)
		15:
			# Todavía en pleno fundido (0.4s ≈ 24 fotogramas): el ratón sigue
			# EXISTIENDO en la escena (no se liberó todavía) pero ya está
			# _muerto. Disparar un proyectil justo contra su posición.
			print("Ratón sigue en escena durante el fundido (esperado true): %s" % is_instance_valid(_raton))
			_disparar_proyectil()
		20:
			var siguio_de_largo: bool = is_instance_valid(_proyectil) and not _proyectil.get("_ya_impacto")
			print("Proyectil atravesó al muerto sin impactar (esperado true): %s" % siguio_de_largo)
			return _informar(siguio_de_largo)
	return false


func _montar() -> void:
	var escena := (load("res://escenas/enemigos/EnemigoRaton.tscn") as PackedScene).instantiate()
	root.add_child(escena)
	_raton = escena
	current_scene = escena


func _disparar_proyectil() -> void:
	var jugador := CharacterBody2D.new()
	jugador.add_to_group("jugadores")
	jugador.global_position = _raton.global_position - Vector2(60, 0)
	root.add_child(jugador)

	_proyectil = (load("res://escenas/habilidades/proyectil/Proyectil.tscn") as PackedScene).instantiate()
	root.add_child(_proyectil)
	_proyectil.global_position = jugador.global_position
	_proyectil.configurar(Vector2.RIGHT, 1.0, 20.0, jugador)


func _informar(exito: bool) -> bool:
	print("PRUEBA MUERTO NO BLOQUEA HABILIDADES %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
