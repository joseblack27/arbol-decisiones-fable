# =============================================================================
# Prueba: AccionAtacar se reposiciona a un costado del objetivo durante la
# recuperación post-ataque, en vez de quedarse plantado — pedido del
# usuario: "se queda quieto esperando los golpes, se me hace muy fácil",
# además de sentirse "muerto" parado ahí. También cubre el reporte
# posterior: "el lobo después de pegar se queda quieto en el puesto" — con
# velocidad_reposicionamiento alta, llegaba al punto elegido casi de
# inmediato y se quedaba plantado el resto de los ~3s de recuperación
# (_tiene_destino_reposicionamiento nunca se limpiaba hasta el próximo
# ataque). Ahora, al llegar, espera una pausa corta y elige OTRO punto,
# repitiendo mientras dure la recuperación.
#
# Sobre un Lobo real, en combate real (mismo criterio que
# prueba_lobo_combate.gd: señuelo en grupo "jugadores", árbol de
# comportamiento completo, sin invocar el nodo a mano): apenas entra en
# recuperación (AccionAtacar._fin_recuperacion > 0), la posición sigue
# cambiando en los fotogramas siguientes en vez de congelarse, Y no hay
# ninguna racha larga sin moverse durante TODA la ventana de recuperación.
#   godot --headless --path . --script res://pruebas/prueba_atacar_reposicionamiento.gd
# =============================================================================
extends SceneTree

const _TOPE_FOTOGRAMAS_ESPERA_ATAQUE := 400
const _FOTOGRAMAS_A_OBSERVAR := 20
# ~3s de recuperación (duracion_recuperacion por defecto) a 60fps, con
# margen para que el último fotograma observado ya haya entrado en recup.
const _FOTOGRAMAS_VENTANA_COMPLETA := 175
# Con pausas de 0.4s (24 fotogramas) entre saltos, una racha bien mayor que
# eso sin moverse indica que se quedó plantado sin elegir un destino nuevo.
const _TOPE_FOTOGRAMAS_QUIETO_SEGUIDOS := 40

var _fotogramas := 0
var _lobo: Node2D
var _senuelo: CharacterBody2D
var _accion_atacar

var _en_recuperacion := false
var _fotogramas_en_recuperacion := 0
var _pos_al_entrar_recuperacion := Vector2.ZERO
var _pos_anterior := Vector2.ZERO
var _fotogramas_quieto_seguidos := 0
var _max_fotogramas_quieto_seguidos := 0

var _llego_a_atacar := false
var _se_mueve_en_recuperacion_ok := false
var _no_se_planta_en_ventana_completa_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas == 1:
		_montar_escena()
		return false

	if not _en_recuperacion:
		if _accion_atacar.get("_fin_recuperacion") > 0.0:
			_en_recuperacion = true
			_llego_a_atacar = true
			_pos_al_entrar_recuperacion = _lobo.global_position
			_pos_anterior = _lobo.global_position
		elif _fotogramas > _TOPE_FOTOGRAMAS_ESPERA_ATAQUE:
			return _informar()
		return false

	_fotogramas_en_recuperacion += 1

	var pos := _lobo.global_position
	if pos.distance_to(_pos_anterior) > 0.05:
		_fotogramas_quieto_seguidos = 0
	else:
		_fotogramas_quieto_seguidos += 1
		_max_fotogramas_quieto_seguidos = maxi(_max_fotogramas_quieto_seguidos, _fotogramas_quieto_seguidos)
	_pos_anterior = pos

	if _fotogramas_en_recuperacion == _FOTOGRAMAS_A_OBSERVAR:
		var distancia_recorrida := pos.distance_to(_pos_al_entrar_recuperacion)
		_se_mueve_en_recuperacion_ok = distancia_recorrida > 5.0
		print("Distancia recorrida durante la recuperación (esperado > 5px, no plantado): %.1fpx" % \
			distancia_recorrida)

	if _fotogramas_en_recuperacion < _FOTOGRAMAS_VENTANA_COMPLETA:
		return false

	print("Racha más larga sin moverse durante ~3s de recuperación (esperado <= %.2fs): %.2fs" % [
		_TOPE_FOTOGRAMAS_QUIETO_SEGUIDOS / 60.0, _max_fotogramas_quieto_seguidos / 60.0])
	_no_se_planta_en_ventana_completa_ok = _max_fotogramas_quieto_seguidos <= _TOPE_FOTOGRAMAS_QUIETO_SEGUIDOS
	return _informar()


func _montar_escena() -> void:
	# Las habilidades instancian su efecto en current_scene (ver
	# prueba_lobo_combate.gd) — sin esto revienta al primer ataque.
	current_scene = root

	_lobo = (load("res://escenas/enemigos/EnemigoLobo.tscn") as PackedScene).instantiate()
	root.add_child(_lobo)
	_lobo.global_position = Vector2(300, 300)

	# Señuelo: cuerpo en grupo "jugadores" con un área VidaComponente
	# detectable, YA en rango de ataque (sin esperar a que se acerque —
	# eso ya se cubre en prueba_lobo_combate.gd).
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
	_senuelo.global_position = Vector2(340, 300)

	_accion_atacar = _lobo.get_node("ArbolComportamiento/Selector/Atacar")


func _informar() -> bool:
	print("Llegó a atacar (esperado true): %s" % _llego_a_atacar)
	var exito := _llego_a_atacar and _se_mueve_en_recuperacion_ok and _no_se_planta_en_ventana_completa_ok
	print("PRUEBA ATACAR REPOSICIONAMIENTO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
