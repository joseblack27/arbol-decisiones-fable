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
		var espacio := entidad.get_world_2d().direct_space_state
		var query := PhysicsRayQueryParameters2D.create(entidad.global_position, destino, capa_obstaculos)
		query.exclude = [entidad]
		var resultado := espacio.intersect_ray(query)
		if not resultado.is_empty():
			# Frenar un poco antes del obstáculo, no justo encima del borde
			# de colisión (podría quedar "adentro" de la pared).
			destino = (resultado.get("position") as Vector2) - dir * 8.0

	# Red de seguridad final: el raycast de arriba puede no detectar un tramo
	# localmente delgado del borde del mapa (esquinas diagonales del contorno
	# de colisión) — igual que MovimientoComponente._contener_dentro_del_mapa,
	# si el destino calculado queda fuera de la malla de navegación, se
	# recorta al punto navegable más cercano en vez de teletransportar ahí.
	var mapa: RID = entidad.get_world_2d().navigation_map
	if not NavigationServer2D.map_get_regions(mapa).is_empty():
		var punto_navegable: Vector2 = NavigationServer2D.map_get_closest_point(mapa, destino)
		if destino.distance_to(punto_navegable) > 6.0:
			destino = punto_navegable

	# Mismo criterio que HabilidadCargaJugador: mover la posición directo,
	# sin RPC dedicado — el jugador ya es autoridad de su propio movimiento
	# (ver Jugador._pedir_mover_red), así que esto se reconcilia solo con
	# el resto del flujo normal de posición.
	entidad.global_position = destino
