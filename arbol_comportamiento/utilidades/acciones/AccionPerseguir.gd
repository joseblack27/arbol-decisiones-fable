# =============================================================================
# AccionPerseguir.gd  (Acción)
#
# Persigue al objetivo de la memoria hasta ponerse a distancia de ataque.
# Si el objetivo sale de la visión, persigue su última posición conocida
# durante unos segundos antes de rendirse (reemplaza el timer de pérdida
# de EstadoPersigue).
#
# RETORNA:
#   EXITOSO  → di un paso de persecución O ya estoy en rango de ataque.
#              (por paso: el Selector raíz re-evalúa prioridades cada tick)
#   FALLIDO  → sin objetivo, o me rendí (lo borra de la memoria).
#
# MEMORIA:
#   lee  "agente", "componente_movimiento", "objetivo", "jugador_detectado"
#   escribe "objetivo" = null al rendirse
# =============================================================================
class_name AccionPerseguir
extends Accion

@export_group("Configuración Persecución")
## Distancia a la que deja de acercarse (histéresis: algo menor que la
## distancia máxima de ataque para no oscilar entre atacar/perseguir).
@export var distancia_ataque: float = 170.0
## Si el objetivo está más lejos que esto, se abandona la persecución.
@export var distancia_abandono: float = 500.0
## Segundos persiguiendo la última posición conocida sin visión antes de rendirse.
@export var tiempo_maximo_sin_vision: float = 4.0

var _ultima_vision: float = 0.0


func _on_ejecutar() -> Estado:
	var agente := _memoria.obtener("agente") as Node2D
	var movimiento: MovimientoComponente = _memoria.obtener("componente_movimiento")
	var objetivo := _memoria.obtener("objetivo") as Node2D
	if not agente or not movimiento:
		return Estado.FALLIDO
	if not objetivo or not is_instance_valid(objetivo):
		return Estado.FALLIDO

	var ahora := Time.get_ticks_msec() / 1000.0
	if _memoria.obtener("jugador_detectado", false):
		_ultima_vision = ahora

	var distancia := agente.global_position.distance_to(objetivo.global_position)

	# Rendirse: demasiado lejos o demasiado tiempo sin verlo.
	if distancia > distancia_abandono or (ahora - _ultima_vision) > tiempo_maximo_sin_vision:
		_memoria.establecer("objetivo", null)
		movimiento.detener()
		return Estado.FALLIDO

	# Ya está a distancia de ataque: quieto y éxito (el próximo tick atacará).
	if distancia <= distancia_ataque:
		movimiento.detener()
		return Estado.EXITOSO

	# Con NavigationAgent2D asignado, rodea obstáculos; sin él, línea recta.
	movimiento.comandar_destino(objetivo.global_position)
	return Estado.EXITOSO


func _on_entrar() -> void:
	super._on_entrar()
	_ultima_vision = Time.get_ticks_msec() / 1000.0
