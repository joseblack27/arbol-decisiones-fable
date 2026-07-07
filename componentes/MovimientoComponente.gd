## MovimientoComponente.gd
## Componente responsable de manejar y aplicar la lógica de movimiento del personaje.
## Debe ser un componente desacoplado. Su única función es tomar el movimiento calculado 
## (ya sea por el BT o manualmente) y aplicarlo al nodo propietario (el jugador).

extends Node
class_name MovimientoComponente

# --- Dependencias inyectadas ---
# Referencia al CharacterBody2D dueño del componente.
@export var jugador: CharacterBody2D 

# --- Variables de estado ---

# Exportable en el editor: Permite al usuario configurar la velocidad base de movimiento.
@export var velocidad_base: float = 300.0

## Agente para comandar_destino() con pathfinding. NORMALMENTE VACÍO: el
## componente crea el suyo automáticamente (colgado del cuerpo) la primera
## vez que se le pide un destino. Asignar uno aquí solo si quieres tunear
## un NavigationAgent2D a mano en la escena.
@export var agente_navegacion: NavigationAgent2D

@export_group("Navegación")
## Distancia (px) a la que un punto intermedio de la ruta se da por pasado.
@export var distancia_punto_ruta := 8.0
## Distancia (px) a la que el destino final se da por alcanzado.
@export var distancia_destino_agente := 16.0

## Máscara de navegación de la capa "Navegacion" de los niveles (ver
## generar_capa_navegacion.gd y tileset_colisiones.tres). Los agentes solo
## calculan rutas sobre ESA malla; ignoran la de Terreno (que no se usa
## para pathfinding, solo para el aspecto visual y su propia colisión física).
const MASCARA_NAVEGACION := 2

## Contador de efectos de inmovilización activos. Mientras sea > 0 el movimiento se bloquea.
var _contador_inmovilizacion: int = 0

# --- Modo comandado (para IA por ticks) ---
# El BT decide cada ~0.1s, pero la física corre cada frame. En vez de que cada
# acción llame a physics_process() manualmente, la acción deja un "comando"
# persistente y este componente lo aplica solo en cada frame físico.
enum ModoComando { LIBRE, DIRECCION, DESTINO }

## Distancia (px) a la que un destino se considera alcanzado.
const MARGEN_DESTINO := 6.0
## Cambio mínimo del destino (px) antes de volver a pedir ruta al agente.
const UMBRAL_REPLANIFICAR := 8.0

var _modo: ModoComando = ModoComando.LIBRE
var _direccion_comandada: Vector2 = Vector2.ZERO
var _velocidad_comandada: float = 0.0
var _destino: Vector2 = Vector2.ZERO
var _destino_definido: bool = false


func _ready() -> void:
	# Algunos enemigos (p. ej. Lobo) traen su propio NavigationAgent2D
	# preconfigurado desde el Inspector (con avoidance_enabled=true ya
	# puesto) en vez de dejar que _crear_agente_navegacion() cree uno por
	# defecto — en ese caso hay que conectar la señal acá, porque
	# _crear_agente_navegacion() nunca se llega a ejecutar.
	if agente_navegacion:
		agente_navegacion.velocity_computed.connect(_on_velocity_computed)


func _physics_process(delta: float) -> void:
	match _modo:
		ModoComando.DIRECCION:
			physics_process(delta, _direccion_comandada, _velocidad_comandada)
		ModoComando.DESTINO:
			_avanzar_hacia_destino(delta)


## Deja un comando de movimiento persistente (se aplica cada frame físico
## hasta recibir otro comando, detener() o liberar_comando()).
func comandar_direccion(direccion: Vector2, velocidad_override: float = 0.0) -> void:
	_modo = ModoComando.DIRECCION
	_direccion_comandada = direccion
	_velocidad_comandada = velocidad_override


## Comando persistente hacia una posición global, con pathfinding (rodea
## agua, muros y bases sólidas). El agente de navegación se crea solo la
## primera vez; sin malla en el nivel, degrada a línea recta.
func comandar_destino(destino: Vector2, velocidad_override: float = 0.0) -> void:
	if agente_navegacion == null:
		_crear_agente_navegacion()
	elif agente_navegacion.navigation_layers != MASCARA_NAVEGACION:
		# Agente puesto a mano en la escena (p. ej. para depurar con
		# debug_enabled): igual se sincroniza a la capa Navegacion dedicada.
		agente_navegacion.navigation_layers = MASCARA_NAVEGACION
	_modo = ModoComando.DESTINO
	_velocidad_comandada = velocidad_override
	if agente_navegacion != null \
			and (not _destino_definido or _destino.distance_to(destino) > UMBRAL_REPLANIFICAR):
		agente_navegacion.target_position = destino
	_destino = destino
	_destino_definido = true


