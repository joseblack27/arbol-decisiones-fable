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
## Punto al que apunta mientras persigue (nunca el centro exacto del
## objetivo) — mismo motivo y mismo valor que AccionAtacar.distancia_minima_
## acercamiento (ver ese comentario largo para el porqué del valor exacto:
## tiene que quedar bien por debajo de distancia_ataque, o el mob se traba a
## mitad de camino por MovimientoComponente.MARGEN_DESTINO). Sin este freno,
## un mob cuya habilidad tiene requiere_acercarse=false (ej. Arañazo de la
## Araña) queda pegado al jugador porque quien lo trae hasta acá es esta
## acción, no AccionAtacar.
## Subido de 20 a 50 (pedido del usuario: "que no sea tan pegado"), mismo
## valor que AccionAtacar — sigue bien por debajo de distancia_ataque (170,
## o 180 en Araña/ArañaReina), ningún mob tiene ese margen ajustado.
@export var distancia_minima_acercamiento: float = 50.0

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
	# Muerto U OCULTO: en los dos casos deja de ser objetivo. Sin el corte por
	# camuflaje, un mob que ya te tenía fichado seguía persiguiendo tu última
	# posición conocida unos segundos, o seguía pegándote si te tenía a
	# distancia — y el camuflaje no serviría para lo único que se hizo:
	# despegarte de una pelea.
	if _objetivo_perdido(objetivo_raw):
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
	movimiento.comandar_destino(_punto_de_acercamiento(agente, objetivo), movimiento.velocidad_base * multiplicador_velocidad)
	return Estado.EXITOSO


## Punto al que se acerca — nunca el centro exacto del objetivo (ver el
## @export distancia_minima_acercamiento). Mismo cálculo que AccionAtacar.
func _punto_de_acercamiento(agente: Node2D, objetivo: Node2D) -> Vector2:
	var hacia_agente := agente.global_position - objetivo.global_position
	if hacia_agente.length() < 1.0:
		hacia_agente = Vector2.RIGHT
	return objetivo.global_position + hacia_agente.normalized() * distancia_minima_acercamiento


func _on_entrar() -> void:
	super._on_entrar()
	_ultima_vision = Time.get_ticks_msec() / 1000.0


## true si el objetivo dejó de contar: muerto (sigue siendo un nodo válido
## porque reaparece, no se libera) u oculto (ver CamuflajeComponente).
func _objetivo_perdido(objetivo) -> bool:
	if "_muerto" in objetivo and objetivo.get("_muerto"):
		return true
	# Por nombre de nodo, no por tipo: ver la nota en
	# VisionComponente._es_objetivo_valido sobre por qué no se referencia la
	# clase CamuflajeComponente desde acá.
	var camuflaje = objetivo.get_node_or_null("CamuflajeComponente")
	return camuflaje != null and camuflaje.esta_activo()
