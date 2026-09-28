class_name SpawnerMobs
extends Node2D
## Genera enemigos periódicamente alrededor de su posición, con un tope de
## cuántos puede tener vivos A LA VEZ y una lista configurable de qué tipos
## puede generar (se elige uno al azar en cada intento).
##
## USO: colócalo como hijo del contenedor "Enemigos" de un nivel (o de
## cualquier Node2D). Los mobs que genera se añaden a SU MISMO padre, para
## participar en el mismo Y-sort que el resto de enemigos del nivel — el
## spawner en sí es solo un punto de referencia, como un Marker2D con lógica.
##
## Un nivel puede tener varios spawners independientes (p. ej. uno de lobos
## al norte, otro de arañas en una cueva), cada uno con su propio tope,
## lista y ritmo.
##
## Los mobs generados NO se reciclan (sin object pooling): ver la nota en
## Enemigo._desvanecer_y_eliminar() sobre por qué un mob no es un buen
## candidato para poolear como sí lo son los proyectiles.

## Tipos de enemigo que puede generar (PackedScene con raíz CharacterBody2D).
@export var lista_mobs: Array[PackedScene] = []
## Cuántos generados por ESTE spawner pueden estar vivos a la vez.
@export var maximo_mobs: int = 3
## Segundos entre intentos de generación (solo genera si hay hueco libre).
@export var intervalo_spawn: float = 8.0
## Radio (px) alrededor del spawner donde aparece cada mob nuevo.
@export var radio_spawn: float = 100.0
## Cuántos generar de golpe nada más arrancar (0 = empezar vacío y esperar
## al primer intervalo).
@export var cantidad_inicial: int = 0
## Si está apagado, no genera nada hasta que activar() lo encienda.
@export var activo: bool = true

## Cuántos puntos al azar se prueban antes de rendirse en un intento de
## generación (ver _punto_de_generacion_valido).
const _INTENTOS_MAXIMOS := 8
## Distancia (px) máxima entre un punto candidato y el punto transitable más
## cercano de la malla de navegación para considerarlo "sobre" la malla.
const _TOLERANCIA_NAVEGACION := 6.0
## Distancia (px) mínima entre un punto candidato y cualquier jugador: sin
## esto, un radio de spawn grande podía generar mobs justo ENCIMA del
## jugador (incluida su zona de aparición al entrar al nivel), que lo
## atacaban antes de que pudiera reaccionar ("el golpe al iniciar").
const _DISTANCIA_MINIMA_JUGADOR := 350.0
## Segundos entre barridos de "¿algún mob vivo quedó fuera del mapa?" (ver
## _revisar_mobs_fuera_de_limites). El punto de generación ya se valida (ver
## _punto_de_generacion_valido), pero deambular o huir puede empujar a un mob
## fuera del borde con el tiempo. Más espaciado que intervalo_spawn a
## propósito: no necesita reaccionar al instante.
const _INTERVALO_REVISION_LIMITES := 5.0

## Activa la limpieza de mobs fuera del mapa (ver
## _revisar_mobs_fuera_de_limites), que pide dos revisiones seguidas antes de
## borrar para no llevarse falsos positivos pasajeros.
var limpieza_fuera_de_limites_activa := true

var _vivos: Array[Node] = []
## Mobs que dieron "fuera de la malla" en la revisión ANTERIOR -- ver
## _revisar_mobs_fuera_de_limites: solo se borran si TAMBIÉN dan fuera de
## la malla en la revisión SIGUIENTE (dos veces seguidas).
var _sospechosos_fuera_de_limites: Array[Node] = []
var _tiempo_restante: float = 0.0
var _tiempo_restante_revision: float = 0.0
var _contenedor: Node
# La generación inicial espera a la malla de navegación (puede tardar algún
# physics_frame); hasta que termine, _process no debe competir generando por
# intervalo, o el recuento de "vivos" quedaría descuadrado.
var _listo := false


