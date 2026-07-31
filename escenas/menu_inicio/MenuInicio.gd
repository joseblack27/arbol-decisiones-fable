extends Control
class_name MenuInicio
## Pantalla previa a Mundo.tscn (ver run/main_scene en project.godot):
## define IP, puerto y nombre a usar para la conexión. Guarda la elección en
## Utils.ip_conexion/puerto_conexion/nombre_conexion — que sobreviven el
## cambio de escena porque viven en un autoload — y recién ahí carga
## Mundo.tscn, que los lee en _conectar_como_cliente()/nombre_jugador_local().
##
## No hace falta "botón de un jugador" aparte: dejar la IP en blanco (o que
## no haya nadie escuchando ahí) hace que Mundo.gd caiga solo al modo local
## de siempre, ver su propio _arrancar_modo_local().
##
## Persistencia (user://config_conexion.cfg): Utils.ip_conexion/puerto_
## conexion/nombre_conexion son variables de autoload — sobreviven el
## change_scene_to_file hacia Mundo.tscn, pero NO sobreviven cerrar la app
## (memoria del proceso). Sin esto, cada apertura tocaba reescribir IP/
## puerto/nombre desde cero (reportado: "cada vez que conecto me toca
## configurar todo"). Se guarda solo al confirmar "Jugar" — nunca mientras
## el usuario todavía está escribiendo.

@onready var _campo_ip: LineEdit      = %CampoIp
@onready var _campo_puerto: LineEdit  = %CampoPuerto
@onready var _campo_nombre: LineEdit  = %CampoNombre
@onready var _campo_pin: LineEdit     = %CampoPin
@onready var _boton_jugar: Button     = %BotonJugar
@onready var _etiqueta_error: Label   = %EtiquetaError
@onready var _titulo: Label           = %Titulo
@onready var _version: Label          = %Version


func _ready() -> void:
	# Título y versión salen de los Ajustes del Proyecto (application/config)
	# en vez de estar escritos a mano en la escena: así se cambian en UN solo
	# lugar y no quedan dos nombres distintos conviviendo.
	var nombre_juego := String(ProjectSettings.get_setting("application/config/name", ""))
	if nombre_juego != "":
		_titulo.text = nombre_juego.to_upper()
	var version_juego := String(ProjectSettings.get_setting("application/config/version", ""))
	_version.text = "v%s" % version_juego if version_juego != "" else ""

	Utils.cargar_config()
	_campo_ip.text     = Utils.ip_conexion
	_campo_puerto.text = str(Utils.puerto_conexion)
	_campo_nombre.text = Utils.nombre_conexion if Utils.nombre_conexion != "" else Utils.nombre_jugador_local()
	_campo_nombre.max_length = 24
	_campo_pin.text    = Utils.pin_conexion

	# Rechazo de la conexión anterior (PIN incorrecto — ver
	# Jugador._rechazar_cuenta_red): mostrarlo acá y limpiarlo, para que el
	# jugador entienda por qué volvió al menú.
	if Utils.error_conexion != "":
		_etiqueta_error.text = Utils.error_conexion
		_etiqueta_error.visible = true
		Utils.error_conexion = ""

	_boton_jugar.pressed.connect(_on_jugar)
	# Enter en cualquier campo confirma igual que tocar el botón — no hace
	# falta ir a buscarlo a propósito en pantallas táctiles chicas.
	_campo_ip.text_submitted.connect(func(_t): _on_jugar())
	_campo_puerto.text_submitted.connect(func(_t): _on_jugar())
	_campo_nombre.text_submitted.connect(func(_t): _on_jugar())
	_campo_pin.text_submitted.connect(func(_t): _on_jugar())


func _on_jugar() -> void:
	var puerto_texto := _campo_puerto.text.strip_edges()
	if not puerto_texto.is_valid_int() or int(puerto_texto) <= 0 or int(puerto_texto) > 65535:
		_etiqueta_error.text = "Puerto inválido (1-65535)."
		_etiqueta_error.visible = true
		return
	_etiqueta_error.visible = false

	var ip := _campo_ip.text.strip_edges()
	Utils.ip_conexion = ip if ip != "" else "127.0.0.1"
	Utils.puerto_conexion = int(puerto_texto)
	Utils.nombre_conexion = _campo_nombre.text.strip_edges().substr(0, 24)
	Utils.pin_conexion = _campo_pin.text.strip_edges()
	if Utils.pin_conexion != "" and Utils.nombre_conexion == "":
		_etiqueta_error.text = "Para usar PIN, escribí también un nombre."
		_etiqueta_error.visible = true
		return
	Utils.guardar_config()

	get_tree().change_scene_to_file("res://escenas/mundo/Mundo.tscn")
