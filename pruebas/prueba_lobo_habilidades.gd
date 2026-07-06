# =============================================================================
# Prueba instrumentada: registra qué habilidades usa el lobo y a qué distancia
# durante ~20 s simulados contra un señuelo estático.
#   godot --headless --path . --script res://pruebas/prueba_lobo_habilidades.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _lobo: Node2D
var _senuelo: CharacterBody2D
var _usos: Array[String] = []


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas == 1:
		_montar_escena()
		return false

	if _fotogramas % 30 == 0:
		var memoria = _lobo.get("memoria")
		var distancia: float = _lobo.global_position.distance_to(_senuelo.global_position)
		print("t=%4.1fs  dist=%5.1f  habilidad_activa=%s  ataque_en_curso=%s" % [
			_fotogramas / 60.0,
			distancia,
			str(memoria.obtener("habilidad_activa")),
			str(memoria.obtener("ataque_en_curso", false)),
		])

	if _fotogramas > 1200:
		print("Habilidades seleccionadas: ", _usos)
		var aranazos := _usos.count("Arañazo")
		var exito := _usos.has("Carga") and aranazos >= 2
		print("PRUEBA HABILIDADES %s" % ("OK" if exito else "FALLIDA"))
		quit(0 if exito else 1)
		return true
	return false


func _montar_escena() -> void:
	# Escena contenedora: las habilidades instancian efectos en current_scene.
	var escena := Node2D.new()
	escena.name = "EscenaPrueba"
	root.add_child(escena)
	current_scene = escena

	_lobo = (load("res://enemigos/EnemigoLobo.tscn") as PackedScene).instantiate()
	root.add_child(_lobo)
	_lobo.global_position = Vector2(300, 300)

	var selector := _lobo.get_node("ArbolComportamiento/Selector/Atacar/SelectorHabilidades") as SelectorHabilidades
	selector.habilidad_seleccionada.connect(func(habilidad: HabilidadBT) -> void:
		_usos.append(habilidad.nombre)
		print(">>> USÓ: %s (dist %.1f)" % [
			habilidad.nombre,
			_lobo.global_position.distance_to(_senuelo.global_position),
		])
	)

	_senuelo = CharacterBody2D.new()
	_senuelo.add_to_group("jugadores")
	var vida := VidaComponente.new()
	vida.collision_layer = 1
	var colision := CollisionShape2D.new()
	var forma := CircleShape2D.new()
	forma.radius = 20.0
	colision.shape = forma
	vida.add_child(colision)
	_senuelo.add_child(vida)
	root.add_child(_senuelo)
	vida.owner = _senuelo
	_senuelo.global_position = Vector2(460, 300)
