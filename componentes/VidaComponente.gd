## VidaComponente.gd
## Componente responsable de gestionar la salud del agente.
## Debe ser adjuntado al nodo raíz del personaje o a un nodo hijo para recibir señales.
## Las dependencias externas (Pizarra, ArbolComportamiento) deben ser referenciadas manualmente en _ready().

extends Area2D
class_name VidaComponente

signal cambio_valor_vida(valor: float)

# Señal emitida cuando la vida del agente llega o cae por debajo de cero.
signal muerte(valor: float)

# Dependencias externas (Pizarra y ArbolComportamiento) deben ser enlazadas en _ready().
#var pizarra: Pizarra 
#@export var arbol_comportamiento: ArbolComportamiento 

@export var salud_maxima: float = 100.0
@export var salud_actual: float

# --- Inicialización y Estado ---

func _ready():
	# Se asume que las referencias Pizarra y ArbolComportamiento ya han sido inyectadas por el controlador principal.
	# Si no están enlazadas, las variables se mantendrán con sus valores por defecto (100.0).
	#if arbol_comportamiento:
		#pizarra = arbol_comportamiento.obtener_pizarra()
		#
		## Sincronizar valores iniciales en la Pizarra
		#pizarra.establecer("vida_actual", salud_maxima)
		#pizarra.establecer("vida_maxima", salud_maxima)
	salud_actual = salud_maxima

## Consulta la vida actual del agente.
func obtener_vida() -> float:
	return salud_actual

## Devuelve la vida máxima del agente.
func obtener_vida_maxima() -> float:
	return salud_maxima

## Agrega vida al agente. Retorna el exceso de vida (si se sobrepasa el máximo).
func agregar_vida(cantidad: float) -> float:
	if cantidad <= 0:
		return 0.0
	
	var vida_anterior = salud_actual
	salud_actual = min(salud_actual + cantidad, salud_maxima)
	
	# Actualizar Pizarra usando las referencias inyectadas.
	#pizarra.establecer("vida_actual", salud_actual)
	
	cambio_valor_vida.emit(salud_actual)
	
	# Retorna la vida que se perdió al alcanzar el máximo
	return max(0.0, (vida_anterior + cantidad) - salud_maxima)

## Quita vida al agente. Retorna la vida restante (si es > 0).
func quitar_vida(cantidad: float) -> float:
	if cantidad <= 0:
		return salud_actual
	
	salud_actual -= cantidad
	
	# Actualizar Pizarra
	#pizarra.establecer("vida_actual", salud_actual)
	
	cambio_valor_vida.emit(salud_actual)
	# El número flotante de daño NO se muestra desde aquí: este componente
	# solo gestiona salud. Quien inflige el daño ya emite
	# BusEventos.daño_aplicado (ver Proyectil.gd, Arañazo.gd, etc.), y
	# GestorNumerosDano (autoload de presentación pura) es quien escucha esa
	# señal y dibuja el número — así "cuánta vida queda" y "cómo se ve" están
	# completamente separados.

	# Emitir señal si la vida es menor o igual a cero
	if salud_actual <= 0.0:
		muerte.emit(0.0)
		salud_actual = 0.0

	return max(0.0, salud_actual)
