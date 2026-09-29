extends Node
## Red de seguridad contra quedar trabado en la geometría del mapa (p. ej.
## insistiendo con Parpadeo o Carga contra la misma esquina). Lo crea
## Jugador.gd como hijo y lo llama con verificar(delta) justo después de mover
## el cuerpo, solo donde vive la posición autoritativa (servidor o sin red): el
## cliente dueño solo predice, y "destrabarlo" ahí lo pisaría la próxima
## reconciliación.
##
## Dos redes:
##   1. INCRUSTADO: el CUERPO se solapa de verdad con la pared, chequeado con
##      una versión achicada de la propia forma (ver _esta_incrustado_en_pared).
##      "No avanza aunque quiera moverse" no alcanza, porque eso también es
##      alguien empujando una pared a propósito.
##   2. SIN AVANZAR, más paciente: no hay solape real pero el jugador igual no
##      avanza (move_and_slide resolviendo ~0 contra una esquina rara). Si pide
##      moverse, no está inmovilizado a propósito (Cepo, aturdido; ver
##      MovimientoComponente._contador_inmovilizacion) y casi no se movió en
##      2 s, se fuerza el movimiento en la dirección pedida
##      (_intentar_forzar_movimiento) y, si no hay camino, se lo reubica en el
##      hueco libre más cercano (_intentar_destrabar). Umbral más largo porque
##      la señal es menos certera; a alguien parado contra una pared normal
##      como mucho le toca un empujón chico.

## Segundos SEGUIDOS incrustado antes de reubicar: evita reaccionar a un solape
## de un solo fotograma, p. ej. justo después de un teletransporte.
const _TIEMPO_UMBRAL := 0.5
## Cuánto se achica la forma real al chequear solape: un contacto normal
## contra una pared (tocando, sin penetrar) no debe contar como atascado.
const _MARGEN_ACHIQUE := 3.0
const _SIN_AVANZAR_TIEMPO_UMBRAL := 2.0
const _SIN_AVANZAR_DISTANCIA_UMBRAL := 15.0
## Distancia que se intenta "forzar" en la dirección pedida antes de rendirse
## y buscar cualquier hueco libre cercano.
const _DISTANCIA_FORZAR := 48.0
## Capa "mundo", mismo criterio que HabilidadParpadeo.capa_obstaculos.
const _CAPA_MUNDO := 1

var _tiempo_incrustado := 0.0
var _tiempo_sin_avanzar := 0.0
var _posicion_referencia_sin_avanzar := Vector2.ZERO

@onready var _jugador: CharacterBody2D = get_parent()
@onready var _forma_colision: CollisionShape2D = get_parent().get_node_or_null("CollisionShape2D")


func verificar(delta: float) -> void:
	if _esta_incrustado_en_pared():
		_tiempo_incrustado += delta
		if _tiempo_incrustado >= _TIEMPO_UMBRAL:
			_tiempo_incrustado = 0.0
			_intentar_destrabar()
			_posicion_referencia_sin_avanzar = _jugador.global_position
			_tiempo_sin_avanzar = 0.0
			return
	else:
		_tiempo_incrustado = 0.0

	_verificar_sin_avanzar_y_forzar(delta)


func _verificar_sin_avanzar_y_forzar(delta: float) -> void:
	var movimiento: MovimientoComponente = _jugador.componente_movimiento
	var inmovilizado := movimiento != null and movimiento._contador_inmovilizacion > 0
	if _jugador.direccion.length() < 0.1 or inmovilizado:
		_tiempo_sin_avanzar = 0.0
		_posicion_referencia_sin_avanzar = _jugador.global_position
		return
	if _jugador.global_position.distance_to(_posicion_referencia_sin_avanzar) > _SIN_AVANZAR_DISTANCIA_UMBRAL:
		_tiempo_sin_avanzar = 0.0
		_posicion_referencia_sin_avanzar = _jugador.global_position
		return
	_tiempo_sin_avanzar += delta
	if _tiempo_sin_avanzar < _SIN_AVANZAR_TIEMPO_UMBRAL:
		return
	_tiempo_sin_avanzar = 0.0
	if not _intentar_forzar_movimiento():
		_intentar_destrabar()
	_posicion_referencia_sin_avanzar = _jugador.global_position


## Barre la forma real (mismo criterio que HabilidadParpadeo._recortar_
## por_obstaculos) hasta _DISTANCIA_FORZAR en la dirección que el jugador está
## pidiendo: si encuentra aunque sea un poco de camino libre de verdad, lo
## empuja hasta ahí en vez de mandarlo a cualquier lado. Devuelve false si no
## encontró nada mejor que quedarse quieto, para caer a _intentar_destrabar().
func _intentar_forzar_movimiento() -> bool:
	if not _forma_colision or not _forma_colision.shape:
		return false
	var query := _consulta(_forma_colision.shape)
	query.transform = Transform2D(0.0, _jugador.global_position)
	query.motion = _jugador.direccion.normalized() * _DISTANCIA_FORZAR
	var fracciones := _jugador.get_world_2d().direct_space_state.cast_motion(query)
	var fraccion_segura: float = fracciones[0] if fracciones.size() > 0 else 0.0
	var avance := query.motion * fraccion_segura
	if avance.length() < 8.0:
		return false
	_jugador.global_position += avance
	_jugador.velocity = Vector2.ZERO
	return true


## true solo si la forma real del jugador, ACHICADA en _MARGEN_ACHIQUE, se
## solapa con la capa "mundo": tocar una pared de refilón (contacto normal, sin
## penetrar) da false a propósito.
func _esta_incrustado_en_pared() -> bool:
	if not _forma_colision or not _forma_colision.shape:
		return false
	var forma_achicada: Shape2D = _forma_colision.shape.duplicate()
	if forma_achicada is CircleShape2D:
		(forma_achicada as CircleShape2D).radius = maxf(1.0, (forma_achicada as CircleShape2D).radius - _MARGEN_ACHIQUE)
	var query := _consulta(forma_achicada)
	query.transform = Transform2D(0.0, _jugador.global_position)
	return not _jugador.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


## Busca en anillos crecientes alrededor de la posición actual el primer punto
## donde la forma real del jugador no se solape con nada de la capa "mundo", y
## lo teletransporta ahí. Nunca prueba "acá mismo" (radio 0): si está
## atascado, acá ya está mal.
func _intentar_destrabar() -> void:
	if not _forma_colision or not _forma_colision.shape:
		return
	var espacio := _jugador.get_world_2d().direct_space_state
	var query := _consulta(_forma_colision.shape)
	var origen := _jugador.global_position
	var radios: Array[float] = [16.0, 32.0, 48.0, 64.0, 96.0, 128.0]
	for radio in radios:
		for angulo_deg in range(0, 360, 30):
			var candidato: Vector2 = origen + Vector2.RIGHT.rotated(deg_to_rad(angulo_deg)) * radio
			query.transform = Transform2D(0.0, candidato)
			if espacio.intersect_shape(query, 1).is_empty():
				_jugador.global_position = candidato
				_jugador.velocity = Vector2.ZERO
				return


func _consulta(forma: Shape2D) -> PhysicsShapeQueryParameters2D:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = forma
	query.collision_mask = _CAPA_MUNDO
	query.exclude = [_jugador.get_rid()]
	return query
