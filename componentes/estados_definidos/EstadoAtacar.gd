extends Node

# =============================================================================
# ⚔️ ATACAR STATE
# Estado responsable de seleccionar y ejecutar habilidades de ataque.
#
# RECUPERACIÓN POST-ATAQUE:
#   Tras cualquier habilidad exitosa, el enemigo se queda quieto N segundos.
#   Durante ese tiempo, escribe "en_recuperacion = true" en la memoria para
#   que el Guardia del árbol bloquee cualquier cambio de estado.
#
# MOVIMIENTO INTELIGENTE:
#   Si hay habilidades libres (sin cooldown) pero fuera de rango → se acerca.
#   Si todo está en cooldown o en rango → quieto.
#
# TRANSICIONES:
#   → EstadoPersigue  : objetivo supera distancia_maxima_ataque o se pierde.
#   → EstadoDeambular : objetivo perdido por demasiado tiempo.
# =============================================================================

# --- DEPENDENCIAS EXTERNAS ---
@export var maquina_de_estados: MaquinaDeEstadosComponente
@export var entidad: Node2D
@export var componente_movimiento: MovimientoComponente
@export var vision_componente: VisionComponente
@export var memoria: MemoriaBT
@export var selector_habilidades: SelectorHabilidades

# --- CONFIGURACIÓN ---
## Distancia máxima para permanecer en ataque. Debe ser >= rango máximo de tus habilidades.
@export var distancia_maxima_ataque: float = 200.0
## Velocidad al acercarse para entrar en rango de una habilidad disponible.
@export var velocidad_aproximacion: float = 60.0
## Segundos de pausa tras ejecutar cualquier habilidad.
@export var duracion_recuperacion: float = 1.0
## Segundos entre cada intento de seleccionar una habilidad.
@export var intervalo_entre_intentos: float = 0.3
## Segundos sin objetivo antes de transicionar.
@export var tiempo_limite_sin_objetivo: float = 1.5

# --- ESTADO INTERNO ---
var _objetivo_actual: Node2D = null
var _tiempo_hasta_intento: float = 0.0
var _tiempo_sin_objetivo: float = 0.0
var _en_recuperacion: bool = false
var _tiempo_recuperacion: float = 0.0


func _ready() -> void:
	if selector_habilidades and memoria:
		selector_habilidades.inicializar(memoria)
	
	memoria.variable_cambiada.connect(_on_memoria_variable_cambiada)


func _on_memoria_variable_cambiada(nombre: String, anterior, _nuevo) -> void:
	# Ignorar si no somos el estado activo — evita que señales de AtaqueMordida
	# o limpiezas de EstadoHuir disparen _iniciar_recuperacion() fuera de turno.
	if maquina_de_estados.estado_actual != "EstadoAtacar":
		return

	if nombre == "habilidad_lanzada":
		var habilidad_lanzada: bool = memoria.obtener("habilidad_lanzada", false)
		if habilidad_lanzada == true:
			memoria.establecer("habilidad_lanzada", false)
			_iniciar_recuperacion()

	# Cuando la mordida termina, reiniciar recovery limpia.
	if nombre == "ataque_en_curso" and anterior == true:
		_iniciar_recuperacion()


func iniciar_estado() -> void:
	_objetivo_actual = memoria.obtener("objetivo")
	_tiempo_hasta_intento = 0.0
	_tiempo_sin_objetivo  = 0.0
	_en_recuperacion      = false
	_tiempo_recuperacion  = 0.0

	# Limpiar flags que podrían haber quedado sucios de un ataque interrumpido
	# (p.ej. la mordida fue cortada por la huida antes de terminar).
	memoria.establecer("habilidad_lanzada", false)
	memoria.establecer("ataque_en_curso",   false)

	if not _objetivo_actual:
		maquina_de_estados.cambiar_estado("EstadoPersigue")
		return

	memoria.establecer("en_combate",     true)
	memoria.establecer("en_recuperacion", false)


