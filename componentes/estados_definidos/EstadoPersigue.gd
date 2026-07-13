extends Node
class_name EstadoPersigue

# =============================================================================
# 🎯 PERSIGUE STATE
# Estado responsable de perseguir al objetivo más cercano detectado por VisionComponente.
# Implementa la lógica de búsqueda de objetivo y movimiento dirigido.
# ===================================================================================

# --- DEPENDENCIAS EXTERNAS (Exportadas) ---
@export var maquina_de_estados: MaquinaDeEstadosComponente # Referencia a la máquina de estados principal
@export var vision_componente: VisionComponente # Referencia al VisionComponente (debe estar en el mismo nodo o accesible)
@export var componente_movimiento: MovimientoComponente # Componente que aplica el movimiento físico
@export var entidad: Node2D # La entidad que está en estado (el enemigo)

## Multiplicador sobre componente_movimiento.velocidad_base SOLO mientras
## persigue (no afecta deambular/huir). 1.0 = sin cambio, el valor de
## siempre. Usado por Caballero Esqueleto (1.20) para perseguir más rápido
## que su velocidad base sin tocar velocidad_base en sí.
@export var multiplicador_velocidad: float = 1.0

# Variables de estado interno
var objetivo_actual: Node2D = null
var tiempo_de_perdida_objetivo: float = 0.0
var intervalo_objetivo_perdido: float = 2.0 # Tiempo antes de considerar que el objetivo se ha perdido y cambiar de estado.

func _ready():
	pass

# Método llamado por MáquinaDeEstadosComponente al entrar en este estado.
func iniciar_estado():
	tiempo_de_perdida_objetivo = 0.0
	# Intentar obtener el objetivo más cercano desde el cono de visión.
	var objetivo := buscar_y_establecer_objetivo()
	if objetivo:
		objetivo_actual = objetivo
	# Fallback: si el cono no detecta nada, leer el último objetivo conocido
	# de la MemoriaBT del enemigo (vía entidad). Cubre el caso en que el
	# jugador salió del cono durante el ataque y objetivo_perdido borró
	# areas_detectadas pero NO borró memoria["objetivo"].
	elif not (objetivo_actual and is_instance_valid(objetivo_actual)):
		if entidad and "memoria" in entidad:
			# Validar ANTES de castear: un objetivo liberado (jugador
			# desconectado en red) revienta el "as" con "Trying to cast a
			# freed object".
			var objetivo_raw = entidad.memoria.obtener("objetivo")
			objetivo_actual = objetivo_raw if is_instance_valid(objetivo_raw) else null

# Sobrescribe el método de procesamiento de estado de la MáquinaDeEstadosComponente.
func procesar_estado(delta: float):
	var objetivo_detectado: Node2D = buscar_y_establecer_objetivo()

	if objetivo_detectado:
		objetivo_actual = objetivo_detectado
		tiempo_de_perdida_objetivo = 0.0

		var vector_destino: Vector2 = objetivo_actual.global_position - entidad.global_position
		var movimiento_calculado: Vector2 = vector_destino.normalized() * componente_movimiento.velocidad_base * multiplicador_velocidad

		entidad.direccion = vector_destino.normalized()

		if entidad.global_position.distance_to(objetivo_actual.global_position) <= 10:
			componente_movimiento.physics_process(delta, Vector2.ZERO)
			maquina_de_estados.cambiar_estado("EstadoIdle")
		else:
			componente_movimiento.physics_process(delta, movimiento_calculado)

	else:
		# Sin objetivo en el cono de visión: moverse hacia la última posición
		# conocida Y contar el tiempo de pérdida. Si el jugador vuelve al cono
		# antes de que expire el timer, se reinicia el contador (ver rama if).
		# Si el timer expira → el jugador se fue de verdad → Deambular.
		tiempo_de_perdida_objetivo += delta
		if objetivo_actual and is_instance_valid(objetivo_actual):
			var dir := (objetivo_actual.global_position - entidad.global_position).normalized()
			entidad.direccion = dir
			componente_movimiento.physics_process(delta, dir * componente_movimiento.velocidad_base * multiplicador_velocidad)
		else:
			componente_movimiento.physics_process(delta, Vector2.ZERO)
		if tiempo_de_perdida_objetivo > intervalo_objetivo_perdido:
			objetivo_actual = null
			maquina_de_estados.cambiar_estado("EstadoDeambular")


# --- Lógica de Persecución ---

## Intenta obtener el objetivo más cercano de la visión.
## @return El Node2D objetivo más cercano, o null si no se encuentra ninguno.
func buscar_y_establecer_objetivo() -> Node2D:
	# Usamos la función de visión para obtener la lista de objetivos
	var lista_objetivos: Array[Area2D] = vision_componente.areas_detectadas.values()
	
	var objetivo_mas_cercano: Node2D = null
	var distancia_minima: float = INF
	
	for area in lista_objetivos:
		# La referencia debe ser el componente o el área que contiene al objetivo.
		var objetivo_node: Node2D = area.get_parent()
		
		if objetivo_node:
			var distancia: float = objetivo_node.global_position.distance_to(entidad.global_position)
			
			if distancia < distancia_minima:
				distancia_minima = distancia
				objetivo_mas_cercano = objetivo_node
				
	return objetivo_mas_cercano

## Establece el objetivo más cercano y reinicia el temporizador de pérdida.
func establecer_objetivo_inicial():
	var objetivo: Node2D = buscar_y_establecer_objetivo()
	if objetivo:
		objetivo_actual = objetivo
		tiempo_de_perdida_objetivo = 0.0
		#print("Se ha adquirido objetivo: ", objetivo.name)
	else:
		#print("Advertencia: No se encontró objetivo al iniciar el estado de persecución. Volviendo a Deambular.")
		# Si no hay objetivo, forzar la transición para no quedarse atascado.
		maquina_de_estados.cambiar_estado("EstadoDeambular")
