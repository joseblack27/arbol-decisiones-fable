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
#   lee  "agente", "componente_movimiento", "ruido_posicion" (si existe, la
#        consume y borra: sesga el próximo destino hacia ese punto — ver
#        Enemigo._priorizar_atacante)
#   escribe "posicion_origen" (la primera vez, para deambular alrededor de ella)
# =============================================================================
class_name AccionDeambular
extends Accion

@export_group("Configuración Deambular")
## Velocidad de paseo (más lenta que la persecución).
@export var velocidad: float = 60.0
## Radio máximo alrededor del origen donde elegir destinos.
@export var radio_deambulacion: float = 260.0
## Segundos de pausa al llegar a cada destino — antes 1.5s, que en los
## destinos más cercanos (hasta 0.3x radio_deambulacion, ~1s de caminata)
## superaba el propio tiempo caminando: el mob pasaba más tiempo plantado
## que moviéndose entre destinos, y se sentía "muerto" (reportado por el
## usuario). Sigue siendo una pausa real (mira alrededor, no un tropezón),
## solo que ya no domina el ciclo.
@export var espera_en_destino: float = 0.6
## Distancia a la que un destino se considera alcanzado.
@export var radio_llegada: float = 10.0
## Dispersión (a cada lado) al sesgar el destino hacia un aviso de "ruido"
## (ver más abajo) — así no camina en línea perfectamente recta hacia el
## golpe, se ve más como "fue a fijarse para ese lado".
@export var dispersion_ruido_grados: float = 35.0

## Cuántos puntos al azar se prueban antes de rendirse y quedarse en el
## origen (mismo criterio que SpawnerMobs._punto_de_generacion_valido).
const _INTENTOS_MAXIMOS := 8
## Distancia (px) máxima entre un candidato y el punto navegable más
## cercano para considerarlo "sobre" la malla.
const _TOLERANCIA_NAVEGACION := 6.0

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

	# Un aviso de ruido nuevo INTERRUMPE el paseo en curso (destino actual o
	# pausa entre destinos) — sin esto, un golpe podía quedar esperando en
	# memoria varios segundos hasta que el mob terminara solo de caminar
	# hacia un destino viejo sin relación, y la reacción se sentía como si
	# no pasara nada (reportado: "le pego desde fuera de su visión y no
	# deambula hacia mi dirección"). Con esto, el próximo tick ya recalcula.
	if _memoria.existe("ruido_posicion"):
		_tiene_destino = false
		_fin_espera = 0.0

	var ahora := Time.get_ticks_msec() / 1000.0

	# Pausa entre destinos.
	if ahora < _fin_espera:
		movimiento.detener()
		return Estado.EXITOSO

	if not _tiene_destino:
		_elegir_destino(agente)

	# Comandar ANTES de preguntar "llegó" -- llego_al_destino() lee el
	# estado interno que deja el ÚLTIMO comandar_destino(), así que tiene
	# que estar fresco para ESTE _destino en el mismo tick en que se eligió.
	movimiento.comandar_destino(_destino, velocidad)

	# llego_al_destino() (no una distancia cruda): además del margen normal,
	# se rinde sola si el destino cayó fuera de lo navegable Y quedó
	# atascada intentando llegar (ver MovimientoComponente._TIEMPO_MAXIMO_
	# INTENTANDO_LLEGAR) — red de seguridad extra sobre la validación de
	# _elegir_destino(), por si algo deja igual un punto inalcanzable.
	if movimiento.llego_al_destino(radio_llegada):
		_tiene_destino = false
		_fin_espera = ahora + espera_en_destino
		movimiento.detener()
		return Estado.EXITOSO

	return Estado.EXITOSO


func _on_reiniciar() -> void:
	super._on_reiniciar()
	_tiene_destino = false
	_fin_espera = 0.0


## "ruido_posicion" la escribe Enemigo._priorizar_atacante cuando golpea al
## mob alguien que NO tiene detectado (fuera de su visión): en vez de
## perseguirlo a ciegas (eso sería detectarlo a cualquier distancia con solo
## golpearlo), el próximo destino se sesga hacia esa dirección — pero sigue
## acotado al radio_deambulacion normal, nunca más lejos que cualquier otro
## paseo. Se consume una sola vez: el siguiente destino después de este
## vuelve a ser al azar, salvo que llegue otro golpe.
##
## Cada candidato se valida contra la malla de Navegacion real (mismo
## criterio que SpawnerMobs._punto_de_generacion_valido) antes de aceptarlo
## -- en un campo abierto (Pradera, Camino) casi cualquier punto en el
## radio es válido y esto no cambia nada, pero en topología de túneles
## angostos (Hormiguero, Mina) un radio_deambulacion normal puede caer
## fácil FUERA de la malla (dentro de una pared). Sin esta validación, el
## mob quedaba comandado para siempre hacia un punto inalcanzable —
## reportado como "las hormigas siempre tratan de volver a un mismo sitio
## que está fuera del mapa" (el propio destino nunca cambiaba porque la
## condición de "llegué" original nunca se cumplía contra un punto así).
func _elegir_destino(agente: Node2D) -> void:
	var origen: Vector2 = _memoria.obtener("posicion_origen", Vector2.ZERO)
	var punto_ruido: Variant = null
	if _memoria.existe("ruido_posicion"):
		punto_ruido = _memoria.obtener("ruido_posicion")
		_memoria.eliminar("ruido_posicion")

	var mapa := GestorNiveles.mapa_navegacion_de(agente)
	# Mientras el mapa no "responde" de verdad (recién creado el nivel,
	# antes de que termine su primera sincronización real -- ver Utils.
	# esperar_malla_de_nivel_lista/_malla_de_nivel_responde, mismo criterio
	# que ya usa SpawnerMobs antes de generar), map_get_closest_point()
	# devuelve (0,0) SIN IMPORTAR el punto consultado. Confiar en eso sin
	# este chequeo colaba (0,0) como "el punto navegable más cercano" y
	# cualquier candidato normal se leía como a miles de píxeles de la
	# malla, invalidando destinos que en realidad eran perfectamente
	# válidos apenas el mapa terminara de sincronizar.
	var hay_malla := mapa.is_valid() and not NavigationServer2D.map_get_regions(mapa).is_empty() \
		and Utils._malla_de_nivel_responde(mapa)

	for _intento in _INTENTOS_MAXIMOS:
		var angulo: float
		if punto_ruido != null:
			var dispersion := deg_to_rad(dispersion_ruido_grados)
			angulo = origen.direction_to(punto_ruido).angle() + randf_range(-dispersion, dispersion)
		else:
			angulo = randf_range(0.0, TAU)
		var distancia := randf_range(radio_deambulacion * 0.3, radio_deambulacion)
		var candidato := origen + Vector2.from_angle(angulo) * distancia
		if not hay_malla:
			_destino = candidato
			_tiene_destino = true
			return
		var mas_cercano: Vector2 = NavigationServer2D.map_get_closest_point(mapa, candidato)
		if candidato.distance_to(mas_cercano) <= _TOLERANCIA_NAVEGACION:
			_destino = candidato
			_tiene_destino = true
			return

	# Nada válido tras varios intentos: quedarse cerca del origen -- ya
	# demostró ser navegable (el propio mob está parado ahí).
	_destino = origen
	_tiene_destino = true
