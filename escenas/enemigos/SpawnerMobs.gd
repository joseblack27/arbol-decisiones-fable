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

var _vivos: Array[Node] = []
var _tiempo_restante: float = 0.0
var _contenedor: Node
# La generación inicial espera a la malla de navegación (puede tardar algún
# physics_frame); hasta que termine, _process no debe competir generando por
# intervalo, o el recuento de "vivos" quedaría descuadrado.
var _listo := false


func _ready() -> void:
	_contenedor = get_parent()
	# Fase 5 del plan de multijugador: el MultiplayerSpawner tiene que
	# existir IGUAL en todos los peers para poder replicar el spawn — se
	# arma acá por código en vez de a mano en cada nivel. Quien de verdad
	# decide CUÁNDO generar (más abajo) sigue siendo solo el servidor.
	if Utils.en_red():
		_configurar_spawner_red()
		# El MultiplayerSpawner replica el lote de mobs YA EXISTENTES a un
		# peer nuevo apenas conecta — cuando ese cliente todavía está
		# cargando el nivel y su SpawnerRed no existe: el lote se pierde y
		# esos mobs quedan INVISIBLES para él para siempre (atacan desde el
		# servidor sin verse — el "mob invisible" reportado en juego real).
		# Solución: cuando el peer confirma que terminó de cargar
		# (peer_listo, el mismo handshake del spawn inicial), el servidor le
		# reenvía a mano los vivos de este spawner (_al_peer_listo).
		if multiplayer.is_server():
			GestorNiveles.peer_listo.connect(_al_peer_listo)
	if cantidad_inicial > 0 and (not Utils.en_red() or multiplayer.is_server()):
		await _esperar_malla_lista()
		for _i in cantidad_inicial:
			_generar_uno()
	_tiempo_restante = intervalo_spawn
	_listo = true


func _configurar_spawner_red() -> void:
	var spawner := MultiplayerSpawner.new()
	spawner.name = "SpawnerRed"
	# add_child() PRIMERO: spawn_path se resuelve con get_node_or_null() contra
	# un NodePath absoluto — si spawner todavía no está dentro del árbol de
	# escena, esa resolución falla ("Can't use get_node() with absolute paths
	# from outside the active scene tree") y spawn_path queda mal configurado.
	# Con el spawner replicador roto, cada mob que este spawner genera existe
	# en el servidor (puede golpear) pero nunca se replica a los clientes —
	# el mob invisible reportado en juego real.
	add_child(spawner)
	spawner.spawn_path = _contenedor.get_path()
	for escena in lista_mobs:
		if escena:
			spawner.add_spawnable_scene(escena.resource_path)


## true si acá corresponde generar/decidir mobs de verdad: sin multiplayer
## activo (un solo jugador, de siempre) siempre true; en red, solo el
## servidor. El cliente nunca llama _generar_uno() — ve los mobs aparecer
## solos, replicados por el MultiplayerSpawner de arriba.
##
## ANTES esto también esperaba (con tope de 5s) a que TODOS los clientes
## conectados confirmaran haber cargado el nivel actual, para que el EVENTO
## DE SPAWN no se perdiera contra uno que todavía no tuviera su propio nodo
## "SpawnerRed" — a diferencia de la posición de un mob (que se autocorrige
## sola al ser unreliable_ordered), ese evento no se reintenta.
## Ese freno terminó siendo la causa de un bug peor: si el ack de "listo"
## de un cliente (celular, red real con más latencia que las pruebas
## locales) tardaba más de esos 5s — algo bastante común al volver a un
## nivel por portal, no solo en la conexión inicial — la tanda ENTERA de
## cantidad_inicial se saltaba en silencio, y el nivel quedaba vacío
## hasta que el goteo lento de _process() (1 cada intervalo_spawn) lo
## rellenara de a poco (hasta minuto y medio para 10 mobs) — "los mobs
## están bugueados, no los veo" reportado en juego real. Ya no hace falta
## ese freno: _al_peer_listo() (ver _ready) reenvía a mano los mobs vivos a
## cualquier peer que confirme estar listo DESPUÉS de que ya se generaron,
## cubriendo el mismo caso sin arriesgar perder la tanda entera.
func _debe_generar_localmente() -> bool:
	if not Utils.en_red():
		return true
	return multiplayer.is_server()


## Si este mundo tiene una malla de navegación (nivel real con capa
## "Navegacion"), espera a que sincronice antes de generar nada: recién
## cargado el nivel tarda unos physics_frame en terminar de bakear/sincronizar
## y hasta entonces cualquier consulta de posición devolvería "inválido".
## El nivel ya tiene su propio fundido a negro, así que esta espera no se
## nota en pantalla. Si no hay malla configurada (p. ej. una prueba aislada
## sin nivel), no hay nada que esperar.
##
## OJO: map_get_iteration_id() != 0 NO basta — en un nivel grande (miles de
## celdas) el motor hace VARIAS pasadas de sincronización: la primera deja
## iteration_id en 1 pero solo cubre una fracción del mapa (verificado: en
## Pradera, iteration_id=1 se mantiene 7 físicas seguidas antes de saltar a
## 2, la sincronización real y completa). Con la espera vieja (cortar en el
## primer != 0), _punto_de_generacion_valido() consultaba un mapa a medio
## hornear: TODOS los candidatos aleatorios devolvían Vector2.ZERO como
## "no encontrado" y el spawner caía siempre al mismo fallback (su propia
## posición) — los mobs generados aparecían todos amontonados en el mismo
## punto en vez de repartidos por radio_spawn.
const _FRAMES_ESTABILIDAD_MALLA := 3

