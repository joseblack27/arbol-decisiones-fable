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
	# configurado en la escena: _crear_agente_navegacion() no corre para ellos,
	# así que la señal se conecta acá.
	if agente_navegacion:
		agente_navegacion.velocity_computed.connect(_on_velocity_computed)
		_ajustar_distancia_punto_ruta()


## Margen (px) por encima del radio del cuerpo con el que un punto intermedio
## de la ruta se da por pasado — ver _ajustar_distancia_punto_ruta().
const _MARGEN_PUNTO_RUTA := 6.0

## La malla de navegación llega hasta el borde de las paredes, así que en cada
## esquina de túnel la ruta pasa por el vértice MISMO de la pared. El cuerpo
## nunca se acerca a ese punto más que su propio radio: con
## path_desired_distance <= radio, el agente jamás lo daba por pasado y el mob
## se quedaba empujando contra la esquina.
func _ajustar_distancia_punto_ruta() -> void:
	if agente_navegacion == null or jugador == null:
		return
	agente_navegacion.path_desired_distance = maxf(
		agente_navegacion.path_desired_distance, _radio_cuerpo() + _MARGEN_PUNTO_RUTA)


## La malla llega hasta el filo de las paredes, así que la ruta corre PEGADA a
## ellas: en un tramo a lo largo de una pared, el centro del cuerpo tendría que
## ir por la pared misma y el mob se quedaba empujando contra ella. Se apunta a
## un punto separado de las paredes por el radio del cuerpo; la dirección
## "hacia adentro" sale de la propia malla, probando en 8 direcciones qué puntos
## alrededor siguen siendo transitables. El punto final de la ruta no se toca
## (es el destino pedido). Se calcula una vez por punto y no por fotograma: con
## decenas de mobs, 8 consultas por fotograma serían caras.
var _punto_ruta_original := Vector2.INF
var _punto_ruta_desplazado := Vector2.INF

func _punto_ruta_con_holgura(punto: Vector2) -> Vector2:
	if punto == _punto_ruta_original:
		return _punto_ruta_desplazado
	_punto_ruta_original = punto
	_punto_ruta_desplazado = punto
	var ruta := agente_navegacion.get_current_navigation_path()
	if ruta.is_empty() or punto == ruta[ruta.size() - 1]:
		return punto
	var mapa := agente_navegacion.get_navigation_map()
	var holgura := _radio_cuerpo() + 2.0
	var hacia_adentro := Vector2.ZERO
	for i in 8:
		var sentido := Vector2.RIGHT.rotated(i * TAU / 8.0)
		var sonda := punto + sentido * holgura
		if NavigationServer2D.map_get_closest_point(mapa, sonda).distance_squared_to(sonda) < 1.0:
			hacia_adentro += sentido
	if hacia_adentro.length() > 0.01:
		_punto_ruta_desplazado = punto + hacia_adentro.normalized() * holgura
	return _punto_ruta_desplazado


## Radio de la colisión del CUERPO (el CollisionShape2D hijo directo, no los de
## visión/vida, que cuelgan de sus propios componentes).
func _radio_cuerpo() -> float:
	for hijo in jugador.get_children():
		if not (hijo is CollisionShape2D) or (hijo as CollisionShape2D).shape == null:
			continue
		var forma := (hijo as CollisionShape2D).shape
		var escala: Vector2 = (jugador.scale * (hijo as Node2D).scale).abs()
		var radio: float
		if forma is CircleShape2D:
			radio = (forma as CircleShape2D).radius
		elif forma is CapsuleShape2D:
			radio = (forma as CapsuleShape2D).radius
		else:
			var medio := forma.get_rect().size / 2.0
			radio = maxf(medio.x, medio.y)
		return radio * maxf(escala.x, escala.y)
	return 0.0


