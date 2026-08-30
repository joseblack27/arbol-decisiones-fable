extends Node
## Cerebro simple para un Jugador manejado por IA en vez de input real —
## pedido del usuario: probar el servidor con varias instancias de Godot
## peleando solas, viendo bots recorrer el mapa y engancharse con mobs.
## Prototipo simple a propósito, sin cola de metas todavía ("ir a mapa tal,
## buscar tal mob, volver a ciudad" queda para más adelante si anda bien):
## deambula por un radio alrededor de donde apareció; si detecta un enemigo
## cerca, lo persigue manteniendo distancia_combate (ver _procesar_
## perseguir) y ataca con alguna de sus habilidades EQUIPADAS al azar (ver
## _usar_alguna_habilidad) hasta matarlo o perderlo de vista; al terminar ese
## combate, sortea si sigue deambulando en este mapa o se va a otro cruzando
## el portal más cercano (ver probabilidad_cambiar_mapa/_abandonar_objetivo)
## — evita que se quede dando vueltas sin fin cuando no hay más mobs cerca.
## Se agrega como hijo del propio Jugador SOLO cuando Utils.modo_bot está
## prendido (ver Jugador._ready()) — nunca sobre la réplica de OTRO jugador.
##
## Detección por QUERY DE FÍSICA directa (no VisionComponente): ese
## componente exige que el área detectada sea un VidaComponente "monitorable"
## (ver VisionComponente._es_objetivo_valido), y el de los MOBS viene con
## monitorable=false de fábrica en su .tscn (ver EnemigoLobo.tscn) — tiene
## sentido para su uso real (los MOBS detectan al JUGADOR, nunca al revés),
## pero deja a VisionComponente inservible para el caso inverso que necesita
## este bot. En cambio, el CUERPO del mob (el CharacterBody2D) sí vive
## siempre en collision_layer=Enemigo.CAPA_MOB (ver Enemigo._ready()) — una
## consulta de forma contra esa capa detecta cualquier mob real sin tocar
## nada del lado de los mobs.
##
## El movimiento va SIEMPRE por _joystick_movimiento() (nunca por
## MovimientoComponente.comandar_destino() directo): en red, el destino real
## lo decide el SERVIDOR vía RPC (ver ese método en Jugador.gd) —
## comandar_destino() solo movería la copia LOCAL, que el servidor
## terminaría pisando igual (mismo motivo por el que las habilidades van
## por _activar_slot(), no por activar() directo sobre la habilidad).
##
## Sin tipar "_jugador" como Jugador a propósito: Jugador.gd no declara
## class_name, así que el tipo estático más específico disponible sería
## CharacterBody2D, que NO conoce _joystick_movimiento/_activar_slot —
## Variant (sin tipo) deja que se resuelvan por duck typing en tiempo real,
## igual que el resto del proyecto hace con este mismo nodo.

enum _Estado { DEAMBULAR, PERSEGUIR, VIAJAR }

