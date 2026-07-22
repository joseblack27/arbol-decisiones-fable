extends Node2D
## Mundo: cascarón persistente del juego (jugador + interfaz). El contenido
## jugable vive en niveles intercambiables dentro de ContenedorNivel;
## GestorNiveles se encarga de cambiarlos (los portales se lo piden).
##
## Multijugador: al arrancar, SIEMPRE intenta conectarse como cliente a la
## IP/puerto elegidos en MenuInicio.tscn (pantalla previa, ver Utils.
## ip_conexion/puerto_conexion). Este juego es multijugador puro — si el
## servidor no responde (falla create_client, ENet avisa connection_failed,
## o pasan 2s sin respuesta) NO cae a un modo un jugador: reintenta solo,
## sin límite, hasta conectar (ver _programar_reintento).

@export_file("*.tscn") var nivel_inicial := "res://escenas/niveles/NivelPradera.tscn"

const DATOS_GOLPE_BASICO := preload("res://recursos/habilidades/golpe_basico.tres")
const RETARDO_REINTENTO := 2.0

@onready var _jugadores: Node2D = $Jugadores
@onready var _label_conexion: Label = $CanvasLayer/EstadoConexion
var _resuelto := false
var _intento := 0

const COLOR_CONECTADO := Color(0.4, 1.0, 0.4)
const COLOR_DESCONECTADO := Color(1.0, 0.4, 0.4)
const COLOR_CONECTANDO := Color(1.0, 0.9, 0.4)


func _ready() -> void:
	GestorNiveles.registrar($ContenedorNivel, null)
	if Utils.modo_local_pruebas:
		_arrancar_modo_prueba_local()
		return
	# Conectadas UNA sola vez acá (no en cada intento): multiplayer es el
	# mismo SceneMultiplayer durante toda la vida del nodo, así que
	# reconectar estas señales en cada reintento las iría apilando y cada
	# fallo terminaría llamando al handler N veces.
	multiplayer.connected_to_server.connect(_al_conectar_ok)
	multiplayer.connection_failed.connect(_al_fallar_conexion)
	_conectar_como_cliente()


## SOLO pruebas (Utils.modo_local_pruebas): jugador local determinista sin
## red — el juego real jamás pasa por acá (reintenta conectarse para
## siempre, ver _programar_reintento). Reproduce el viejo "modo un jugador":
## nivel primero, jugador "local" recién cuando el nivel terminó de cargar.
func _arrancar_modo_prueba_local() -> void:
	_resuelto = true
	_label_conexion.text = "Prueba local"
	GestorNiveles.nivel_cargado.connect(_crear_jugador_prueba_local, CONNECT_ONE_SHOT)
	GestorNiveles.cambiar_nivel(nivel_inicial)


func _crear_jugador_prueba_local(_nivel: NivelBase) -> void:
	if not is_inside_tree():
		return
	var jugador := (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	jugador.name = "local"
	_jugadores.add_child(jugador)
	GestorNiveles.registrar($ContenedorNivel, jugador)
	GestorNiveles.asignar_jugador(jugador)


func _conectar_como_cliente() -> void:
	_intento += 1
	GestorLogRed.registrar("Intentando conectar a %s:%d (intento %d)" % [Utils.ip_conexion, Utils.puerto_conexion, _intento])
	_label_conexion.text = "Conectando a %s:%d... (intento %d)" % [Utils.ip_conexion, Utils.puerto_conexion, _intento]
	_label_conexion.add_theme_color_override("font_color", COLOR_CONECTANDO)
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(Utils.ip_conexion, Utils.puerto_conexion)
	GestorLogRed.registrar("create_client() devolvió código %d (0 = OK)" % error)
	if error != OK:
		GestorLogRed.registrar("create_client() falló de entrada -> reintentando")
		_programar_reintento()
		return
	# OJO: asignar multiplayer_peer acá ya hace que Utils.en_red() dé true
	# (create_client() todavía no confirmó nada, solo empezó a intentarlo) —
	# por eso NADA que dependa de en_red() (cambiar_nivel, que dispara
	# SpawnerMobs) puede correr todavía. Recién se carga el nivel una vez
	# resuelta la conexión (_al_conectar_ok).
	multiplayer.multiplayer_peer = peer
	# ENet por UDP no siempre dispara "connection_failed" rápido cuando
	# sencillamente no hay nadie escuchando en el puerto — sin este
	# respaldo, un servidor caído se queda esperando una conexión que nunca
	# llega. Se liga al número de intento actual para que el timer de un
	# intento viejo no dispare un reintento de más si ya se resolvió (éxito
	# u otro intento en curso).
	get_tree().create_timer(2.0).timeout.connect(_al_vencer_timeout.bind(_intento))


func _al_fallar_conexion() -> void:
	if _resuelto:
		return
	GestorLogRed.registrar("ENet avisó connection_failed -> reintentando")
	_programar_reintento()


func _al_vencer_timeout(intento_del_timer: int) -> void:
	if _resuelto or intento_del_timer != _intento:
		return
	GestorLogRed.registrar("Pasaron 2s sin respuesta del servidor -> reintentando")
	_programar_reintento()


## Espera un poco y reintenta — nunca se rinde ni cae a un modo sin
## servidor: este juego es multijugador puro (ver comentario de arriba).
func _programar_reintento() -> void:
	if _resuelto or not is_inside_tree():
		return
	_label_conexion.text = "Sin respuesta, reintentando..."
	_label_conexion.add_theme_color_override("font_color", COLOR_DESCONECTADO)
	get_tree().create_timer(RETARDO_REINTENTO).timeout.connect(_conectar_como_cliente)


func _al_conectar_ok() -> void:
	GestorLogRed.registrar("¡Conectado! El servidor respondió y aceptó la conexión.")
	if _resuelto:
		return
	_resuelto = true
	multiplayer.server_disconnected.connect(_al_perder_conexion)
	_label_conexion.text = "Conectado %s:%d" % [Utils.ip_conexion, Utils.puerto_conexion]
	_label_conexion.add_theme_color_override("font_color", COLOR_CONECTADO)
	GestorNiveles.cambiar_nivel(nivel_inicial)
	_esperar_jugador_propio()


## El servidor se cayó a mitad de partida — el label tiene que reflejarlo
## YA, no recién cuando termine de recargar la escena (que puede tardar por
## el fundido de GestorNiveles). reload_current_scene reinicia Mundo desde
## cero, así que _ready() vuelve a arrancar el ciclo de reintentos.
##
## EXCEPCIÓN: si el servidor cortó la conexión porque rechazó la cuenta (PIN
## incorrecto — ver Jugador._rechazar_cuenta_red, que anota Utils.
## error_conexion justo antes de que esto dispare), reintentar sin más no
## sirve — se reconectaría con el MISMO PIN malo para siempre, sin que el
## jugador se enterara nunca de por qué. En ese caso, en vez de reintentar,
## se vuelve al menú para que pueda corregirlo.
func _al_perder_conexion() -> void:
	if Utils.error_conexion != "":
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		get_tree().change_scene_to_file("res://escenas/menu_inicio/MenuInicio.tscn")
		return
	_label_conexion.text = "Desconectado"
	_label_conexion.add_theme_color_override("font_color", COLOR_DESCONECTADO)
	get_tree().reload_current_scene()


func _esperar_jugador_propio(intentos: int = 0) -> void:
	if not is_inside_tree():
		return  # escena recargada mientras el reintento estaba pendiente.
	var propio := _jugadores.get_node_or_null(str(multiplayer.get_unique_id()))
	if propio:
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
