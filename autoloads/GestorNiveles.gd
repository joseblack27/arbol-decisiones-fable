extends Node
## GestorNiveles (autoload): intercambia el nivel activo del mundo.
##
## Mundo.tscn es el "cascarón" persistente (jugador + UI); los niveles son
## escenas intercambiables que viven dentro de un contenedor. Este gestor:
##   1. Libera el nivel actual.
##   2. Instancia el nuevo (cualquier escena cuyo raíz sea NivelBase).
##   3. Coloca al jugador en el PuntoAparicion del nivel.
##
## El cambio siempre se difiere: los portales lo piden desde body_entered
## (callback de física) donde no se puede tocar el árbol.

signal nivel_cargado(nivel: NivelBase)
## Solo en el servidor: un peer confirmó (vía _marcar_listo_red) que terminó
## de cargar el nivel actual. ServidorDedicado la usa para recién entonces
## spawnear el Jugador de ese peer — así el cliente carga el mapa completo
## ANTES de que exista su jugador.
signal peer_listo(peer_id: int)

## Segundos tras cargar en los que se ignoran nuevas peticiones
## (evita rebotes si el jugador aparece cerca de un portal).
const GRACIA_TRAS_CARGA := 1.0
## Duración de cada mitad del fundido (a negro / desde negro).
const DURACION_FUNDIDO := 0.3

var _contenedor: Node
var _jugador: Node2D
var _cargando := false
var _gracia := 0.0

# ── Mitigación de la carrera servidor/cliente al cargar nivel ──────────────
# El cambio de nivel NO está sincronizado por red: cada peer llama cambiar_
# nivel() por su cuenta (mismo criterio en Mundo.gd/ServidorDedicado.gd para
# el nivel inicial, y en cada portal). El cliente tarda más en llegar a
# "nivel cargado" (arrastra el handshake de conexión antes), así que durante
# esa ventana el servidor ya puede estar mandando RPCs de mobs que en el
# cliente todavía no existen — la posición se autocorrige sola (unreliable_
# ordered), pero el EVENTO DE SPAWN de un mob nuevo (SpawnerMobs, vía
# MultiplayerSpawner) no se reintenta: si llega antes de que el cliente
# tenga su propio nodo "SpawnerRed", ese mob no aparece nunca para él.
# _generacion_nivel distingue acks de una carga vieja (nivel ya cambió de
# nuevo) de los de la carga actual.
var _generacion_nivel: int = 0
var _peers_listos: Array[int] = []

## Overlay de fundido autoconstruido: así el gestor no depende de que
## Mundo.tscn tenga un nodo concreto, y funciona igual desde cualquier
## escena que registre un contenedor.
var _velo: ColorRect


func _ready() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 100  # por encima de la UI del juego durante la transición
	_velo = ColorRect.new()
	_velo.color = Color.BLACK
	_velo.modulate.a = 0.0
	_velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	capa.add_child(_velo)
	add_child(capa)


func _process(delta: float) -> void:
	_gracia = maxf(0.0, _gracia - delta)


## Mundo.tscn llama esto al arrancar.
func registrar(contenedor: Node, jugador: Node2D) -> void:
	_contenedor = contenedor
	_jugador = jugador


## En red, el jugador propio recién existe DESPUÉS de conectar (ver
## Mundo.gd) — el nivel ya está cargado para entonces, así que hay que
## reposicionarlo "a mano" en vez de esperar al próximo cambiar_nivel().
func asignar_jugador(jugador: Node2D) -> void:
	_jugador = jugador
	var nivel := nivel_actual()
	if jugador == null or nivel == null:
		return
	var punto: Node2D = nivel.punto_aparicion()
	if punto != null:
		jugador.global_position = punto.global_position
		if jugador is CharacterBody2D:
			(jugador as CharacterBody2D).velocity = Vector2.ZERO
	if jugador.has_method(&"aplicar_limites_camara"):
		jugador.call(&"aplicar_limites_camara", nivel.limites_camara())
	if jugador.has_method(&"resetear_camara"):
		jugador.call(&"resetear_camara")


func nivel_actual() -> NivelBase:
	if _contenedor == null:
		return null
	for hijo in _contenedor.get_children():
		if hijo is NivelBase:
			return hijo
	return null


func cambiar_nivel(ruta_escena: String) -> void:
	if _cargando or _gracia > 0.0:
		return
	if _contenedor == null:
		push_error("GestorNiveles: nadie llamó a registrar(); no hay contenedor.")
		return
	_cargando = true
	_cargar.call_deferred(ruta_escena)


func _cargar(ruta_escena: String) -> void:
	var escena := load(ruta_escena) as PackedScene
	if escena == null:
		push_error("GestorNiveles: no se pudo cargar '%s'." % ruta_escena)
		_cargando = false
		return

	# Invalida los acks de "cliente listo" de cualquier carga anterior — ver
	# SpawnerMobs._al_peer_listo().
	_generacion_nivel += 1
	_peers_listos.clear()

	# Fundido a negro: el intercambio de escena ocurre con la pantalla
	# tapada, así que el "pop" de instanciar/reposicionar nunca se ve.
	await _fundir(1.0)

	# Recoge cualquier proyectil/número de daño que siguiera "en vuelo" del
	# nivel anterior: viven en la piscina (fuera del árbol del nivel, ver
	# GestorPiscinas) precisamente para sobrevivir a este cambio, pero no
	# tiene sentido que sigan animándose sobre un nivel que ya no existe.
	GestorPiscinas.liberar_todos_los_activos()

	for hijo in _contenedor.get_children():
		hijo.free()

	var nivel := escena.instantiate()
	_contenedor.add_child(nivel)

	if _jugador != null and nivel is NivelBase:
		var punto: Node2D = (nivel as NivelBase).punto_aparicion()
		if punto != null:
			_jugador.global_position = punto.global_position
			if _jugador is CharacterBody2D:
				(_jugador as CharacterBody2D).velocity = Vector2.ZERO
		if _jugador.has_method(&"aplicar_limites_camara"):
			_jugador.call(&"aplicar_limites_camara", (nivel as NivelBase).limites_camara())
		if _jugador.has_method(&"resetear_camara"):
			_jugador.call(&"resetear_camara")

	_gracia = GRACIA_TRAS_CARGA
	_cargando = false
	if nivel is NivelBase:
		nivel_cargado.emit(nivel)
		print("Nivel cargado: %s" % (nivel as NivelBase).nombre_nivel)
		if Utils.en_red() and not multiplayer.is_server():
			rpc_id(1, "_marcar_listo_red", _generacion_nivel)

	await _fundir(0.0)


## El cliente avisa acá que ya terminó de cargar su copia del nivel actual.
## reliable: es un aviso puntual (no un flujo continuo), no puede perderse.
@rpc("any_peer", "reliable")
func _marcar_listo_red(generacion: int) -> void:
	if not multiplayer.is_server():
		return
	if generacion != _generacion_nivel:
		return  # Ack de una carga vieja — el nivel ya cambió de nuevo.
	var quien := multiplayer.get_remote_sender_id()
	if not _peers_listos.has(quien):
		_peers_listos.append(quien)
		peer_listo.emit(quien)


## Anima el velo negro hacia la opacidad objetivo (1.0 = tapado, 0.0 = visible).
func _fundir(alfa_objetivo: float) -> void:
	var tween := create_tween()
	tween.tween_property(_velo, "modulate:a", alfa_objetivo, DURACION_FUNDIDO)
	await tween.finished