@export var radio_deambulacion: float = 350.0
@export var radio_deteccion: float = 250.0
## Si el objetivo actual se aleja más que esto, se abandona en vez de
## perseguirlo sin fin (mismo criterio que AccionPerseguir.distancia_abandono).
@export var radio_abandono: float = 500.0
## Distancia que el bot intenta mantener con el objetivo mientras pelea —
## pedido del usuario: "que no se ubicaran justo encima del mob, sino que
## se mantengan como a 40px". Con tolerancia_distancia_combate de margen a
## cada lado: sin ese margen, cualquier variación mínima (lag de red, el
## propio mob empujándolo o persiguiéndolo de vuelta) dispararía
## corrección constante de ida y vuelta en vez de quedarse quieto peleando.
@export var distancia_combate: float = 40.0
@export var tolerancia_distancia_combate: float = 10.0
@export var intervalo_ataque: float = 1.1
@export var intervalo_recalculo_deambular: float = 2.5
@export var intervalo_escaneo: float = 0.4
## Filtra qué tipos de mob perseguir — vacío (default) = cualquiera, mismo
## comportamiento de siempre. Con algo cargado, solo esos tipos activan la
## persecución (el resto se ignora aunque esté más cerca); se compara
## contra EnemigoDatos.obtener_id() de cada mob (el "id" si lo tiene
## configurado, si no nombre_tipo tal cual — ver recursos/enemigos/*.tres,
## p. ej. "Lobo", "Araña", "Araña Reina", "El Guardián Quebrado"). Pedido
## del usuario: "si quiero que busque mobs específicos".
@export var tipos_objetivo: Array[String] = []
## Probabilidad (0-1) de decidir irse a otro mapa en vez de seguir buscando
## mobs, evaluada UNA sola vez justo al terminar un combate (mob muerto o
## abandonado por alejarse demasiado — ver _abandonar_objetivo). Pedido del
## usuario: antes el bot, al no encontrar nada cerca, se quedaba deambulando
## sin límite dentro del mismo mapa en vez de probar suerte en otro; tirar el
## dado en cualquier otro momento (p. ej. en cada ciclo de deambular)
## produciría cambios de mapa mientras aún podría haber un mob a la vista.
@export_range(0.0, 1.0) var probabilidad_cambiar_mapa: float = 0.35
## Segundos sin avance mínimo mientras deambula o viaja a un portal antes de
## darse por atascado (p. ej. pegado contra una pared cerca de un portal) —
## pedido del usuario: "si no cambian de posición en 3 segundos mientras
## caminan, significan que están atascados". Al disparar, se sortea un punto
## nuevo VALIDADO contra la malla de navegación (ver _punto_navegable_
## aleatorio), anclado a la posición ACTUAL en vez del origen de siempre: si
## el problema es justo esa zona del mapa, seguir sorteando alrededor del
## mismo origen podía volver a mandarlo justo ahí.
@export var umbral_atascado_segundos: float = 3.0
## Avance mínimo (px) en ese lapso para NO considerarse atascado.
@export var distancia_minima_progreso_atascado: float = 15.0

## Cuántos puntos al azar se prueban antes de resignarse en
## _punto_navegable_aleatorio (mismo criterio que
## SpawnerMobs._punto_de_generacion_valido).
const _INTENTOS_MAXIMOS_PUNTO_NAVEGABLE := 8
## Distancia (px) máxima entre un candidato y el punto transitable más
## cercano de la malla para considerarlo "sobre" ella.
const _TOLERANCIA_NAVEGACION := 10.0

var _jugador
var _estado: _Estado = _Estado.DEAMBULAR
var _objetivo: Node2D = null
var _origen := Vector2.ZERO
var _destino_deambular := Vector2.ZERO
var _portal_destino: Node2D = null
var _proximo_ataque := 0.0
var _proximo_recalculo := 0.0
var _proximo_escaneo := 0.0
## Agente PROPIO (no el de MovimientoComponente): el movimiento real sigue
## yendo siempre por _joystick_movimiento (ver nota grande arriba), este
## agente solo PLANIFICA una ruta sobre la malla del nivel para saber hacia
## qué dirección apuntar el joystick en cada paso — mismo mecanismo que usan
## los mobs (ver MovimientoComponente.comandar_destino), aplicado acá sin
## tocar el camino de movimiento real de un jugador.
var _agente_navegacion: NavigationAgent2D
var _posicion_control_atascado := Vector2.ZERO
var _tiempo_atascado := 0.0


func _ready() -> void:
	_jugador = get_parent()
	if _jugador == null:
		return
	_origen = _jugador.global_position
	_posicion_control_atascado = _origen
	_crear_agente_navegacion()
	_elegir_destino_deambular()
	GestorNiveles.nivel_cargado.connect(_al_cambiar_de_nivel)


## Ver el comentario de _agente_navegacion (la var) para por qué existe uno
## PROPIO en vez de reusar el de MovimientoComponente.
func _crear_agente_navegacion() -> void:
	_agente_navegacion = NavigationAgent2D.new()
	_agente_navegacion.name = "AgenteNavegacionBot"
	_agente_navegacion.navigation_layers = MovimientoComponente.MASCARA_NAVEGACION
	_agente_navegacion.path_desired_distance = 8.0
	_agente_navegacion.target_desired_distance = 8.0
	_agente_navegacion.avoidance_enabled = false
	_jugador.add_child(_agente_navegacion)
	_actualizar_mapa_navegacion()


## El agente tiene que rutear sobre la malla de SU nivel — mismo motivo que
## MovimientoComponente._usar_mapa_del_nivel (con varios niveles cargados a
## la vez en el servidor, cada uno tiene la suya).
func _actualizar_mapa_navegacion() -> void:
	if _agente_navegacion == null or not _jugador.is_inside_tree():
		return
	var mapa := GestorNiveles.mapa_navegacion_de(_jugador)
	if mapa.is_valid() and _agente_navegacion.get_navigation_map() != mapa:
		_agente_navegacion.set_navigation_map(mapa)


