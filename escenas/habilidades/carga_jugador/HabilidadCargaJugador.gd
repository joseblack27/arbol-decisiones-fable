class_name HabilidadCargaJugador
extends HabilidadBase
## Dash direccional del jugador.
## Se activa con un JoystickHabilidad (tipo_habilidad = "carga").
## Va directo al DASH sin fase de preparación.

signal carga_iniciada(direccion: Vector2)
signal carga_terminada()

@export_group("Dash")
## Sobreescrito por DatosHabilidad.aplicar_datos() al equipar.
var dano_carga: float            = 20.0
var distancia_maxima_dash: float = 180.0
## Sin equivalente en DatosHabilidad — configurable manualmente.
@export var multiplicador_velocidad_carga: float = 5.0
@export var duracion_maxima: float               = 0.45

@export_group("Dependencias")
@export var componente_movimiento: MovimientoComponente

# ── Estado interno ────────────────────────────────────────────────────────────
var _en_dash: bool              = false
var _direccion_carga: Vector2   = Vector2.RIGHT
var _distancia_recorrida: float = 0.0
var _timer_seguridad: float     = 0.0
## Enemigos ya golpeados en ESTE dash — evita pegarle varias veces al mismo
## mob mientras dura el dash, pero permite golpear a varios mobs distintos
## si el corredor los toca a todos (antes, con un solo booleano "_ya_impacto",
## el primer golpe cerraba el daño para el resto del dash entero).
var _objetivos_golpeados: Array[Node] = []
var _dano_actual: int           = 0  # Calculado al inicio de cada dash


func _ready() -> void:
	super._ready()
	nombre_habilidad = "Dash"
	tipo_habilidad   = "carga"
	# Resolver componente_movimiento desde el jugador si no está asignado en Inspector
	if not componente_movimiento and is_instance_valid(entidad_dueña):
		componente_movimiento = entidad_dueña.get("componente_movimiento")


func _process(delta: float) -> void:
	super._process(delta)
	if _en_dash:
		_timer_seguridad += delta
		if _timer_seguridad >= duracion_maxima:
			_terminar()


func _physics_process(delta: float) -> void:
	if not _en_dash or not componente_movimiento:
		return
	var entidad := entidad_dueña as CharacterBody2D
	if not entidad:
		return

	# ── Movimiento ────────────────────────────────────────────────────────────
	var vel       := multiplicador_velocidad_carga * componente_movimiento.velocidad_base
	var pos_antes := entidad.global_position
	componente_movimiento.physics_process(delta, _direccion_carga, vel)
	_distancia_recorrida += entidad.global_position.distance_to(pos_antes)

	# ── Daño a enemigos durante el dash ───────────────────────────────────────
	# Se consulta cada fotograma (no solo hasta el primer golpe): así el dash
	# puede golpear a varios enemigos distintos si el corredor los toca a
	# todos, sin pegarle dos veces al mismo (ver _objetivos_golpeados).
	var espacio := entidad.get_world_2d().direct_space_state
	var forma_query := CircleShape2D.new()
	forma_query.radius = 24.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape              = forma_query
	query.transform          = entidad.global_transform
	query.collision_mask     = 0xFFFFFFFF
	query.collide_with_bodies = true
	query.collide_with_areas  = true
	for r in espacio.intersect_shape(query):
		var col = r.get("collider")
		if col == null or col == entidad_dueña:
			continue
		var objetivo: Node = col
		if col is VidaComponente:
			objetivo = col.get_parent()
		if objetivo == entidad_dueña or objetivo in _objetivos_golpeados:
			continue
		if objetivo.has_method("quitar_vida"):
			_objetivos_golpeados.append(objetivo)
			var dano_final := AtributosComponente.calcular_pipeline(entidad_dueña, objetivo, float(_dano_actual), tipo_dano)
			# Enemigos/jugadores reenvían el atacante a su VidaComponente
			# (para el log de Actividad Reciente en red); los genéricos
			# (Muro...) mantienen su firma de un solo argumento.
			if objetivo.is_in_group("enemigos") or objetivo.is_in_group("jugadores"):
				objetivo.quitar_vida(dano_final, entidad_dueña)
			else:
				objetivo.quitar_vida(dano_final)
			if Utils.debe_mostrar_dano_local():
				BusEventos.daño_aplicado.emit(objetivo, dano_final, entidad_dueña)
			BusEventos.habilidad_impacto.emit("carga_jugador", objetivo)

	# ── Condiciones de fin ────────────────────────────────────────────────────
	if _distancia_recorrida >= distancia_maxima_dash or entidad.is_on_wall():
		_terminar()


# =============================================================================
# API pública (llamada por HabilidadBase.activar)
# =============================================================================

func aplicar_datos(d: DatosHabilidad) -> void:
	super.aplicar_datos(d)
	distancia_maxima_dash = d.alcance_metros * ESCALA_METROS_PIXEL

func _ejecutar(direccion: Vector2, _poder: float) -> void:
	_direccion_carga     = direccion if direccion.length() > 0.1 else _ultima_direccion_jugador()
	_distancia_recorrida = 0.0
	_timer_seguridad     = 0.0
	_objetivos_golpeados.clear()
	_en_dash             = true
	_dano_actual         = _calcular_dano(int(dano_carga))
	_set_excepciones_enemigos(true)
	carga_iniciada.emit(_direccion_carga)


# =============================================================================
# Internos
# =============================================================================

func _terminar() -> void:
	_en_dash = false
	_set_excepciones_enemigos(false)
	carga_terminada.emit()


func _set_excepciones_enemigos(activar: bool) -> void:
	var jugador := entidad_dueña as CharacterBody2D
	if not jugador:
		return
	for enemigo in jugador.get_tree().get_nodes_in_group("enemigos"):
		if activar:
			jugador.add_collision_exception_with(enemigo)
		else:
			jugador.remove_collision_exception_with(enemigo)


func _ultima_direccion_jugador() -> Vector2:
	if entidad_dueña and "direccion" in entidad_dueña:
		var dir: Vector2 = entidad_dueña.get("direccion")
		if dir.length() > 0.1:
			return dir.normalized()
	return Vector2.RIGHT
