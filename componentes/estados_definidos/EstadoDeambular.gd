extends Node
class_name EstadoDeambular

# =========================================================================
# 🚶‍♂️ DEAMBULAR STATE
# Estado responsable de mover al enemigo de forma aleatoria por el mapa.
# Implementa la lógica de movimiento cíclico y basado en destino.
# =========================================================================
# --- DEPENDENCIAS EXTERNAS (Exportadas) ---
@export var componente_movimiento: MovimientoComponente # Referencia al componente de movimiento desacoplado
@export var velocidad_deambular: float = 80.0
@export var entidad: Node2D

# Variables de estado interno
var destino_actual: Vector2 = Vector2.ZERO
var tiempo_hasta_nuevo_destino: float = 0.0
const INTERVALO_CAMBIO_DESTINO: float = 3.0 # Cambia de destino cada 3 segundos

func _ready():
	pass

# Método llamado por MáquinaDeEstadosComponente al entrar en este estado.
func iniciar_estado():
	#print("Estado deambular iniciado: Estableciendo nuevo destino.")
	establecer_nuevo_destino()

# Sobrescribe el método de procesamiento de estado de la MáquinaDeEstadosComponente.
func procesar_estado(delta: float):
	# 1. Gestión del cambio de destino.
	tiempo_hasta_nuevo_destino -= delta
	if tiempo_hasta_nuevo_destino <= 0 or abs(entidad.global_position.distance_to(destino_actual)) < 10:
		establecer_nuevo_destino()
		tiempo_hasta_nuevo_destino = INTERVALO_CAMBIO_DESTINO

	# 2. Calcular el vector de movimiento hacia el destino.
	var vector_destino: Vector2 = destino_actual - entidad.global_position
	# La magnitud del movimiento se escala por la velocidad.
	var movimiento_calculado: Vector2 = vector_destino.normalized() * velocidad_deambular

	# 3. Devolver el movimiento para que sea aplicado por el ComponenteMovimiento.
	# El componente de movimiento se encarga de la física y de la velocidad_aplicada.
	#return movimiento_calculado
	entidad.direccion = vector_destino.normalized()
	componente_movimiento.physics_process(delta, movimiento_calculado)

# --- Lógica de Movimiento Aleatorio ---

func establecer_nuevo_destino():
	# Esto debería idealmente calcular límites del mapa (por ejemplo, usando los límites del nodo Mundo).
	# Por ahora, asumimos que el mapa es de 0 a 1024 en ambas dimensiones.
	var pantalla = get_viewport().get_visible_rect().size
	var rango_x: float = pantalla.x
	var rango_y: float = pantalla.y
	
	var nuevo_destino: Vector2 = Vector2(
		randf_range(0, rango_x), 
		randf_range(0, rango_y)
	)
	destino_actual = nuevo_destino
	#print(destino_actual)
	# Opcional: Puedes añadir un sonido o un efecto visual aquí.