## Recién terminó de cargar un nivel en ESTE cliente (cruzó un portal, ver
## _procesar_viajar) — reancla el radio de deambulación a la nueva posición
## en vez de seguir usando coordenadas del mapa anterior, y suelta cualquier
## objetivo/portal que ya no tenga sentido acá.
func _al_cambiar_de_nivel(_nivel) -> void:
	if not is_instance_valid(_jugador):
		return
	_objetivo = null
	_portal_destino = null
	_estado = _Estado.DEAMBULAR
	# Deferred: el cambio de nivel puede llegar un frame antes de que la
	# posición replicada del propio jugador se actualice al punto de llegada.
	call_deferred("_reanclar_origen")


func _reanclar_origen() -> void:
	if not is_instance_valid(_jugador):
		return
	_origen = _jugador.global_position
	_posicion_control_atascado = _origen
	_tiempo_atascado = 0.0
	_elegir_destino_deambular()


func _process(delta: float) -> void:
	if not is_instance_valid(_jugador):
		return
	if "_muerto" in _jugador and _jugador._muerto:
		return

	var ahora := Time.get_ticks_msec() / 1000.0
	if ahora >= _proximo_escaneo:
		_proximo_escaneo = ahora + intervalo_escaneo
		_escanear_enemigos()

	_actualizar_deteccion_atascado(delta)

	match _estado:
		_Estado.DEAMBULAR:
			_procesar_deambular()
		_Estado.PERSEGUIR:
			_procesar_perseguir()
		_Estado.VIAJAR:
			_procesar_viajar()


## Busca el mob real más cercano dentro de radio_deteccion — solo si no hay
## uno en curso, para no cambiar de blanco a mitad de la persecución.
func _escanear_enemigos() -> void:
	# Ya decidido irse a otro mapa (ver _abandonar_objetivo): no distraerse
	# con un mob nuevo a mitad de camino, o nunca llegaría al portal.
	if _estado == _Estado.VIAJAR:
		return
	if _estado == _Estado.PERSEGUIR and is_instance_valid(_objetivo):
		return

	var espacio = _jugador.get_world_2d().direct_space_state
	var forma := CircleShape2D.new()
	forma.radius = radio_deteccion
	var consulta := PhysicsShapeQueryParameters2D.new()
	consulta.shape = forma
	consulta.transform = Transform2D(0.0, _jugador.global_position as Vector2)
	consulta.collision_mask = Enemigo.CAPA_MOB
	consulta.collide_with_bodies = true
	consulta.collide_with_areas = false

	var mas_cerca: Node2D = null
	var distancia_mas_cerca := INF
	for resultado in espacio.intersect_shape(consulta, 8):
		var candidato = resultado.get("collider")
		if not (candidato is Node2D) or not candidato.is_in_group("enemigos"):
			continue
		if not candidato.has_method("quitar_vida"):
			continue
		if not _coincide_tipo_objetivo(candidato):
			continue
		var d: float = _jugador.global_position.distance_to(candidato.global_position)
		if d < distancia_mas_cerca:
			distancia_mas_cerca = d
			mas_cerca = candidato

	if mas_cerca:
		_objetivo = mas_cerca
		_estado = _Estado.PERSEGUIR


## true si tipos_objetivo está vacío (sin filtro, cualquiera sirve) o si el
## "datos" (EnemigoDatos) del candidato coincide con alguno de los tipos
## pedidos. Sin "datos" asignado (raro, pero posible en un mob armado a
## mano) se descarta en vez de arriesgar un falso positivo.
func _coincide_tipo_objetivo(candidato: Node) -> bool:
	if tipos_objetivo.is_empty():
		return true
	if not ("datos" in candidato) or candidato.datos == null:
		return false
	return tipos_objetivo.has(candidato.datos.obtener_id())


func _abandonar_objetivo() -> void:
	_objetivo = null
	var portal := _portal_mas_cercano()
	if portal != null and randf() < probabilidad_cambiar_mapa:
		_portal_destino = portal
		_estado = _Estado.VIAJAR
		return
	_estado = _Estado.DEAMBULAR
	_elegir_destino_deambular()