func _esperar_malla_lista() -> void:
	var mapa := get_world_2d().navigation_map
	var intentos := 0
	while NavigationServer2D.map_get_iteration_id(mapa) == 0 and intentos < 60:
		await get_tree().physics_frame
		intentos += 1
	var anterior := NavigationServer2D.map_get_iteration_id(mapa)
	var estable := 0
	while estable < _FRAMES_ESTABILIDAD_MALLA and intentos < 90:
		await get_tree().physics_frame
		intentos += 1
		var actual := NavigationServer2D.map_get_iteration_id(mapa)
		if actual == anterior:
			estable += 1
		else:
			estable = 0
			anterior = actual


func _process(delta: float) -> void:
	if not _listo or not activo or lista_mobs.is_empty() or _vivos.size() >= maximo_mobs:
		return
	if not _debe_generar_localmente():
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
	# force_readable_name=true: sin esto, add_child() le pone un nombre
	# interno tipo "@CharacterBody2D@37" — MultiplayerSpawner lo rechaza
	# ("Unable to auto-spawn node with reserved name") y el mob nunca
	# replica al cliente.
	_contenedor.add_child(mob, true)
	if mob is Node2D:
		(mob as Node2D).global_position = punto
	_vivos.append(mob)
	# tree_exiting es nativa de Node: dispara justo cuando el mob se libera
	# de verdad (muerte, o el nivel entero desapareciendo), sin necesitar
	# ninguna señal propia de Enemigo.
	mob.tree_exiting.connect(_al_salir_mob.bind(mob), CONNECT_ONE_SHOT)

	# Insurance contra el "mob invisible" (SpawnerRed en teoría lo replica
	# solo con add_child, pero en juego real a veces no le llega a un peer
	# YA conectado — no solo a los que llegan tarde, ver _al_peer_listo).
	# Reusa la MISMA función de resincronización, pero en broadcast a TODOS
	# los conectados apenas se genera, no solo al reconectar: idempotente
	# (_recibir_mobs_existentes se salta si el nodo ya llegó por la vía
	# normal), así que no duplica nada para quien sí lo recibió bien.
	if Utils.en_red() and multiplayer.is_server():
		rpc("_recibir_mobs_existentes", [[escena.resource_path, String(mob.name), punto]])


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


func _demasiado_cerca_de_jugador(punto: Vector2) -> bool:
	for jugador in get_tree().get_nodes_in_group("jugadores"):
		if jugador is Node2D and punto.distance_to(jugador.global_position) < _DISTANCIA_MINIMA_JUGADOR:
			return true
	return false


func _al_salir_mob(mob: Node) -> void:
	_vivos.erase(mob)


# =============================================================================
# RESINCRONIZACIÓN DE MOBS EXISTENTES (peers que llegan tarde)
# =============================================================================

## SERVIDOR: un peer terminó de cargar el nivel — mandarle los mobs de este
## spawner que ya estaban vivos ANTES de que se conectara (el lote automático
## del MultiplayerSpawner se le perdió mientras cargaba, ver _ready).
func _al_peer_listo(peer_id: int) -> void:
	var datos: Array = []
	var nombres_omitidos: Array = []
	for mob in _vivos:
		if not is_instance_valid(mob) or not (mob is Node2D):
			# Diagnóstico permanente (mob invisible reportado en juego real,
			# sin poder reproducirlo en pruebas locales): si esto aparece en
			# el log de Docker justo cuando alguien se conecta, confirma que
			# un mob murió/se liberó ENTRE que se generó y que el peer
			# terminó de cargar — nunca llega a resincronizarse porque ya
			# no está en _vivos con datos válidos en ese instante.
			nombres_omitidos.append(str(mob.name) if is_instance_valid(mob) else "<liberado>")
			continue
		datos.append([mob.scene_file_path, String(mob.name), (mob as Node2D).global_position])
	print("[RESYNC] peer=%d spawner=%s mobs_reenviados=%d omitidos=%s" % [
		peer_id, name, datos.size(), str(nombres_omitidos)])
	if datos.is_empty():
		return
	rpc_id(peer_id, "_recibir_mobs_existentes", datos)


## CLIENTE: instancia las réplicas que le falten, con el MISMO nombre bajo el
## MISMO contenedor que en el servidor — así los RPCs por ruta (posición,
## animación, despawn) le llegan igual que a una réplica del spawner normal.
## Idempotente en la CREACIÓN (si el nodo ya existe no se instancia de
## nuevo), pero NO en la posición: si el nodo ya llegó por el lote
## automático del MultiplayerSpawner (su catch-up a peers que se conectan
## tarde, que a veces sí dispara aunque no sea confiable — ver comentario en
## _ready), ese lote NUNCA trae posición — Enemigo no usa Synchronizer para
## eso a propósito (replica por RPC explícito, ver Enemigo._physics_process).
## Antes esto se saltaba de largo si el nodo "ya estaba", dejándolo pegado
## en el origen del contenedor para siempre — el "todos los mobs spawnean
## en el centro" reportado en juego real. Ahora SIEMPRE se le pisa la
## posición real, exista ya o se acabe de crear acá.
@rpc("authority", "reliable")
func _recibir_mobs_existentes(datos: Array) -> void:
	if _contenedor == null:
		_contenedor = get_parent()
	for entrada in datos:
		var ruta: String = entrada[0]
		var nombre: String = entrada[1]
		var pos: Vector2 = entrada[2]
		if nombre == "":
			continue
		var mob := _contenedor.get_node_or_null(nombre)
		if mob == null:
			var escena := load(ruta) as PackedScene
			if escena == null:
				continue
			mob = escena.instantiate()
			mob.name = nombre
			_contenedor.add_child(mob)
		if mob is Node2D:
			(mob as Node2D).global_position = pos
