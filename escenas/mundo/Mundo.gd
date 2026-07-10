extends Node2D
## Mundo: cascarón persistente del juego (jugador + interfaz). El contenido
## jugable vive en niveles intercambiables dentro de ContenedorNivel;
## GestorNiveles se encarga de cambiarlos (los portales se lo piden).
##
## Multijugador: al arrancar, SIEMPRE intenta conectarse como cliente al
## servidor dedicado en 127.0.0.1 (ver ServidorDedicado.gd/.tscn, pensado
## para correr solo en Docker). Si no hay servidor escuchando, cae de
## vuelta al juego de un jugador de toda la vida — mismo comportamiento de
## siempre, sin pedir IP ni nada (la máquina del cliente es siempre local).

@export_file("*.tscn") var nivel_inicial := "res://escenas/niveles/NivelPradera.tscn"

const ESCENA_JUGADOR := preload("res://escenas/jugador/Jugador.tscn")
const DATOS_GOLPE_BASICO := preload("res://recursos/habilidades_ui/golpe_basico.tres")

@onready var _jugadores: Node2D = $Jugadores
@onready var _label_conexion: Label = $CanvasLayer/EstadoConexion
var _resuelto := false

const COLOR_CONECTADO := Color(0.4, 1.0, 0.4)
const COLOR_DESCONECTADO := Color(1.0, 0.4, 0.4)
const COLOR_CONECTANDO := Color(1.0, 0.9, 0.4)


func _ready() -> void:
	GestorNiveles.registrar($ContenedorNivel, null)
	_conectar_como_cliente()


func _conectar_como_cliente() -> void:
	_label_conexion.text = "Conectando a 127.0.0.1:%d..." % Utils.PUERTO_JUEGO
	_label_conexion.add_theme_color_override("font_color", COLOR_CONECTANDO)
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client("127.0.0.1", Utils.PUERTO_JUEGO)
	if error != OK:
		_arrancar_modo_local()
		return
	# OJO: asignar multiplayer_peer acá ya hace que Utils.en_red() dé true
	# (create_client() todavía no confirmó nada, solo empezó a intentarlo) —
	# por eso NADA que dependa de en_red() (cambiar_nivel, que dispara
	# SpawnerMobs) puede correr todavía. Recién se carga el nivel una vez
	# resuelta la conexión (_al_conectar_ok / _arrancar_modo_local).
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_al_conectar_ok)
	multiplayer.connection_failed.connect(_arrancar_modo_local)
	# ENet por UDP no siempre dispara "connection_failed" rápido cuando
	# sencillamente no hay nadie escuchando en el puerto — sin este
	# respaldo, jugar sin el servidor Docker corriendo se queda esperando
	# una conexión que nunca llega.
	get_tree().create_timer(2.0).timeout.connect(_arrancar_modo_local)


func _al_conectar_ok() -> void:
	if _resuelto:
		return
	_resuelto = true
	multiplayer.server_disconnected.connect(_al_perder_conexion)
	_label_conexion.text = "Conectado 127.0.0.1:%d" % Utils.PUERTO_JUEGO
	_label_conexion.add_theme_color_override("font_color", COLOR_CONECTADO)
	GestorNiveles.cambiar_nivel(nivel_inicial)
	_esperar_jugador_propio()


## El servidor se cayó a mitad de partida — el label tiene que reflejarlo
## YA, no recién cuando termine de recargar la escena (que puede tardar por
## el fundido de GestorNiveles).
func _al_perder_conexion() -> void:
	_label_conexion.text = "Desconectado"
	_label_conexion.add_theme_color_override("font_color", COLOR_DESCONECTADO)
	get_tree().reload_current_scene()


## No hay servidor en 127.0.0.1 (o se cayó la conexión): vuelve al modo de
## un solo jugador de siempre, instanciando el Jugador.tscn local a mano
## (antes era un nodo fijo en la escena — ahora que Jugadores/GeneradorJugadores
## reemplazó a ese nodo estático, hay que crearlo por código).
func _arrancar_modo_local() -> void:
	# El temporizador de respaldo (2s) puede disparar DESPUÉS de que esta
	# escena fue reemplazada (reload_current_scene al perder conexión) —
	# los SceneTree timers sobreviven al reload. Sin este corte, corría
	# sobre un Mundo ya liberado.
	if not is_inside_tree():
		return
	if _resuelto:
		return
	_resuelto = true
	if Utils.en_red():
		# null (no un OfflineMultiplayerPeer) deja a Utils.en_red() dando
		# true por error, y a multiplayer.get_unique_id() reventando.
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_label_conexion.text = "Desconectado"
	_label_conexion.add_theme_color_override("font_color", COLOR_DESCONECTADO)
	# El nivel se carga PRIMERO, completo (terreno, navegación, mobs); el
	# jugador recién se crea cuando GestorNiveles avisa que terminó — así
	# nunca existe un jugador parado sobre un mundo a medio cargar.
	GestorNiveles.nivel_cargado.connect(_crear_jugador_local, CONNECT_ONE_SHOT)
	GestorNiveles.cambiar_nivel(nivel_inicial)


func _crear_jugador_local(_nivel: NivelBase) -> void:
	if not is_inside_tree():
		return
	var jugador := ESCENA_JUGADOR.instantiate()
	jugador.name = "local"
	_jugadores.add_child(jugador)
	GestorNiveles.registrar($ContenedorNivel, jugador)
	# Colocarlo en el PuntoAparicion y aplicarle los límites de cámara del
	# nivel recién cargado (cambiar_nivel ya pasó — con _jugador en null —
	# así que hay que hacerlo "a mano", igual que en el camino de red).
	GestorNiveles.asignar_jugador(jugador)


func _esperar_jugador_propio(intentos: int = 0) -> void:
	if not Utils.en_red():
		return  # la conexión falló mientras tanto — ya se cayó a modo local.
	if not is_inside_tree():
		return  # escena recargada mientras el reintento estaba pendiente.
	var propio := _jugadores.get_node_or_null(str(multiplayer.get_unique_id()))
	if propio:
		# Si el temporizador de respaldo llegó a crear un jugador local
		# antes de que la conexión terminara de resolverse, sería un
		# segundo jugador fantasma al lado del replicado — eliminarlo.
		var local := _jugadores.get_node_or_null("local")
		if local:
			local.queue_free()
		GestorNiveles.asignar_jugador(propio)
		# Habilidad por defecto para poder probar combate ya mismo — el
		# servidor equipa la misma en su copia de este jugador (ver
		# ServidorDedicado.gd); ambos lados necesitan el mismo nodo hijo en
		# el mismo path para que el RPC de HabilidadBase._activar_red
		# encuentre el nodo correcto.
		var slots = propio.get_node("SlotHabilidades")
		slots.equipar(0, DATOS_GOLPE_BASICO)
		# Recuperar el progreso guardado EN EL SERVIDOR (si existe): posición,
		# vida, XP, inventario, equipo y habilidades (estas últimas pisan el
		# golpe_basico por defecto de arriba, que queda solo para cuentas
		# nuevas). Si el servidor no tiene partida de este jugador, no
		# responde nada y se arranca de cero.
		GestorGuardado.cargar_partida()
		return
	# ~10s de reintento: el servidor ya no spawnea al conectar, sino recién
	# cuando este cliente confirma que cargó el nivel (más el respaldo de 5s
	# del servidor) — el margen viejo de 5s quedaba justo.
	if intentos > 600:
		return
	get_tree().create_timer(1.0 / 60.0).timeout.connect(_esperar_jugador_propio.bind(intentos + 1))
