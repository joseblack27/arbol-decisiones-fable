class_name HabilidadParpadeo
extends HabilidadBase
## Teletransporte corto e instantáneo, sin daño y sin chocar contra
## enemigos en el camino — la contraparte de movilidad pura de
## HabilidadCargaJugador (que sí golpea). Direccional (joystick), como el
## resto de las habilidades apuntadas.
##
## NOTA: placeholder equipable a pedido — el plan es convertir esto en un
## dash de dirección FIJA más adelante; por ahora se deja direccional y
## equipable para poder probarlo.

@export_group("Parpadeo")
@export var distancia_parpadeo: float = 200.0
## Si está activo, estirar menos el joystick acorta la distancia (poder 0..1).
@export var distancia_segun_poder := false
## Capas de física que bloquean el parpadeo (paredes/obstáculos sólidos) —
## sin esto atravesaría un muro de un salto. 0 = sin chequeo, siempre llega
## entero. SOLO la capa 1 (mundo): los enemigos ya no cuentan como obstáculo
## del parpadeo. Antes incluía la 2 (mobs) para no aterrizar ENCIMA de uno —
## en esa época jugador y mob colisionaban físicamente y el solapamiento
## producía un empujón brusco; hoy los personajes no chocan entre sí (ver
## Jugador.tscn capa 8 / Enemigo.gd capa 2), así que caer solapado es
## inofensivo y frenar el teletransporte en un enemigo era puro estorbo
## ("la habilidad parpadeo choca con los enemigos", reportado).
@export_flags_2d_physics var capa_obstaculos: int = 1


func _ready() -> void:
	super._ready()
	nombre_habilidad = "Parpadeo"
	tipo_habilidad   = "parpadeo"
	requiere_direccion = true


func aplicar_datos(d: DatosHabilidad) -> void:
	super.aplicar_datos(d)
	if d.alcance_metros > 0:
		distancia_parpadeo = d.alcance_metros * ESCALA_METROS_PIXEL


func _ejecutar(direccion: Vector2, poder: float) -> void:
	if direccion.length() < 0.1 or not is_instance_valid(entidad_dueña):
		return
	var entidad := entidad_dueña as Node2D
	if not entidad:
		return

	var dir := direccion.normalized()
	var distancia := distancia_parpadeo * (poder if distancia_segun_poder else 1.0)
	var destino := entidad.global_position + dir * distancia

	if capa_obstaculos != 0:
		destino = _recortar_por_obstaculos(entidad, destino, dir)

	# Mismo criterio que HabilidadCargaJugador: mover la posición directo,
	# sin RPC dedicado — el jugador ya es autoridad de su propio movimiento
	# (ver Jugador._pedir_mover_red), así que esto se reconcilia solo con
	# el resto del flujo normal de posición.
	entidad.global_position = destino


## Reportado en juego real (20 sep 2026), sobre todo cerca de esquinas del
## Hormiguero: "cuando me acerco y uso parpadeo contra la pared, no me deja
## moverme después, se queda fijo". Causa real: el chequeo de obstáculos
## usaba un RAYO (ancho cero) desde el CENTRO de la entidad — un rayo puede
## pasar limpio justo al lado de una esquina que el cuerpo real (con su
## radio real, ver _forma_colision_de) sí toca, así que el teletransporte
## terminaba en un punto que el rayo veía libre pero que en los hechos se
## solapaba con la pared, dejando al jugador "adentro" de la geometría —
## desde ahí move_and_slide() ya no puede resolver ningún movimiento.
## Arreglo: barrer la FORMA real de la entidad (cast_motion), no un rayo.
func _recortar_por_obstaculos(entidad: Node2D, destino: Vector2, dir: Vector2) -> Vector2:
	var espacio := entidad.get_world_2d().direct_space_state
	var forma := _forma_colision_de(entidad)
	if forma == null:
		# Sin forma propia detectable: mismo comportamiento de siempre
		# (rayo), mejor que no frenar nada.
		var query_rayo := PhysicsRayQueryParameters2D.create(entidad.global_position, destino, capa_obstaculos)
		query_rayo.exclude = [entidad]
		var resultado_rayo := espacio.intersect_ray(query_rayo)
		if not resultado_rayo.is_empty():
			return (resultado_rayo.get("position") as Vector2) - dir * 8.0
		return destino

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = forma
	query.transform = Transform2D(0.0, entidad.global_position)
	query.motion = destino - entidad.global_position
	query.collision_mask = capa_obstaculos
	query.exclude = [entidad]
	var fracciones := espacio.cast_motion(query)
	var fraccion_segura: float = fracciones[0] if fracciones.size() > 0 else 1.0
	if fraccion_segura >= 1.0:
		return destino
	# Un pequeño margen extra hacia atrás (la forma ya viaja con su radio
	# real, no hace falta el margen grande que necesitaba el rayo) para no
	# quedar apenas rozando el borde de colisión.
	return entidad.global_position + query.motion * fraccion_segura - dir * 4.0


## La forma de colisión REAL de la entidad (CircleShape2D del jugador, o la
## que tenga cualquier mob que equipe esta habilidad — ver EnemigoLoboFeroz)
## para el barrido de _recortar_por_obstaculos(). null si no se encuentra
## (entidad sin "CollisionShape2D" hijo, o sin forma asignada).
func _forma_colision_de(entidad: Node2D) -> Shape2D:
	var col := entidad.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col and col.shape:
		return col.shape.duplicate()
	return null