func _physics_process(delta: float) -> void:
	# El empuje (ver aplicar_empuje) TOMA el control del movimiento por
	# encima de cualquier comando de IA/jugador en curso, mismo criterio de
	# prioridad que _contador_inmovilizacion — no hace falta liberar_comando()
	# antes ni después: al vencer, el comando que ya hubiera se retoma solo.
	if _empuje_restante > 0.0:
		_empuje_restante -= delta
		jugador.velocity = _empuje_velocidad
		jugador.move_and_slide()
		return
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
	_usar_mapa_del_nivel()
	_modo = ModoComando.DESTINO
	_velocidad_comandada = velocidad_override
	if agente_navegacion != null \
			and (not _destino_definido or _destino.distance_to(destino) > UMBRAL_REPLANIFICAR):
		agente_navegacion.target_position = destino
		_tiempo_en_destino_actual = 0.0  # destino de verdad nuevo, reiniciar el reloj de llego_al_destino().
	_destino = destino
	_destino_definido = true


## Comando persistente de quietud (velocity = ZERO cada frame).
func detener() -> void:
	comandar_direccion(Vector2.ZERO, 0.0)


## Segundos que llevamos intentando llegar al destino ACTUAL de
## comandar_destino() — se reinicia solo cuando el destino cambia de
## verdad (ver comandar_destino). Usado por llego_al_destino() como último
## recurso: ver ese comentario.
var _tiempo_en_destino_actual: float = 0.0
## Si tras esto seguimos sin "llegar" ni con is_navigation_finished(), se da
## por llegado igual: un destino inalcanzable por la malla puede dejar
## is_navigation_finished() en false PARA SIEMPRE, y el que lo pidió (p. ej. el
## leñador) se quedaba caminando en el lugar.
const _TIEMPO_MAXIMO_INTENTANDO_LLEGAR := 6.0


## true si ya "llegamos" al último destino de comandar_destino(): cerca de
## verdad (dentro de margen), O el agente ya da la ruta por terminada aunque
## sigamos más lejos (el punto pedido puede quedar dentro de algo sólido que la
## malla rodea, como el tronco de un árbol), O ya pasaron
## _TIEMPO_MAXIMO_INTENTANDO_LLEGAR segundos intentándolo. Pensado para
## llamadores que apuntan al centro de algo con cuerpo sólido (ver Lenador.gd).
func llego_al_destino(margen: float) -> bool:
	if not _destino_definido:
		return false
	if jugador.global_position.distance_to(_destino) <= margen:
		return true
	if agente_navegacion != null and agente_navegacion.is_navigation_finished():
		return true
	return _tiempo_en_destino_actual > _TIEMPO_MAXIMO_INTENTANDO_LLEGAR


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
	_usar_mapa_del_nivel()
	# Con avoidance_enabled=true en el agente (ver .tscn), asignar
	# agente_navegacion.velocity dispara el cálculo de evasión (RVO) contra
	# otros agentes cercanos; el resultado "seguro" llega por esta señal. Sin
	# conectarla, avoidance_enabled no tiene efecto.
	agente_navegacion.velocity_computed.connect(_on_velocity_computed)
	_ajustar_distancia_punto_ruta()


## El agente tiene que rutear SOBRE LA MALLA DE SU NIVEL, no sobre la del
## mundo: con varios niveles cargados a la vez, un mob de un nivel sin malla
## propia se enganchaba a la del OTRO nivel y se iba caminando hacia allá (ver
## NivelBase._crear_mapa_navegacion).
func _usar_mapa_del_nivel() -> void:
	if agente_navegacion == null or jugador == null or not jugador.is_inside_tree():
		return
	var mapa := GestorNiveles.mapa_navegacion_de(jugador)
	if mapa.is_valid() and agente_navegacion.get_navigation_map() != mapa:
		agente_navegacion.set_navigation_map(mapa)


