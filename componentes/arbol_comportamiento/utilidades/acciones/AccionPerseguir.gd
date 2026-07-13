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
## Multiplicador sobre componente_movimiento.velocidad_base SOLO mientras
## persigue (no afecta deambular/atacar/huir). 1.0 = sin cambio, el valor de
## siempre. Usado por Caballero Esqueleto (1.20) para perseguir más rápido
## que su velocidad base sin tocar velocidad_base en sí.
@export var multiplicador_velocidad: float = 1.0

var _ultima_vision: float = 0.0


func _on_ejecutar() -> Estado:
	var agente := _memoria.obtener("agente") as Node2D
	var movimiento: MovimientoComponente = _memoria.obtener("componente_movimiento")
	# Validar ANTES de castear: un objetivo liberado (p. ej. jugador
	# desconectado en red) hace que "as Node2D" reviente con "Trying to
	# cast a freed object" en vez de simplemente devolver null.
	var objetivo_raw = _memoria.obtener("objetivo")
	if not agente or not movimiento:
		return Estado.FALLIDO
	if not is_instance_valid(objetivo_raw):
		return Estado.FALLIDO
	# Mismo criterio que AccionAtacar: un jugador muerto sigue siendo un
	# nodo válido (reaparece, no se libera) — sin esto, un mob perseguía el
	# cadáver indefinidamente en vez de abandonar.
	if "_muerto" in objetivo_raw and objetivo_raw.get("_muerto"):
		_memoria.establecer("objetivo", null)
		_memoria.establecer("jugador_detectado", false)
		return Estado.FALLIDO
	var objetivo := objetivo_raw as Node2D

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
	movimiento.comandar_destino(objetivo.global_position, movimiento.velocidad_base * multiplicador_velocidad)
	return Estado.EXITOSO


func _on_entrar() -> void:
	super._on_entrar()
	_ultima_vision = Time.get_ticks_msec() / 1000.0