func procesar_estado(delta: float) -> void:
	# ── RECUPERACIÓN POST-ATAQUE ───────────────────────────────────────────────
	# Durante la recuperación: quieto, sin atacar, sin cambiar de estado.
	# El Guardia del árbol también bloquea transiciones externas.
	#if _en_recuperacion:
		#componente_movimiento.physics_process(delta, Vector2.ZERO)
		## Pausar el timer mientras un ataque de larga duración siga activo.
		## Cuando termine (ataque_en_curso = false) el listener reinicia recovery.
		#if not memoria.obtener("ataque_en_curso", false):
			#_tiempo_recuperacion -= delta
			#if _tiempo_recuperacion <= 0.0:
				#_en_recuperacion = false
				#memoria.establecer("en_recuperacion", false)
		#return
	
	if _en_recuperacion:
		componente_movimiento.physics_process(delta, Vector2.ZERO)
		if not memoria.obtener("ataque_en_curso", false):
			_tiempo_recuperacion -= delta
			if _tiempo_recuperacion <= 0.0:
				_en_recuperacion = false
				memoria.establecer("en_recuperacion", false)
		return

	# ── LÓGICA NORMAL ──────────────────────────────────────────────────────────

	# 1. Actualizar objetivo.
	_objetivo_actual = _buscar_objetivo_mas_cercano()

	if not _objetivo_actual:
		componente_movimiento.physics_process(delta, Vector2.ZERO)
		_tiempo_sin_objetivo += delta
		if _tiempo_sin_objetivo >= tiempo_limite_sin_objetivo:
			_salir_del_ataque("EstadoPersigue")
		return

	_tiempo_sin_objetivo = 0.0
	memoria.establecer("objetivo", _objetivo_actual)

	# 2. Calcular distancia real.
	var distancia: float = entidad.global_position.distance_to(
		_objetivo_actual.global_position
	)

	# 3. Objetivo demasiado lejos → perseguir.
	if distancia > distancia_maxima_ataque:
		maquina_de_estados.cambiar_estado("EstadoPersigue")
		return

	# 4. Orientar hacia el objetivo.
	entidad.direccion = (
		_objetivo_actual.global_position - entidad.global_position
	).normalized()

	# 5. Intentar ejecutar una habilidad cada N segundos.
	_tiempo_hasta_intento -= delta
	if _tiempo_hasta_intento <= 0.0:
		_tiempo_hasta_intento = intervalo_entre_intentos
		var resultado: NodoBT.Estado = selector_habilidades.ejecutar()
		if resultado == NodoBT.Estado.EXITOSO:
			_iniciar_recuperacion()
			return  # El return evita mover al enemigo en el mismo frame del ataque.

	# 6. Decidir movimiento según disponibilidad de habilidades.
	if selector_habilidades.hay_habilidades_fuera_de_rango(distancia):
		var dir := (
			_objetivo_actual.global_position - entidad.global_position
		).normalized()
		componente_movimiento.physics_process(delta, dir * velocidad_aproximacion)
	else:
		componente_movimiento.physics_process(delta, Vector2.ZERO)


# =============================================================================
# RECUPERACIÓN
# =============================================================================


func _iniciar_recuperacion() -> void:
	_en_recuperacion     = true
	_tiempo_recuperacion = duracion_recuperacion
	memoria.establecer("en_recuperacion", true)
	componente_movimiento.physics_process(0.0, Vector2.ZERO)


# =============================================================================
# BÚSQUEDA DE OBJETIVO
# =============================================================================


func _buscar_objetivo_mas_cercano() -> Node2D:
	var lista: Array[Area2D] = vision_componente.areas_detectadas.values()
	var mas_cercano: Node2D  = null
	var distancia_minima: float = INF

	for area in lista:
		var nodo := area.owner as Node2D
		if nodo:
			var dist: float = nodo.global_position.distance_to(entidad.global_position)
			if dist < distancia_minima:
				distancia_minima = dist
				mas_cercano      = nodo

	# Fallback: si el cono de visión no detecta nada (jugador al lado/detrás),
	# conservar el _objetivo_actual en lugar de perder el combate por una salida
	# momentánea del área de detección. Solo se pierde si el nodo ya no existe.
	if mas_cercano == null and _objetivo_actual and is_instance_valid(_objetivo_actual):
		mas_cercano = _objetivo_actual

	return mas_cercano


# =============================================================================
# TRANSICIONES
# =============================================================================

func _salir_del_ataque(estado_destino: String) -> void:
	_en_recuperacion = false
	memoria.establecer("en_recuperacion", false)
	memoria.establecer("en_combate",      false)
	selector_habilidades.reiniciar()
	maquina_de_estados.cambiar_estado(estado_destino)
