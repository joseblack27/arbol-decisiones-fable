extends Node
class_name EstadoHuir

# =============================================================================
# 🏃 HUIR STATE
# El enemigo huye en dirección contraria al jugador con velocidad aumentada
# durante `duracion_huida` segundos.
#
# Al terminar, activa un cooldown (escrito en MemoriaBT) durante el cual
# no puede volver a huir. Mientras el cooldown esté activo, la transición
# a este estado queda bloqueada desde Enemigo.gd.
#
# TRANSICIÓN DE ENTRADA:
#   Enemigo.gd → _on_memoria_variable_cambiada:
#     vida_baja == true  AND  jugador_detectado == true
#     AND  huida_en_cooldown == false  AND  esta_huyendo == false
#
# TRANSICIÓN DE SALIDA (al terminar duracion_huida):
#   jugador_detectado == true  → EstadoPersigue
#   jugador_detectado == false → EstadoDeambular
# =============================================================================

# --- DEPENDENCIAS ---
@export var maquina_de_estados: MaquinaDeEstadosComponente
@export var entidad: Node2D
@export var componente_movimiento: MovimientoComponente
@export var vision_componente: VisionComponente
@export var memoria: MemoriaBT

# --- CONFIGURACIÓN ---
## Segundos que el enemigo huye activamente.
@export var duracion_huida: float = 3.0
## Multiplicador sobre la velocidad base del MovimientoComponente.
@export var multiplicador_velocidad: float = 1.5
## Segundos tras la huida en los que no puede volver a huir.
@export var duracion_cooldown: float = 10.0

# --- ESTADO INTERNO ---
var _tiempo_huyendo: float = 0.0
var _direccion_huida: Vector2 = Vector2.ZERO


# =============================================================================
# CICLO DE ESTADO
# =============================================================================

func iniciar_estado() -> void:
	_tiempo_huyendo = 0.0

	# IMPORTANTE: mantener en_recuperacion = true durante toda la huida para
	# que GuardiaEnRecuperacion bloquee la rama de combate del árbol BT.
	# Sin esto, el siguiente tick del árbol (0.1s) dispara AccionCambiarEstado
	# ("EstadoAtacar") y sobreescribe el EstadoHuir inmediatamente.
	# en_recuperacion se limpia en _finalizar_huida() al terminar la huida.
	memoria.establecer("en_recuperacion",  true)
	memoria.establecer("ataque_en_curso",  false)
	memoria.establecer("habilidad_lanzada", false)

	# Calcular dirección inicial: opuesta al jugador.
	var objetivo := memoria.obtener("objetivo") as Node2D
	if objetivo and is_instance_valid(objetivo):
		_direccion_huida = (entidad.global_position - objetivo.global_position).normalized()
	else:
		# Sin objetivo conocido: dirección aleatoria.
		_direccion_huida = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()

	memoria.establecer("esta_huyendo", true)


func procesar_estado(delta: float) -> void:
	_tiempo_huyendo += delta

	# Actualizar dirección dinámicamente mientras el jugador sea visible.
	var objetivo := memoria.obtener("objetivo") as Node2D
	if objetivo and is_instance_valid(objetivo):
		_direccion_huida = (entidad.global_position - objetivo.global_position).normalized()

	# Aplicar movimiento con velocidad aumentada.
	entidad.direccion = _direccion_huida
	var velocidad_huida: float = componente_movimiento.velocidad_base * multiplicador_velocidad
	componente_movimiento.physics_process(delta, _direccion_huida, velocidad_huida)

	# Terminar la huida al agotar el tiempo.
	if _tiempo_huyendo >= duracion_huida:
		_finalizar_huida()


# =============================================================================
# LÓGICA INTERNA
# =============================================================================

func _finalizar_huida() -> void:
	componente_movimiento.physics_process(0.0, Vector2.ZERO)
	memoria.establecer("esta_huyendo",         false)
	memoria.establecer("en_recuperacion",      false)   # Re-habilitar rama de combate del BT
	memoria.establecer("huida_en_cooldown",    true)
	memoria.establecer("tiempo_cooldown_huida", duracion_cooldown)

	# Siempre ir a EstadoPersigue: el enemigo debe volver a buscar al jugador.
	# EstadoPersigue perseguirá la última posición conocida aunque el jugador
	# haya salido del rango de visión durante la huida.
	maquina_de_estados.cambiar_estado("EstadoPersigue")