## El portal de cambio de nivel más cercano dentro del mapa actual (grupo
## "portales_nivel", ver PortalNivel.gd) — null si este nivel no tiene
## ninguno cargado. El propio cruce lo detecta el portal al ver al jugador
## encima (igual que un jugador real, ver PortalNivel._viajar): a este bot
## le alcanza con caminar hasta ahí por _joystick_movimiento.
func _portal_mas_cercano() -> Node2D:
	var mas_cerca: Node2D = null
	var distancia_mas_cerca := INF
	for candidato in get_tree().get_nodes_in_group(&"portales_nivel"):
		if not (candidato is Node2D):
			continue
		var d: float = _jugador.global_position.distance_to(candidato.global_position)
		if d < distancia_mas_cerca:
			distancia_mas_cerca = d
			mas_cerca = candidato
	return mas_cerca


func _procesar_viajar() -> void:
	if not is_instance_valid(_portal_destino):
		_estado = _Estado.DEAMBULAR
		_elegir_destino_deambular()
		return
	_mover_hacia(_portal_destino.global_position)


func _procesar_deambular() -> void:
	var ahora := Time.get_ticks_msec() / 1000.0
	if ahora >= _proximo_recalculo or _jugador.global_position.distance_to(_destino_deambular) < 24.0:
		_elegir_destino_deambular()
	_mover_hacia(_destino_deambular)


func _elegir_destino_deambular() -> void:
	_proximo_recalculo = Time.get_ticks_msec() / 1000.0 + intervalo_recalculo_deambular
	_destino_deambular = _punto_navegable_aleatorio(_origen, radio_deambulacion)


## Punto al azar dentro de "radio" alrededor de "centro", VALIDADO contra la
## malla de navegación del nivel actual (mismo criterio que
## SpawnerMobs._punto_de_generacion_valido: prueba varios candidatos y se
## queda con el punto transitable más cercano de uno que sí caiga sobre la
## malla) — pedido del usuario: antes se elegía cualquier punto del círculo a
## ciegas, y el bot terminaba caminando hacia terreno no transitable o hacia
## el otro lado de una pared, quedando pegado contra ella sin poder llegar
## nunca. Sin malla en el nivel (pruebas sueltas sin nivel real) cae al
## comportamiento simple de siempre.
func _punto_navegable_aleatorio(centro: Vector2, radio: float) -> Vector2:
	var mapa := GestorNiveles.mapa_navegacion_de(_jugador)
	if NavigationServer2D.map_get_regions(mapa).is_empty():
		var angulo_simple := randf() * TAU
		var distancia_simple := randf_range(radio * 0.3, radio)
		return centro + Vector2.from_angle(angulo_simple) * distancia_simple
	for _i in _INTENTOS_MAXIMOS_PUNTO_NAVEGABLE:
		var angulo := randf() * TAU
		var distancia := randf_range(radio * 0.3, radio)
		var candidato: Vector2 = centro + Vector2.from_angle(angulo) * distancia
		var punto_malla: Vector2 = NavigationServer2D.map_get_closest_point(mapa, candidato)
		if candidato.distance_to(punto_malla) <= _TOLERANCIA_NAVEGACION:
			return punto_malla
	# Nada válido en el radio: el punto transitable más cercano al propio
	# centro (se asume transitable, es donde el bot ya estuvo parado antes).
	return NavigationServer2D.map_get_closest_point(mapa, centro)


## Ver umbral_atascado_segundos: solo corre mientras el bot está tratando de
## LLEGAR a algún lado caminando (deambulando o viajando a un portal) — la
## persecución/combate no cuenta como "atascado" (mantener distancia con un
## mob a propósito no debe disparar esto).
func _actualizar_deteccion_atascado(delta: float) -> void:
	if _estado != _Estado.DEAMBULAR and _estado != _Estado.VIAJAR:
		_tiempo_atascado = 0.0
		_posicion_control_atascado = _jugador.global_position
		return
	if _jugador.global_position.distance_to(_posicion_control_atascado) >= distancia_minima_progreso_atascado:
		_posicion_control_atascado = _jugador.global_position
		_tiempo_atascado = 0.0
		return
	_tiempo_atascado += delta
	if _tiempo_atascado >= umbral_atascado_segundos:
		_tiempo_atascado = 0.0
		_posicion_control_atascado = _jugador.global_position
		_resolver_atascamiento()