func _ready() -> void:
	_contenedor = get_parent()
	# Solo decide CUÁNDO generar (servidor/sin red); que los clientes vean los
	# mobs lo resuelve ReplicadorEnemigos, que observa el contenedor.
	if cantidad_inicial > 0 and (not Utils.en_red() or multiplayer.is_server()):
		await Utils.esperar_malla_de_nivel_lista(self)
		for _i in cantidad_inicial:
			_generar_uno()
	_tiempo_restante = intervalo_spawn
	_tiempo_restante_revision = _INTERVALO_REVISION_LIMITES
	_listo = true


## true si acá corresponde generar/decidir mobs de verdad: sin red siempre;
## en red, solo el servidor.
func _debe_generar_localmente() -> bool:
	if not Utils.en_red():
		return true
	return multiplayer.is_server()


func _process(delta: float) -> void:
	if not _listo or not _debe_generar_localmente():
		return
	# Nivel sin nadie adentro: no tiene sentido poblarlo (en el servidor
	# pueden convivir varios niveles a la vez, ver GestorNiveles). Además
	# evita mandarle a los clientes eventos de spawn de un mapa que no
	# tienen cargado — el motor los rechazaría con "node not found".
	if not GestorNiveles.hay_jugadores_en(_nivel_propio()):
		return

	# Corre SIEMPRE, sin importar activo/maximo_mobs: justo cuando el
	# spawner está "lleno" es cuando más importa detectar un fantasma
	# afuera del mapa ocupando un lugar de verdad (ver la constante).
	_tiempo_restante_revision -= delta
	if _tiempo_restante_revision <= 0.0:
		_tiempo_restante_revision = _INTERVALO_REVISION_LIMITES
		_revisar_mobs_fuera_de_limites()

	if not activo or lista_mobs.is_empty() or _vivos.size() >= maximo_mobs:
		return
	_tiempo_restante -= delta
	if _tiempo_restante <= 0.0:
		_tiempo_restante = intervalo_spawn
		_generar_uno()


func activar() -> void:
	activo = true
	# _tiempo_restante corre desde _ready() sin importar "activo" (ver
	# _process, que resta delta antes de cortar por "not activo"). Cuando
	# ActivadorSalaSpawners activa una sala (spawner arrancado con
	# activo=false, ver generar_nivel_hormiguero.gd), ese temporizador puede
	# estar recién reiniciado, y la primera hormiga tardaría un
	# intervalo_spawn entero: el jugador ya habría cruzado la sala.
	_tiempo_restante = 0.0


func desactivar() -> void:
	activo = false


## Cuántos mobs generados por ESTE spawner siguen vivos ahora mismo.
func cantidad_viva() -> int:
	return _vivos.size()


## El nivel al que pertenece este spawner. Se busca hacia arriba en vez de
## preguntarle a GestorNiveles "cuál es el nivel": en el servidor hay varios
## cargados a la vez y cada spawner es de UNO solo.
func _nivel_propio() -> NivelBase:
	var nodo := get_parent()
	while nodo != null and not (nodo is NivelBase):
		nodo = nodo.get_parent()
	return nodo as NivelBase


func _generar_uno() -> void:
	if lista_mobs.is_empty() or _contenedor == null:
		return
	var punto = _punto_de_generacion_valido()
	if punto == null:
		return
	var escena: PackedScene = lista_mobs[randi() % lista_mobs.size()]
	var mob := escena.instantiate()
	# force_readable_name=true: el nombre viaja a los clientes (ver
	# ReplicadorEnemigos) y tiene que ser el mismo en los dos lados.
	_contenedor.add_child(mob, true)
	if mob is Node2D:
		(mob as Node2D).global_position = punto
	_vivos.append(mob)
	# tree_exiting es nativa de Node: dispara justo cuando el mob se libera
	# de verdad (muerte, o el nivel entero desapareciendo), sin necesitar
	# ninguna señal propia de Enemigo.
	mob.tree_exiting.connect(_al_salir_mob.bind(mob), CONNECT_ONE_SHOT)


