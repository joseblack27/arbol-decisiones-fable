class_name HabilidadCarga
extends HabilidadBase
## Carga que atraviesa al jugador — el enemigo se lanza y solo se detiene al
## chocar con un obstáculo o al llegar a la distancia máxima.
##
## FASES:
##   INACTIVO → PREPARACION (enemigo quieto, apunta al jugador) → DASH

enum Fase { INACTIVO, PREPARACION, DASH }

## Emitida al entrar en la fase de preparación (enemigo se detiene y apunta).
signal preparacion_iniciada()
## Emitida cuando el dash realmente comienza.
signal carga_iniciada(direccion: Vector2, multiplicador_velocidad: float)
## Emitida cuando el dash termina (por cualquier condición).
signal carga_terminada()

@export_group("Preparación")
@export var duracion_preparacion: float          = 0.5

@export_group("Dash")
@export var daño_carga: float                    = 25.0
@export var multiplicador_velocidad_carga: float = 4.0
## Distancia máxima que puede recorrer el dash antes de terminar.
@export var distancia_maxima_dash: float         = 300.0
## Tiempo máximo de seguridad — evita un dash infinito si algo falla.
@export var duracion_maxima: float               = 1.5

@export_group("Dependencias")
## Referencia al componente de movimiento — aplica el dash directamente.
@export var componente_movimiento: MovimientoComponente

# ── Estado interno ────────────────────────────────────────────────────────────
var _fase: Fase                  = Fase.INACTIVO
var _timer_preparacion: float    = 0.0
var _timer_seguridad: float      = 0.0
var _direccion_carga: Vector2    = Vector2.RIGHT
var _distancia_recorrida: float  = 0.0
var _posicion_objetivo: Vector2  = Vector2.ZERO
var _ya_impacto: bool            = false

func _ready() -> void:
	super._ready()
	nombre_habilidad = "Carga"
	tipo_habilidad   = "carga"

func _process(delta: float) -> void:
	super._process(delta)  # Tick de recarga (HabilidadBase)

	match _fase:
		Fase.PREPARACION:
			_timer_preparacion += delta

			# Rastrear posición del objetivo mientras apuntamos
			var objetivo := _obtener_objetivo()
			if objetivo:
				_posicion_objetivo = objetivo.global_position
				var nueva_dir := (_posicion_objetivo - (entidad_dueña as Node2D).global_position).normalized()
				if nueva_dir.length() > 0.1:
					_direccion_carga = nueva_dir
					# Actualizar la dirección visible del enemigo
					if "direccion" in entidad_dueña:
						entidad_dueña.set("direccion", _direccion_carga)

			if _timer_preparacion >= duracion_preparacion:
				_iniciar_dash()

		Fase.DASH:
			_timer_seguridad += delta
			if _timer_seguridad >= duracion_maxima:
				_terminar_carga()


func _physics_process(delta: float) -> void:
	# Solo actúa durante el dash — durante PREPARACION el enemigo está quieto
	# gracias al modo recuperación de EstadoAtacar.
	if _fase != Fase.DASH or not componente_movimiento:
		return
	var entidad := entidad_dueña as CharacterBody2D
	if not entidad:
		return

	# ── Aplicar movimiento ────────────────────────────────────────────────────
	var vel       := multiplicador_velocidad_carga * componente_movimiento.velocidad_base
	var pos_antes := entidad.global_position
	componente_movimiento.physics_process(delta, _direccion_carga, vel)
	_distancia_recorrida += entidad.global_position.distance_to(pos_antes)

	# ── Daño al jugador si hay colisión durante el dash ──────────────────────
	if not _ya_impacto:
		var espacio := entidad.get_world_2d().direct_space_state
		var forma_query := CircleShape2D.new()
		forma_query.radius = 24.0
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape              = forma_query
		query.transform          = entidad.global_transform
		query.collision_mask     = 0xFFFFFFFF
		query.collide_with_bodies = true
		query.collide_with_areas  = true
		var hits := espacio.intersect_shape(query)
		for r in hits:
			var col = r.get("collider")
			if col == null or col == entidad_dueña:
				continue
			var objetivo: Node = col
			if col is VidaComponente:
				objetivo = col.get_parent()
			if objetivo == entidad_dueña:
				continue
			if objetivo.has_method("quitar_vida"):
				_ya_impacto = true
				var dano_final := AtributosComponente.calcular_pipeline(entidad_dueña, objetivo, daño_carga, tipo_dano)
				objetivo.quitar_vida(dano_final)
				BusEventos.daño_aplicado.emit(objetivo, dano_final, entidad_dueña)
				BusEventos.habilidad_impacto.emit("carga", objetivo)
				break

	# ── Condición 2: recorrió la distancia máxima ────────────────────────────
	if _distancia_recorrida >= distancia_maxima_dash:
		_terminar_carga()
		return

	# ── Condición 3: chocó con una pared ─────────────────────────────────────
	if entidad.is_on_wall():
		_terminar_carga()


# =============================================================================
# API pública
# =============================================================================

func _ejecutar(direccion: Vector2, _poder: float) -> void:
	_direccion_carga     = direccion if direccion.length() > 0.1 else Vector2.RIGHT
	_timer_preparacion   = 0.0
	_timer_seguridad     = 0.0
	_distancia_recorrida = 0.0

	# Capturar posición inicial del objetivo (para apuntar durante preparación)
	var objetivo := _obtener_objetivo()
	if objetivo and is_instance_valid(objetivo):
		_posicion_objetivo = objetivo.global_position

	_ya_impacto = false
	# Avisar al BT que hay un ataque en curso (antes lo hacía el wrapper en EnemigoLobo).
	if entidad_dueña and "memoria" in entidad_dueña:
		entidad_dueña.get("memoria").establecer("ataque_en_curso", true)
	_fase = Fase.PREPARACION
	_set_excepciones_jugador(true)
	preparacion_iniciada.emit()


func esta_cargando() -> bool:
	return _fase == Fase.DASH

func esta_preparando() -> bool:
	return _fase == Fase.PREPARACION

func obtener_direccion_carga() -> Vector2:
	return _direccion_carga

func obtener_multiplicador_velocidad() -> float:
	return multiplicador_velocidad_carga


# =============================================================================
# Internos
# =============================================================================

func _iniciar_dash() -> void:
	_fase            = Fase.DASH
	_timer_seguridad = 0.0
	carga_iniciada.emit(_direccion_carga, multiplicador_velocidad_carga)


func _terminar_carga() -> void:
	_fase = Fase.INACTIVO
	_set_excepciones_jugador(false)
	carga_terminada.emit()


func _set_excepciones_jugador(activar: bool) -> void:
	var enemigo := entidad_dueña as CharacterBody2D
	if not enemigo:
		return
	for jugador in enemigo.get_tree().get_nodes_in_group("jugadores"):
		if activar:
			enemigo.add_collision_exception_with(jugador)
		else:
			enemigo.remove_collision_exception_with(jugador)


func _obtener_objetivo() -> Node2D:
	if not (entidad_dueña and "memoria" in entidad_dueña):
		return null
	return entidad_dueña.get("memoria").obtener("objetivo") as Node2D
