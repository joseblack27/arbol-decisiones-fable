extends Node
class_name EstadoIdle

# =========================================================================
# 🛋️ IDLE STATE
# Estado responsable de la inactividad. Espera un período aleatorio
# antes de activar el movimiento de deambulación.
# Implementa un temporizador y realiza la transición al estado deambular.
# ============================================================================

# --- DEPENDENCIAS EXTERNAS (Exportadas) ---
@export var maquina_de_estados: MaquinaDeEstadosComponente # Referencia a la máquina de estados principal
@export var entidad: Node2D # La entidad que está en estado (el enemigo)
@export var memoria: MemoriaBT

# Variables de estado interno
var tiempo_inicial: float = 0.0
var tiempo_deseado_minimo: float = 5.0
var tiempo_deseado_maximo: float = 10.0
var tiempo_restante: float = 0.0

func _ready():
	pass

# Método llamado por MáquinaDeEstadosComponente al entrar en este estado.
func iniciar_estado():
	# Inicializa el temporizador con un valor aleatorio entre 5 y 10 segundos.
	tiempo_restante = randf_range(tiempo_deseado_minimo, tiempo_deseado_maximo)
	memoria.establecer("cooldown_estado", true)
	if entidad is CharacterBody2D:
		entidad.velocity = Vector2.ZERO

# Sobrescribe el método de procesamiento de estado de la MáquinaDeEstadosComponente.
func procesar_estado(delta: float):
	# 1. Decrementar el contador.
	tiempo_restante -= delta
	
	# 2. Chequear la condición de transición.
	if tiempo_restante <= 0:
		memoria.establecer("cooldown_estado", false)
		# 3. Transicionar al siguiente estado.
		# Se llama a la función de cambio de estado en el controlador.
		if maquina_de_estados:
			maquina_de_estados.cambiar_estado("EstadoDeambular")
		else:
			print("ERROR: No se pudo realizar la transición de EstadoIdle. Faltan referencias.")

	# Opcional: Emitir señal visual o sonora si el tiempo es crítico.