## Comando persistente de quietud (velocity = ZERO cada frame).
func detener() -> void:
	comandar_direccion(Vector2.ZERO, 0.0)


## Suelta el control del movimiento SIN frenar. Necesario cuando otro sistema
## (p. ej. HabilidadCarga durante el dash) conduce el cuerpo directamente.
func liberar_comando() -> void:
	_modo = ModoComando.LIBRE
	_destino_definido = false


## El agente debe colgar de un Node2D (usa la posición de su padre), por eso
## se añade al cuerpo y no a este componente (que es un Node sin posición).
func _crear_agente_navegacion() -> void:
	agente_navegacion = NavigationAgent2D.new()
	agente_navegacion.name = "AgenteNavegacion"
	agente_navegacion.path_desired_distance = distancia_punto_ruta
	agente_navegacion.target_desired_distance = distancia_destino_agente
	agente_navegacion.navigation_layers = MASCARA_NAVEGACION
	jugador.add_child(agente_navegacion)
	# Con avoidance_enabled=true en el agente (ver .tscn), asignar
	# agente_navegacion.velocity dispara el cálculo de evasión (RVO) contra
	# otros agentes/NavigationObstacle2D cercanos; el resultado "seguro" llega
	# por esta señal — sin conectarla, avoidance_enabled no tiene ningún
	# efecto real (antes solo estaba el flag puesto, nunca usado).
	agente_navegacion.velocity_computed.connect(_on_velocity_computed)


func _avanzar_hacia_destino(delta: float) -> void:
	var posicion := jugador.global_position
	var deseada := Vector2.ZERO
	if posicion.distance_to(_destino) > MARGEN_DESTINO:
		var direccion := Vector2.ZERO
		if agente_navegacion != null and not agente_navegacion.is_navigation_finished():
			# Siguiente punto de la ruta calculada por la malla de navegación.
			direccion = posicion.direction_to(agente_navegacion.get_next_path_position())
		if direccion == Vector2.ZERO:
			# Sin agente, sin malla en el nivel o ruta vacía (el agente devuelve
			# nuestra propia posición): línea recta, el comportamiento clásico.
			direccion = posicion.direction_to(_destino)
		if "direccion" in jugador:
			jugador.set("direccion", direccion)  # Para animaciones y habilidades.
		var vel := _velocidad_comandada if _velocidad_comandada > 0.0 else velocidad_base
		deseada = direccion * vel

	if agente_navegacion != null:
		# El movimiento real ocurre en _on_velocity_computed (avoidance).
		agente_navegacion.velocity = deseada
	else:
		physics_process(delta, deseada, deseada.length())


## Velocidad ya corregida por avoidance (o idéntica a la pedida, si
## avoidance_enabled está apagado) — mueve el cuerpo directo, sin volver a
## pasar por physics_process() para no aplicarle la normalización de
## dirección dos veces.
func _on_velocity_computed(velocidad_segura: Vector2) -> void:
	if _contador_inmovilizacion > 0:
		jugador.velocity = Vector2.ZERO
	else:
		jugador.velocity = velocidad_segura
	jugador.move_and_slide()


# --- Lógica de Movimiento ---

## Método físico principal llamado por el controlador. Ejecuta el movimiento real.
## velocidad_override: si es > 0, usa ese valor en lugar de velocidad_base.
## Útil para ataques especiales (dash, huida rápida) sin cambiar velocidad_base.
func physics_process(_delta: float, _direccion: Vector2, velocidad_override: float = 0.0) -> void:
	if _contador_inmovilizacion > 0:
		jugador.velocity = Vector2.ZERO
		jugador.move_and_slide()
		return

	# 1. Elegir velocidad: override si se especifica, base por defecto.
	var vel := velocidad_override if velocidad_override > 0.0 else velocidad_base

	# 2. Calcular el movimiento en función de la dirección recibida.
	var velocidad_aplicada: Vector2 = _direccion.normalized() * vel

	# 3. Aplicar movimiento físico.
	jugador.velocity = velocidad_aplicada
	jugador.move_and_slide()


func agregar_inmovilizacion() -> void:
	_contador_inmovilizacion += 1


func quitar_inmovilizacion() -> void:
	_contador_inmovilizacion = max(0, _contador_inmovilizacion - 1)