func _avanzar_hacia_destino(delta: float) -> void:
	_tiempo_en_destino_actual += delta
	var posicion := jugador.global_position
	var deseada := Vector2.ZERO
	if posicion.distance_to(_destino) > MARGEN_DESTINO:
		var direccion := Vector2.ZERO
		if agente_navegacion != null and not agente_navegacion.is_navigation_finished():
			# Siguiente punto de la ruta calculada por la malla de navegación.
			direccion = posicion.direction_to(_punto_ruta_con_holgura(agente_navegacion.get_next_path_position()))
		if direccion == Vector2.ZERO:
			# Sin agente, sin malla en el nivel o ruta vacía (el agente devuelve
			# nuestra propia posición): línea recta, el comportamiento clásico.
			direccion = posicion.direction_to(_destino)
		if "direccion" in jugador:
			jugador.set("direccion", direccion)  # Para animaciones y habilidades.
		var vel := _velocidad_comandada if _velocidad_comandada > 0.0 else velocidad_base
		deseada = direccion * vel * _multiplicador_lentitud()

	# En CUALQUIER contexto headless (el servidor dedicado y las pruebas por
	# --script) el callback de evasión (velocity_computed) casi no dispara:
	# llega una vez cada varios segundos y el mob queda congelado esperando una
	# velocidad "segura". Ahí se aplica el movimiento directo: perder la evasión
	# entre mobs es mejor que mobs congelados.
	if agente_navegacion != null and DisplayServer.get_name() != "headless":
		# El movimiento real ocurre en _on_velocity_computed (avoidance).
		agente_navegacion.velocity = deseada
	else:
		physics_process(delta, deseada, deseada.length())


## Velocidad ya corregida por avoidance (o idéntica a la pedida, si
## avoidance_enabled está apagado) — mueve el cuerpo directo, sin volver a
## pasar por physics_process() para no aplicarle la normalización de
## dirección dos veces.
##
## NavigationServer2D calcula esto de forma ASÍNCRONA: la respuesta puede
## tardar uno o más fotogramas. Si mientras tanto algo tomó el control directo
## del movimiento (p. ej. HabilidadCarga durante el dash, vía liberar_comando()),
## una respuesta tardía pisaba la dirección del dash. Por eso se descarta toda
## respuesta que llegue fuera del modo DESTINO.
func _on_velocity_computed(velocidad_segura: Vector2) -> void:
	if _modo != ModoComando.DESTINO:
		return
	# Un empuje en curso ya fija la velocidad este frame (ver
	# _physics_process): una respuesta asíncrona de avoidance no debe pisarla.
	if _empuje_restante > 0.0:
		return
	if _contador_inmovilizacion > 0:
		_mover(Vector2.ZERO)
	else:
		_mover(velocidad_segura)


# --- Lógica de Movimiento ---

## Método físico principal llamado por el controlador. Ejecuta el movimiento real.
## velocidad_override: si es > 0, usa ese valor en lugar de velocidad_base.
## Útil para ataques especiales (dash, huida rápida) sin cambiar velocidad_base.
func physics_process(_delta: float, _direccion: Vector2, velocidad_override: float = 0.0) -> void:
	if _contador_inmovilizacion > 0:
		_mover(Vector2.ZERO)
		return

	# 1. Elegir velocidad: override si se especifica, base por defecto.
	var vel := velocidad_override if velocidad_override > 0.0 else velocidad_base

	# 2. Calcular el movimiento en función de la dirección recibida.
	var velocidad_aplicada: Vector2 = _direccion.normalized() * vel * _multiplicador_lentitud()

	# 3. Aplicar movimiento físico.
	_mover(velocidad_aplicada)


## move_and_slide() SOLO corre si hay velocidad que resolver: con velocidad
## cero la posición no cambia igual, y llamarlo en cada mob quieto de todo el
## mapa pesa en el servidor de un solo núcleo.
func _mover(velocidad_aplicada: Vector2) -> void:
	jugador.velocity = velocidad_aplicada
	if velocidad_aplicada != Vector2.ZERO:
		jugador.move_and_slide()


## Factores de lentitud activos (0.5 = mitad de velocidad). Lista y no un
## solo float por la misma razón que la inmovilización usa contador: dos
## efectos solapados no deben pisarse entre sí al expirar cada uno por su
## lado — cada efecto agrega SU factor al aplicarse y quita ESE MISMO
## factor al vencer (ver EfectoLentitud). Se multiplican entre sí.
var _factores_lentitud: Array[float] = []