## "Hagan un mapeo del mapa y se dirijan a un punto bueno del mismo" (pedido
## del usuario): suelta lo que estuviera haciendo (viaje a portal u objetivo)
## y vuelve a deambular hacia un punto recién VALIDADO contra la malla de
## navegación (ver _punto_navegable_aleatorio), esta vez anclado a la
## posición ACTUAL en vez del origen de siempre — si el atasco es por esa
## zona puntual del mapa (p. ej. la esquina de un portal), seguir sorteando
## alrededor del mismo origen de siempre podía volver a mandarlo justo ahí.
func _resolver_atascamiento() -> void:
	_portal_destino = null
	_objetivo = null
	_estado = _Estado.DEAMBULAR
	_destino_deambular = _punto_navegable_aleatorio(_jugador.global_position, radio_deambulacion)
	_proximo_recalculo = Time.get_ticks_msec() / 1000.0 + intervalo_recalculo_deambular


func _procesar_perseguir() -> void:
	if not is_instance_valid(_objetivo):
		_abandonar_objetivo()
		return
	var distancia: float = _jugador.global_position.distance_to(_objetivo.global_position)
	if distancia > radio_abandono:
		_abandonar_objetivo()
		return
	if distancia > distancia_combate + tolerancia_distancia_combate:
		_mover_hacia(_objetivo.global_position)
		return
	if distancia < distancia_combate - tolerancia_distancia_combate:
		_mover_alejandose_de(_objetivo.global_position)
		return
	_jugador._joystick_movimiento(Vector2.ZERO)
	var ahora := Time.get_ticks_msec() / 1000.0
	if ahora >= _proximo_ataque:
		_proximo_ataque = ahora + intervalo_ataque
		_usar_alguna_habilidad()


## Junta los slots equipados que no estén en cooldown y elige uno al azar —
## pedido del usuario: "que los bots pudieran usar más habilidades" en vez
## de spamear siempre golpe_basico (slot 0). Las que requieren dirección
## (proyectiles, golpes apuntados) se lanzan hacia el objetivo; el resto
## (curación, escudo, buffs...) se activa tal cual, sin apuntar a nada.
func _usar_alguna_habilidad() -> void:
	var slots = _jugador.slot_habilidades
	if slots == null:
		return
	var disponibles: Array[int] = []
	for i in slots.total_slots:
		var h: HabilidadBase = slots.obtener(i)
		if h and h.puede_usarse():
			disponibles.append(i)
	if disponibles.is_empty():
		return
	var elegido: int = disponibles[randi() % disponibles.size()]
	var h: HabilidadBase = slots.obtener(elegido)
	var dir := Vector2.ZERO
	if h.requiere_direccion and is_instance_valid(_objetivo):
		var hacia_objetivo: Vector2 = (_objetivo.global_position as Vector2) - (_jugador.global_position as Vector2)
		if hacia_objetivo.length() > 0.1:
			dir = hacia_objetivo.normalized()
	_jugador._activar_slot(elegido, dir)


func _mover_hacia(destino: Vector2) -> void:
	var posicion: Vector2 = _jugador.global_position
	if posicion.distance_to(destino) < 8.0:
		_jugador._joystick_movimiento(Vector2.ZERO)
		return
	_jugador._joystick_movimiento(_direccion_navegada_hacia(destino))


## Dirección hacia "destino" siguiendo la malla de navegación del nivel
## actual (rodea muros/obstáculos en vez de ir en línea recta) — mismo
## criterio de fallback que MovimientoComponente._avanzar_hacia_destino: sin
## malla en el nivel o ruta vacía (el agente devuelve nuestra propia
## posición), línea recta de siempre.
func _direccion_navegada_hacia(destino: Vector2) -> Vector2:
	_actualizar_mapa_navegacion()
	if _agente_navegacion.target_position.distance_to(destino) > 8.0:
		_agente_navegacion.target_position = destino
	var posicion: Vector2 = _jugador.global_position
	if not _agente_navegacion.is_navigation_finished():
		var siguiente: Vector2 = _agente_navegacion.get_next_path_position()
		if siguiente != posicion:
			return posicion.direction_to(siguiente)
	return posicion.direction_to(destino)


func _mover_alejandose_de(posicion: Vector2) -> void:
	var lejos: Vector2 = (_jugador.global_position as Vector2) - posicion
	if lejos.length() < 0.1:
		lejos = Vector2.RIGHT
	_jugador._joystick_movimiento(lejos.normalized())
