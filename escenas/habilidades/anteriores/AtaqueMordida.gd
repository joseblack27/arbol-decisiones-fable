extends Area2D
class_name AtaqueMordida

# =============================================================================
# AtaqueMordida  (hijo de Habilidades Marker2D)
#
# Gestiona las tres fases del ataque de mordida:
#   PREPARACION → quieto, rastrea al jugador, avisa al enemigo para animar
#   MOVIENDO    → dash; avisa al enemigo para animar el dash
#   IMPACTO     → reproduce su propio efecto visual + activa el hitbox
#
# Este nodo NO controla las animaciones del cuerpo del enemigo.
# Emite señales por fase para que Enemigo.gd las delegue a AnimacionComponente.
# =============================================================================

enum Fase { INACTIVO, PREPARACION, MOVIENDO, IMPACTO }

@export_group("Dependencias")
@export var componente_movimiento: MovimientoComponente
@export var componente_animacion: AnimacionComponente

@export_group("Tiempos")
@export var duracion_preparacion: float = 0.5

@export_group("Dash")
@export var distancia_dash: float = 100.0
@export var velocidad_dash: float = 380.0
@export var distancia_minima_impacto: float = 32.0

@onready var forma: CollisionShape2D = $CollisionShape2D
@onready var animacion: AnimationPlayer = $AnimationPlayer
@onready var sprite_2d: Sprite2D = $Sprite2D

# ─── Señales ──────────────────────────────────────────────────────────────────

## Avisa al Enemigo para que AnimacionComponente reproduzca la animación de carga.
signal fase_preparacion_iniciada()
## Avisa al Enemigo para que AnimacionComponente reproduzca la animación de dash.
signal fase_dash_iniciada()
## Avisa al Enemigo para que AnimacionComponente reproduzca la animación de impacto.
signal fase_impacto_iniciada()
## Emitida al detectar contacto durante el impacto. Enemigo aplica el daño.
signal golpe_conectado(cuerpo: Node2D, golpe: float)
## Emitida al terminar el ataque completo.
signal ataque_completado()

# ─── Estado interno ───────────────────────────────────────────────────────────
var _fase: Fase = Fase.INACTIVO
var _timer: float = 0.0
var _entidad: CharacterBody2D = null
var _objetivo: Node2D = null
var _memoria: MemoriaBT = null
var _direccion_dash: Vector2 = Vector2.ZERO
var _distancia_recorrida: float = 0.0
var _distancia_a_recorrer: float = 0.0

var _posicion_objetivo: Vector2 = Vector2.ZERO

func _ready() -> void:
	forma.disabled = true
	area_entered.connect(_on_area_entrada)


func _physics_process(delta: float) -> void:
	sprite_2d.global_rotation = 0
	
	match _fase:
		Fase.PREPARACION: _procesar_preparacion(delta)
		Fase.MOVIENDO:    _procesar_movimiento(delta)
		Fase.IMPACTO:
			componente_movimiento.physics_process(delta, Vector2.ZERO)


# =============================================================================
# API PÚBLICA
# =============================================================================

## Compatibilidad con SelectorHabilidades (ruta_nodo).
## Obtiene entidad, objetivo y memoria desde la jerarquía de nodos.
func activar(_direccion: Vector2 = Vector2.ZERO, _poder: float = 1.0) -> void:
	var entidad := get_parent().get_parent() as CharacterBody2D
	if entidad == null:
		push_error("AtaqueMordida.activar(): no se encontró CharacterBody2D en get_parent().get_parent()")
		return
	var mem: MemoriaBT = entidad.get("memoria") if "memoria" in entidad else null
	# Validar ANTES de castear: un objetivo liberado (jugador desconectado
	# en red) revienta el "as" con "Trying to cast a freed object".
	var objetivo_raw = mem.obtener("objetivo") if mem else null
	var objetivo: Node2D = objetivo_raw if is_instance_valid(objetivo_raw) else null
	lanzar(entidad, objetivo, mem)


