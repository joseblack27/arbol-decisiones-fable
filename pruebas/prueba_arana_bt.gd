# =============================================================================
# Prueba de la araña migrada a BT puro (kiter):
#   Fase 1 — señuelo a 260 px (en visión, fuera de rango de disparo 200)
#            → debe ACERCARSE a ~180 px y lanzar BolaTelaraña.
#   Fase 2 — señuelo a 70 px   → debe retirarse (la distancia crece).
#   Fase 3 — señuelo pegado a 30 px → debe usar Arañazo.
#   godot --headless --path . --script res://pruebas/prueba_arana_bt.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _arana: Node2D
var _senuelo: CharacterBody2D
var _usos: Array[String] = []
var _dist_al_acercarse := 0.0
var _se_retiro := false
var _se_acerco_a_rango := false
var _dist_al_disparar := INF


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas == 1:
		_montar_escena()
		return false
	# Fase 1 (hasta 480): debe acercarse por sí sola a rango de disparo.
	if _fotogramas <= 480:
		if _arana.global_position.distance_to(_senuelo.global_position) <= 200.0:
			_se_acerco_a_rango = true
	if _fotogramas == 481:
		# Fase 2: señuelo a 90 px — dentro de la ventana de retirada (80-100):
		# más cerca del rango del arañazo (80) ya no huye, ataca.
		_senuelo.global_position = _arana.global_position + Vector2(90, 0)
		_dist_al_acercarse = 90.0
	if _fotogramas > 481 and _fotogramas <= 720:
		var d := _arana.global_position.distance_to(_senuelo.global_position)
		if d > _dist_al_acercarse + 40.0:
			_se_retiro = true
	if _fotogramas > 720 and _fotogramas <= 1100:
		# Fase 3: señuelo pegado a 70 px (dentro del rango 80 del arañazo,
		# dentro también del umbral de retirada 100: debe GANAR el arañazo).
		_senuelo.global_position = _arana.global_position + Vector2(70, 0)
	if _fotogramas > 1100:
		return _informar()
	return false


func _informar() -> bool:
	print("Habilidades usadas: ", _usos)
	print("Se acercó a rango de disparo: %s" % _se_acerco_a_rango)
	print("Lanzó telaraña (a %.0f px): %s" % [_dist_al_disparar, _usos.has("BolaTelaraña")])
	print("Se retiró al acercarse: %s" % _se_retiro)
	print("Arañazo con jugador encima: %s" % _usos.has("Arañazo"))
	var exito := _usos.has("BolaTelaraña") and _se_acerco_a_rango \
		and _dist_al_disparar <= 200.0 and _se_retiro and _usos.has("Arañazo")
	print("PRUEBA ARAÑA %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true


func _montar_escena() -> void:
	var escena := Node2D.new()
	escena.name = "EscenaPrueba"
	root.add_child(escena)
	current_scene = escena

	_arana = (load("res://enemigos/EnemigoAraña.tscn") as PackedScene).instantiate()
	root.add_child(_arana)
	_arana.global_position = Vector2(300, 300)

	for selector: Node in [
		_arana.get_node("ArbolComportamiento/Selector/AtacarMelee/SelectorArañazo"),
		_arana.get_node("ArbolComportamiento/Selector/AtaqueADistancia/AtacarLejos/SelectorTelaraña"),
	]:
		(selector as SelectorHabilidades).habilidad_seleccionada.connect(
			func(habilidad: HabilidadBT) -> void:
				_usos.append(habilidad.nombre)
				if habilidad.nombre == "BolaTelaraña":
					_dist_al_disparar = minf(
						_dist_al_disparar,
						_arana.global_position.distance_to(_senuelo.global_position),
					)
				print(">>> USÓ: %s (dist %.1f, t=%.1fs)" % [
					habilidad.nombre,
					_arana.global_position.distance_to(_senuelo.global_position),
					_fotogramas / 60.0,
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
	# A 260 px: dentro de la visión (300) pero fuera del rango de disparo (200).
	_senuelo.global_position = Vector2(560, 300)
