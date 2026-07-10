# =============================================================================
# AccionDeambular.gd  (Acción — comportamiento de fondo)
#
# Deambula alrededor de la posición de origen del agente: elige destinos
# aleatorios dentro de un radio, camina hasta ellos y espera un momento.
#
# Reemplaza a EstadoIdle + EstadoDeambular en un único nodo del árbol.
#
# RETORNA:
#   EXITOSO por tick ("di un paso de deambulación"). Nunca EN_EJECUCION:
#   así el Selector raíz re-evalúa las ramas de mayor prioridad en cada tick
#   y la deambulación puede interrumpirse en cualquier momento.
#
# MEMORIA:
#   lee  "agente", "componente_movimiento"
#   escribe "posicion_origen" (la primera vez, para deambular alrededor de ella)
# =============================================================================
class_name AccionDeambular
extends Accion

@export_group("Configuración Deambular")
## Velocidad de paseo (más lenta que la persecución).
@export var velocidad: float = 60.0
## Radio máximo alrededor del origen donde elegir destinos.
@export var radio_deambulacion: float = 200.0
## Segundos de pausa al llegar a cada destino.
@export var espera_en_destino: float = 1.5
## Distancia a la que un destino se considera alcanzado.
@export var radio_llegada: float = 10.0

var _destino: Vector2 = Vector2.ZERO
var _tiene_destino: bool = false
var _fin_espera: float = 0.0


func _on_ejecutar() -> Estado:
	var agente := _memoria.obtener("agente") as Node2D
	var movimiento: MovimientoComponente = _memoria.obtener("componente_movimiento")
	if not agente or not movimiento:
		return Estado.FALLIDO

	# Registrar el origen la primera vez (punto de anclaje del paseo).
	if not _memoria.existe("posicion_origen"):
		_memoria.establecer("posicion_origen", agente.global_position)

	# Deambular = fuera de combate: soltar la mirada de combate que
	# AccionAtacar/AccionHuir dejaron puesta (no pueden limpiarla ellos en
	# _on_salir — se dispara cada tick, ver nota en AccionAtacar). Sin esto
	# el mob pasearía mirando fijo hacia la última posición del objetivo.
	if "direccion_mirada" in agente and agente.get("direccion_mirada") != Vector2.ZERO:
		agente.set("direccion_mirada", Vector2.ZERO)

	var ahora := Time.get_ticks_msec() / 1000.0

	# Pausa entre destinos.
	if ahora < _fin_espera:
		movimiento.detener()
		return Estado.EXITOSO

	if not _tiene_destino:
		_elegir_destino()

	# ¿Llegó al destino? → programar espera y soltar el destino.
	if agente.global_position.distance_to(_destino) <= radio_llegada:
		_tiene_destino = false
		_fin_espera = ahora + espera_en_destino
		movimiento.detener()
		return Estado.EXITOSO

	# Con NavigationAgent2D asignado, rodea obstáculos; sin él, línea recta.
	movimiento.comandar_destino(_destino, velocidad)
	return Estado.EXITOSO


func _on_reiniciar() -> void:
	super._on_reiniciar()
	_tiene_destino = false
	_fin_espera = 0.0


func _elegir_destino() -> void:
	var origen: Vector2 = _memoria.obtener("posicion_origen", Vector2.ZERO)
	var angulo := randf_range(0.0, TAU)
	var distancia := randf_range(radio_deambulacion * 0.3, radio_deambulacion)
	_destino = origen + Vector2.from_angle(angulo) * distancia
	_tiene_destino = true