func lanzar(entidad: CharacterBody2D, objetivo: Node2D, memoria: MemoriaBT) -> bool:
	if _fase != Fase.INACTIVO:
		return false

	_entidad  = entidad
	_objetivo = objetivo
	_memoria  = memoria
	_distancia_recorrida = 0.0

	# Capturar la posición inicial del objetivo.
	# Si el objetivo es null desde el inicio, usar la posición del propio enemigo
	# como fallback para no romper el ataque.
	if _objetivo and is_instance_valid(_objetivo):
		_posicion_objetivo = _objetivo.global_position
	else:
		_posicion_objetivo = _entidad.global_position

	_memoria.establecer("ataque_en_curso", true)
	_cambiar_fase(Fase.PREPARACION)
	fase_preparacion_iniciada.emit()
	return true


## Track de método del AnimationPlayer — frame activo del golpe.
func activar_colision() -> void:
	forma.disabled = false


## Track de método del AnimationPlayer — frame activo termina.
func desactivar_colision() -> void:
	forma.disabled = true


## Track de método del AnimationPlayer — último frame de mordida_impacto.
func finalizar_ataque() -> void:
	_cambiar_fase(Fase.INACTIVO)
	if _memoria:
		_memoria.establecer("congelar_rotacion", false)
		_memoria.establecer("ataque_en_curso",   false)
	ataque_completado.emit()


# =============================================================================
# FASES
# =============================================================================

func _procesar_preparacion(delta: float) -> void:
	_timer += delta

	if _objetivo and is_instance_valid(_objetivo):
		_posicion_objetivo = _objetivo.global_position

	if _entidad and _posicion_objetivo != Vector2.ZERO:
		var dir := (_posicion_objetivo - _entidad.global_position).normalized()
		if dir != Vector2.ZERO:
			_entidad.set("direccion", dir)
			# Actualizar blend directamente desde aquí — corre DESPUÉS
			# de Enemigo._physics_process, así no hay delay de 1 frame.
			if componente_animacion:
				componente_animacion.actualizar_blend(dir)

	componente_movimiento.physics_process(delta, Vector2.ZERO)

	if _timer >= duracion_preparacion:
		_distancia_a_recorrer = clamp(
			_entidad.global_position.distance_to(_posicion_objetivo),
			0,
			distancia_dash - distancia_minima_impacto
		)
		_iniciar_dash()


func _iniciar_dash() -> void:
	_direccion_dash = _entidad.get("direccion") if _entidad else Vector2.RIGHT
	if _direccion_dash == Vector2.ZERO:
		_direccion_dash = Vector2.RIGHT

	if _memoria:
		_memoria.establecer("congelar_rotacion", true)   # ← añadir

	_distancia_recorrida = 0.0
	_cambiar_fase(Fase.MOVIENDO)
	fase_dash_iniciada.emit()


func _procesar_movimiento(delta: float) -> void:
	# Usar posición cacheada en lugar de _objetivo directo.
	if _entidad:
		var dist := _entidad.global_position.distance_to(_posicion_objetivo)
		if dist <= distancia_minima_impacto:
			componente_movimiento.physics_process(0.0, Vector2.ZERO)
			_iniciar_impacto()
			return

	var pos_antes := _entidad.global_position
	componente_movimiento.physics_process(delta, _direccion_dash, velocidad_dash)
	_distancia_recorrida += _entidad.global_position.distance_to(pos_antes)

	var llego_al_final  := _distancia_recorrida >= _distancia_a_recorrer
	var choco_obstaculo := _entidad.is_on_wall() or _entidad.is_on_ceiling()

	if llego_al_final or choco_obstaculo:
		componente_movimiento.physics_process(0.0, Vector2.ZERO)
		_iniciar_impacto()


func _iniciar_impacto() -> void:
	_cambiar_fase(Fase.IMPACTO)
	fase_impacto_iniciada.emit()
	# El efecto visual de la mordida se reproduce aquí.
	animacion.stop()
	animacion.play("mordida_impacto")
	await animacion.animation_finished
	finalizar_ataque()


# =============================================================================
# HELPERS
# =============================================================================

func _cambiar_fase(nueva: Fase) -> void:
	_fase = nueva
	_timer = 0.0


func _on_area_entrada(area: Area2D) -> void:
	if _fase != Fase.IMPACTO or forma.disabled:
		return
	golpe_conectado.emit(area, 30.0)
