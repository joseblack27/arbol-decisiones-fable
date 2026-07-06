extends Node
class_name MaquinaDeEstadosComponente

# =========================================================================
# 🧠 MÁQUINA DE ESTADOS COMPONENTE
# Función de encapsulamiento del patrón Máquina de Estados.
# Es un componente reutilizable y desacoplado.
# =========================================================================
# --- DEPENDENCIAS EXTERNAS (Exportadas) ---
@export var estado_activo: Node # La referencia al estado que se está ejecutando (ej: EstadoDeambular)
@export var etiqueta_estado: Label

var estado_actual: String = "Inactivo"

signal cambio_de_estado(nuevo_estado: String)

func _ready():
	if estado_activo:
		etiqueta_estado.text = estado_activo.name
		cambiar_estado(estado_activo.name)

# NOTA: esta máquina NO se procesa sola. Quien la posee (Enemigo.gd) llama a
# procesar_estado(delta) desde su _physics_process. Antes existía aquí un
# _physics_process propio que provocaba que el estado activo se procesara DOS
# veces por frame (doble velocidad de movimiento y timers al doble).

# Esta función debe ser llamada por BehaviorController o el nodo principal en _physics_process.
func procesar_estado(delta: float):
	if estado_activo:
		# Delegar el procesamiento al estado activo.
		estado_activo.procesar_estado(delta)
	else:
		print("ADVERTENCIA: No hay estado activo asignado en la MáquinaDeEstadosComponente.")


# --- Gestión de Estado (Lógica de Transición) ---

# Función pública para cambiar de estado, llamada por el BehaviorController.
# Nota: Este método ahora debe manejar la asignación de nodos de estado.
func cambiar_estado(nuevo_estado: String):
	if estado_actual != nuevo_estado:
		#print("🤖 Transición de estado en la IA: De ", estado_actual, " a: ", nuevo_estado)
		estado_actual = nuevo_estado
		cambio_de_estado.emit(nuevo_estado)
		
		# Buscar el nodo del nuevo estado. Se espera que el nombre del estado
		# coincida con el nombre del nodo hijo en la escena.
		var nuevo_estado_node = get_node_or_null(nuevo_estado)
		
		if nuevo_estado_node:
			estado_activo = nuevo_estado_node
			# Llamar a una función inicial de estado si existe (e.g., iniciar movimiento)
			if estado_activo.has_method("iniciar_estado"):
				estado_activo.iniciar_estado()
			# También se puede requerir la llamada a set_state() si los estados usan ese método:
			# if estado_activo.has_method("set_state"):
			# 	estado_activo.set_state()
		else:
			estado_activo = null
			print("ERROR: No se encontró el nodo de estado o el estado: ", nuevo_estado)
		
		etiqueta_estado.text = estado_activo.name