## Busca un punto dentro de radio_spawn que esté sobre la malla de
## navegación (misma malla dedicada de MovimientoComponente.MASCARA_NAVEGACION):
## así se evita instanciar mobs fuera del mapa o sobre casillas no
## transitables (agua, huecos) sin duplicar lógica de terreno.
## Devuelve null si tras varios intentos no encuentra ninguno válido.
func _punto_de_generacion_valido() -> Variant:
	# Mapa de SU nivel (ver NivelBase._crear_mapa_navegacion): el del mundo
	# mezclaría la malla de todos los niveles cargados a la vez.
	var mapa := GestorNiveles.mapa_navegacion_de(self)
	if NavigationServer2D.map_get_regions(mapa).is_empty():
		# Sin malla de navegación en este mundo (p. ej. una prueba aislada sin
		# nivel real): no hay nada que validar, se mantiene el comportamiento
		# simple de siempre.
		return global_position + Vector2(
			randf_range(-radio_spawn, radio_spawn), randf_range(-radio_spawn, radio_spawn)
		)
	for _i in _INTENTOS_MAXIMOS:
		var candidato: Vector2 = global_position + Vector2(
			randf_range(-radio_spawn, radio_spawn), randf_range(-radio_spawn, radio_spawn)
		)
		if _demasiado_cerca_de_jugador(candidato):
			continue
		var mas_cercano: Vector2 = NavigationServer2D.map_get_closest_point(mapa, candidato)
		if candidato.distance_to(mas_cercano) <= _TOLERANCIA_NAVEGACION:
			return candidato
	# Nada válido en el radio: se cae de vuelta a la posición del propio
	# spawner (se asume colocado sobre terreno transitable por quien lo puso).
	if _demasiado_cerca_de_jugador(global_position):
		return null
	var mas_cercano_base: Vector2 = NavigationServer2D.map_get_closest_point(mapa, global_position)
	if global_position.distance_to(mas_cercano_base) <= _TOLERANCIA_NAVEGACION:
		return global_position
	return null


## Elimina (no reposiciona) a cualquier mob de _vivos que haya quedado más
## lejos de _TOLERANCIA_NAVEGACION de la malla DOS revisiones seguidas —
## más simple y sin riesgo de "moverlo" a otro punto igual de inválido.
## Saca a "mob" de _vivos acá mismo, SIN esperar a que tree_exiting dispare
## _al_salir_mob (queue_free() es diferido al final del fotograma) — así
## el próximo _generar_uno() (o una segunda pasada de esta misma revisión)
## ya ve el hueco libre de inmediato, no recién en el fotograma siguiente.
## Sin botín ni XP ni animación de muerte a propósito: esto no es una
## muerte de combate, es descartar un estado anómalo.
##
## Exige DOS revisiones seguidas fuera de la malla (separadas por
## _INTERVALO_REVISION_LIMITES) antes de borrar: _TOLERANCIA_NAVEGACION
## (6 px) es ajustada para un mob en movimiento (corta esquinas, se desvía
## por evasión), que puede quedar un instante unos px afuera sin estar
## atascado, y con una sola revisión se borraban mobs sanos. Uno de verdad
## atascado sigue afuera en la revisión siguiente.
func _revisar_mobs_fuera_de_limites() -> void:
	if not limpieza_fuera_de_limites_activa:
		return
	if _vivos.is_empty():
		_sospechosos_fuera_de_limites.clear()
		return
	var mapa := GestorNiveles.mapa_navegacion_de(self)
	if NavigationServer2D.map_get_regions(mapa).is_empty():
		return
	var fuera_esta_vez: Array[Node] = []
	for mob in _vivos.duplicate():
		if not is_instance_valid(mob) or not (mob is Node2D):
			continue
		var posicion: Vector2 = (mob as Node2D).global_position
		var mas_cercano: Vector2 = NavigationServer2D.map_get_closest_point(mapa, posicion)
		if posicion.distance_to(mas_cercano) > _TOLERANCIA_NAVEGACION:
			fuera_esta_vez.append(mob)
			if _sospechosos_fuera_de_limites.has(mob):
				_vivos.erase(mob)
				mob.queue_free()
	_sospechosos_fuera_de_limites = fuera_esta_vez


func _demasiado_cerca_de_jugador(punto: Vector2) -> bool:
	for jugador in get_tree().get_nodes_in_group("jugadores"):
		if jugador is Node2D and punto.distance_to(jugador.global_position) < _DISTANCIA_MINIMA_JUGADOR:
			return true
	return false


func _al_salir_mob(mob: Node) -> void:
	_vivos.erase(mob)
