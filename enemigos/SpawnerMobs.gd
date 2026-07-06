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

var _vivos: Array[Node] = []
var _tiempo_restante: float = 0.0
var _contenedor: Node
# La generación inicial espera a la malla de navegación (puede tardar algún
# physics_frame); hasta que termine, _process no debe competir generando por
# intervalo, o el recuento de "vivos" quedaría descuadrado.
var _listo := false


func _ready() -> void:
	_contenedor = get_parent()
	if cantidad_inicial > 0:
		await _esperar_malla_lista()
		for _i in cantidad_inicial:
			_generar_uno()
	_tiempo_restante = intervalo_spawn
	_listo = true


## Si este mundo tiene una malla de navegación (nivel real con capa
## "Navegacion"), espera a que sincronice antes de generar nada: recién
## cargado el nivel tarda unos physics_frame en terminar de bakear/sincronizar
## y hasta entonces cualquier consulta de posición devolvería "inválido".
## El nivel ya tiene su propio fundido a negro, así que esta espera no se
## nota en pantalla. Si no hay malla configurada (p. ej. una prueba aislada
## sin nivel), no hay nada que esperar.
func _esperar_malla_lista() -> void:
	var mapa := get_world_2d().navigation_map
	var intentos := 0
	while NavigationServer2D.map_get_iteration_id(mapa) == 0 and intentos < 60:
		await get_tree().physics_frame
		intentos += 1


func _process(delta: float) -> void:
	if not _listo or not activo or lista_mobs.is_empty() or _vivos.size() >= maximo_mobs:
		return
	_tiempo_restante -= delta
	if _tiempo_restante <= 0.0:
		_tiempo_restante = intervalo_spawn
		_generar_uno()


func activar() -> void:
	activo = true


func desactivar() -> void:
	activo = false


## Cuántos mobs generados por ESTE spawner siguen vivos ahora mismo.
func cantidad_viva() -> int:
	return _vivos.size()


func _generar_uno() -> void:
	if lista_mobs.is_empty() or _contenedor == null:
		return
	var punto = _punto_de_generacion_valido()
	if punto == null:
		return
	var escena: PackedScene = lista_mobs[randi() % lista_mobs.size()]
	var mob := escena.instantiate()
	_contenedor.add_child(mob)
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
	var mapa := get_world_2d().navigation_map
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
		var mas_cercano: Vector2 = NavigationServer2D.map_get_closest_point(mapa, candidato)
		if candidato.distance_to(mas_cercano) <= _TOLERANCIA_NAVEGACION:
			return candidato
	# Nada válido en el radio: se cae de vuelta a la posición del propio
	# spawner (se asume colocado sobre terreno transitable por quien lo puso).
	var mas_cercano_base: Vector2 = NavigationServer2D.map_get_closest_point(mapa, global_position)
	if global_position.distance_to(mas_cercano_base) <= _TOLERANCIA_NAVEGACION:
		return global_position
	return null


func _al_salir_mob(mob: Node) -> void:
	_vivos.erase(mob)
