# =============================================================================
# Prueba del ciclo muerte → reaparición del jugador (un solo jugador):
#   1. Al llegar la vida a 0: queda "muerto" (sin colisión, oscurecido, sin
#      poder moverse ni lanzar habilidades) en vez de curarse al instante.
#   2. Pasados TIEMPO_REAPARICION segundos: revive con vida Y ENERGÍA
#      completas, en el PuntoAparicion del nivel, con colisión y color
#      restaurados, e invulnerable por TIEMPO_INVULNERABILIDAD_REVIVIR (5s)
#      con el destello AMARILLO del sprite (pedido del usuario, distinto del
#      simple pulso de alpha que había antes).
#   godot --headless --path . --script res://pruebas/prueba_muerte_jugador.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _mundo: Node2D
var _jugador: CharacterBody2D
var _capa_original := 0
var _murio_bien := false
var _lejos_del_spawn := Vector2(400, 300)
var _energia_llena_al_revivir := false
var _invulnerable_al_revivir := false
var _duracion_invulnerabilidad_correcta := false
var _sprite_amarillo_al_revivir := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			# Modo local de pruebas: sin esto, Mundo reintenta conectarse al
			# servidor para siempre (multijugador puro) — o peor, se conecta
			# de verdad al Docker si esta corriendo y la prueba deja de ser
			# determinista. Ver Mundo._arrancar_modo_prueba_local().
			root.get_node("/root/Utils").modo_local_pruebas = true
			_mundo = (load("res://escenas/mundo/Mundo.tscn") as PackedScene).instantiate()
			root.add_child(_mundo)
			current_scene = _mundo
		# El jugador recién existe tras el fallback a modo local (~2s) + carga
		# de nivel (ver Mundo._crear_jugador_local).
		200:
			_jugador = _mundo.get_node("Jugadores/local")
			_capa_original = _jugador.collision_layer
			# Alejarlo del spawn para poder verificar el teletransporte al revivir.
			_jugador.global_position = _spawn() + _lejos_del_spawn
			# Un jugador recién aparecido es invulnerable un rato (ver
			# Jugador.TIEMPO_INVULNERABILIDAD_APARICION) — acá se prueba la
			# muerte, no esa protección, así que se la saca antes de golpear.
			_jugador.get_node("VidaComponente").cancelar_invulnerabilidad()
			# Gastar energía para poder comprobar que revivir la rellena
			# igual que la vida.
			_jugador.get_node("EnergiaComponente").consumir(40.0)
			# Matarlo de un golpe.
			_jugador.get_node("VidaComponente").quitar_vida(99999.0)
		230:
			var vida: float = _jugador.get_node("VidaComponente").obtener_vida()
			var sin_colision: bool = _jugador.collision_layer == 0
			var oscurecido: bool = _jugador.modulate != Color.WHITE
			var muerto_flag: bool = _jugador.get("_muerto")
			print("Tras morir: vida=%.0f | sin colision=%s | oscurecido=%s | _muerto=%s" % [
				vida, sin_colision, oscurecido, muerto_flag,
			])
			_murio_bien = vida <= 0.0 and sin_colision and oscurecido and muerto_flag
		# TIEMPO_REAPARICION = 5s → 300 frames; morimos en el 200, así que al
		# frame 560 ya tuvo que revivir (con margen).
		560:
			return _verificar_reaparicion()
	return false


func _spawn() -> Vector2:
	var nivel = root.get_node("/root/GestorNiveles").nivel_actual()
	return (nivel.punto_aparicion() as Node2D).global_position


func _verificar_reaparicion() -> bool:
	var vida_comp = _jugador.get_node("VidaComponente")
	var energia_comp = _jugador.get_node("EnergiaComponente")
	var vida: float = vida_comp.obtener_vida()
	var vida_llena := is_equal_approx(vida, vida_comp.obtener_vida_maxima())
	var colision_ok: bool = _jugador.collision_layer == _capa_original
	var color_ok: bool = _jugador.modulate == Color.WHITE
	var vivo_flag: bool = not _jugador.get("_muerto")
	var en_spawn: float = _jugador.global_position.distance_to(_spawn())
	print("Tras revivir: vida=%.0f (llena=%s) | colision=%s | color=%s | vivo=%s | a %.0f px del spawn" % [
		vida, vida_llena, colision_ok, color_ok, vivo_flag, en_spawn,
	])

	# Energía llena — mismo criterio que la vida (ver Jugador._reaparecer).
	_energia_llena_al_revivir = is_equal_approx(
		energia_comp.obtener_energia(), energia_comp.obtener_energia_maxima())
	print("Energía llena al revivir (esperado true, %.0f/%.0f): %s" % [
		energia_comp.obtener_energia(), energia_comp.obtener_energia_maxima(),
		_energia_llena_al_revivir])

	# Invulnerable al revivir, con la duración PROPIA de revivir (5s), no la
	# de aparición inicial (3s) — pedido del usuario.
	_invulnerable_al_revivir = vida_comp.es_invulnerable()
	_duracion_invulnerabilidad_correcta = is_equal_approx(
		_jugador.TIEMPO_INVULNERABILIDAD_REVIVIR, 5.0)
	print("Invulnerable al revivir (esperado true): %s | TIEMPO_INVULNERABILIDAD_REVIVIR=%.1f (esperado 5.0)" % [
		_invulnerable_al_revivir, _jugador.TIEMPO_INVULNERABILIDAD_REVIVIR])

	# Destello amarillo (no solo alpha) mientras dura la protección.
	var color_sprite: Color = _jugador.sprite.modulate
	_sprite_amarillo_al_revivir = is_equal_approx(color_sprite.r, 1.0) \
		and is_equal_approx(color_sprite.g, 1.0) and is_equal_approx(color_sprite.b, 0.0)
	print("Sprite amarillo mientras es invulnerable (esperado true, color=%s): %s" % [
		color_sprite, _sprite_amarillo_al_revivir])

	var exito := _murio_bien and vida_llena and colision_ok and color_ok \
		and vivo_flag and en_spawn < 50.0 and _energia_llena_al_revivir \
		and _invulnerable_al_revivir and _duracion_invulnerabilidad_correcta \
		and _sprite_amarillo_al_revivir
	print("PRUEBA MUERTE JUGADOR %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