func agregar_lentitud(factor: float) -> void:
	_factores_lentitud.append(clampf(factor, 0.05, 1.0))


func quitar_lentitud(factor: float) -> void:
	_factores_lentitud.erase(clampf(factor, 0.05, 1.0))


func _multiplicador_lentitud() -> float:
	var multiplicador := 1.0
	for factor in _factores_lentitud:
		multiplicador *= factor
	return multiplicador


func agregar_inmovilizacion() -> void:
	_contador_inmovilizacion += 1


func quitar_inmovilizacion() -> void:
	_contador_inmovilizacion = max(0, _contador_inmovilizacion - 1)


## Velocidad y tiempo restante de un empuje externo en curso (ver
## aplicar_empuje): cero salvo mientras dura un knockback (Onda de Choque).
var _empuje_velocidad: Vector2 = Vector2.ZERO
var _empuje_restante: float = 0.0


## Aplica un empuje externo por "duracion" segundos — toma el control total
## del movimiento mientras dure (ver _physics_process/_on_velocity_computed),
## por encima de cualquier comando de IA o del jugador en curso. Llamar de
## nuevo mientras uno ya está activo simplemente lo reemplaza (último empuje
## gana, no se suman).
func aplicar_empuje(direccion: Vector2, fuerza: float, duracion: float) -> void:
	if direccion == Vector2.ZERO or duracion <= 0.0:
		return
	_empuje_velocidad = direccion.normalized() * fuerza
	_empuje_restante = duracion


## Margen (px) antes de considerar que el cuerpo realmente "se salió" del
## área navegable — un punto interior normal da distancia ~0 contra su
## propia malla, así que cualquier valor bien por encima de eso es señal
## real de fuga, no ruido de la consulta.
const MARGEN_FUERA_DE_MAPA := 6.0

## Red de seguridad contra fugas del mapa: la colisión física del borde (tiles
## diagonales en las esquinas del contorno) puede tener puntos delgados que una
## embestida a alta velocidad cruza en un solo fotograma sin que
## move_and_slide() lo detecte. Se usa la malla de NAVEGACIÓN como fuente de
## verdad de "qué es adentro": si tras moverse el cuerpo quedó fuera de ella,
## se lo devuelve al punto navegable más cercano.
##
## Pública y NO llamada en cada physics_process(): el movimiento normal nunca
## es tan rápido como para tunelear, y llamarla siempre rompía cambios de
## posición legítimos (spawn, teletransporte al cambiar de nivel) contra una
## malla que recién sincroniza. Llamar SOLO desde las habilidades que mueven el
## cuerpo a velocidad de riesgo: HabilidadCarga y HabilidadCargaJugador
## (HabilidadParpadeo hace su propio chequeo equivalente).
##
## Sin malla en la escena (pruebas sueltas) no hace nada.
func contener_dentro_del_mapa() -> void:
	# El mapa de SU nivel, no el del mundo: con varios niveles a la vez, el
	# compartido devolvería el punto navegable de otro nivel y este "rescate"
	# teletransportaría al cuerpo a 100.000 px de distancia.
	var mapa: RID = GestorNiveles.mapa_navegacion_de(jugador)
	# iteration_id == 0: el mapa todavía no terminó su primera sincronización.
	# Consultarlo ya da un ERROR de NavigationServer y puede devolver (0,0),
	# que teletransportaría al recién llegado ahí. Sin regiones tampoco hay
	# contra qué comparar.
	if NavigationServer2D.map_get_iteration_id(mapa) == 0:
		return
	if NavigationServer2D.map_get_regions(mapa).is_empty():
		return
	var posicion := jugador.global_position
	var punto_navegable: Vector2 = NavigationServer2D.map_get_closest_point(mapa, posicion)
	if posicion.distance_to(punto_navegable) > MARGEN_FUERA_DE_MAPA:
		jugador.global_position = punto_navegable
