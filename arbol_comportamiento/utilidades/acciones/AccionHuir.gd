# =============================================================================
# AccionHuir.gd  (Acción)
#
# Huye en dirección opuesta al objetivo durante N segundos con velocidad
# aumentada. Es la ÚNICA acción del enemigo que retorna EN_EJECUCION:
# la huida es un compromiso que debe completarse (el Selector con memoria
# se queda en esta rama hasta que termine).
#
# El cooldown de huida NO vive aquí: envolver este nodo con un decorador
# Enfriamiento (solo_al_exitoso = true). Eso reemplaza a las banderas
# esta_huyendo / huida_en_cooldown / tiempo_cooldown_huida / en_recuperacion.
#
# RETORNA:
#   EN_EJECUCION → huyendo.
#   EXITOSO      → huida completada (aquí arranca el Enfriamiento padre).
#
# MEMORIA:
#   lee "agente", "componente_movimiento", "objetivo"
# =============================================================================
class_name AccionHuir
extends Accion

@export_group("Configuración Huida")
## Segundos que dura la huida activa.
@export var duracion_huida: float = 3.0
## Multiplicador sobre la velocidad base del MovimientoComponente.
@export var multiplicador_velocidad: float = 1.5

var _fin_huida: float = 0.0
var _direccion_huida: Vector2 = Vector2.ZERO


func _on_entrar() -> void:
	super._on_entrar()
	_fin_huida = Time.get_ticks_msec() / 1000.0 + duracion_huida
	# Dirección inicial por si no hay objetivo conocido.
	_direccion_huida = Vector2.from_angle(randf_range(0.0, TAU))


func _on_ejecutar() -> Estado:
	var agente := _memoria.obtener("agente") as Node2D
	var movimiento: MovimientoComponente = _memoria.obtener("componente_movimiento")
	if not agente or not movimiento:
		return Estado.FALLIDO

	if Time.get_ticks_msec() / 1000.0 >= _fin_huida:
		movimiento.detener()
		return Estado.EXITOSO

	# Actualizar dirección de escape mientras el objetivo siga siendo válido.
	var objetivo := _memoria.obtener("objetivo") as Node2D
	if objetivo and is_instance_valid(objetivo):
		_direccion_huida = (agente.global_position - objetivo.global_position).normalized()

	if "direccion" in agente:
		agente.set("direccion", _direccion_huida)
	movimiento.comandar_direccion(_direccion_huida, movimiento.velocidad_base * multiplicador_velocidad)
	return Estado.EN_EJECUCION
