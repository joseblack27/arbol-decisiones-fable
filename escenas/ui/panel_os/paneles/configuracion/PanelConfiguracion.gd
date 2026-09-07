extends Control
class_name PanelConfiguracion
## Pestaña "Configuración" del OS. Todo lo que se muestra acá está conectado
## a algo real: no hay opciones decorativas.
##
## Las preferencias viven en Utils y se guardan con Utils.guardar_config()
## (mismo archivo y mismas claves que usa MenuInicio: user://config_conexion
## .cfg). Antes esa persistencia era privada de MenuInicio, que se libera al
## entrar al juego — se movió al autoload justamente para que este panel
## pueda reusarla en vez de duplicar la lista de claves.

## Se relee al abrirse (mismo patrón que PanelTablero): los valores pueden
## haber cambiado desde otro lado mientras el panel estaba oculto.
@onready var _casilla_depuracion: CheckBox = %CasillaDepuracion
@onready var _tabs: TabContainer = %Tabs
@onready var _btn_interfaz: Button = %BtnInterfaz
@onready var _btn_audio: Button = %BtnAudio
@onready var _btn_partida: Button = %BtnPartida
@onready var _btn_cuenta: Button = %BtnCuenta
@onready var _slider_volumen_sfx: HSlider = %SliderVolumenSfx
@onready var _slider_volumen_musica: HSlider = %SliderVolumenMusica
@onready var _boton_guardar: Button = %BotonGuardarPartida
@onready var _boton_cargar: Button = %BotonCargarPartida
@onready var _campo_nombre: LineEdit = %CampoNombre
@onready var _campo_pin: LineEdit = %CampoPin
@onready var _boton_aplicar_cuenta: Button = %BotonAplicarCuenta
@onready var _valor_servidor: Label = %ValorServidor
@onready var _boton_cerrar_sesion: Button = %BotonCerrarSesion
@onready var _aviso: Label = %Aviso


func _ready() -> void:
	# Barra de categorías propia (Interfaz/Audio/Partida/Cuenta), mismo
	# patrón que OsPrincipal.set_active_topbar_button: TabContainer con
	# tabs_visible=false (la barra nativa no respeta el tema del resto del
	# OS) + botones toggle_mode que se deshabilitan mientras están activos,
	# para que no se puedan des-togglear a mano.
	_btn_interfaz.pressed.connect(_cambiar_tab.bind(0, _btn_interfaz))
	_btn_audio.pressed.connect(_cambiar_tab.bind(1, _btn_audio))
	_btn_partida.pressed.connect(_cambiar_tab.bind(2, _btn_partida))
	_btn_cuenta.pressed.connect(_cambiar_tab.bind(3, _btn_cuenta))
	_cambiar_tab(0, _btn_interfaz)

	_casilla_depuracion.toggled.connect(_al_cambiar_depuracion)
	_slider_volumen_sfx.value_changed.connect(_al_cambiar_volumen_sfx)
	_slider_volumen_sfx.drag_ended.connect(_al_soltar_volumen_sfx)
	_slider_volumen_musica.value_changed.connect(_al_cambiar_volumen_musica)
	_slider_volumen_musica.drag_ended.connect(_al_soltar_volumen_musica)
	_boton_guardar.pressed.connect(_al_guardar_partida)
	_boton_cargar.pressed.connect(_al_cargar_partida)
	_boton_aplicar_cuenta.pressed.connect(_al_aplicar_cuenta)
	_boton_cerrar_sesion.pressed.connect(_al_cerrar_sesion)
	visibility_changed.connect(_al_cambiar_visibilidad)
	_refrescar()


func _cambiar_tab(indice: int, boton: Button) -> void:
	_tabs.current_tab = indice
	for otro in [_btn_interfaz, _btn_audio, _btn_partida, _btn_cuenta]:
		otro.button_pressed = false
		otro.disabled = false
	boton.button_pressed = true
	boton.disabled = true


func _al_cambiar_visibilidad() -> void:
	if visible:
		_refrescar()


func _refrescar() -> void:
	_casilla_depuracion.button_pressed = Utils.mostrar_depuracion
	_slider_volumen_sfx.value = Utils.volumen_sfx
	_slider_volumen_musica.value = Utils.volumen_musica
	_campo_nombre.text = Utils.nombre_conexion if Utils.nombre_conexion != "" else Utils.nombre_jugador_local()
	_campo_pin.text = Utils.pin_conexion
	_valor_servidor.text = "%s:%d" % [Utils.ip_conexion, Utils.puerto_conexion]
	_aviso.text = ""


## A diferencia de la casilla de MenuInicio (que solo deja el valor listo
## para la próxima partida), acá se aplica EN VIVO: el jugador ya está
## adentro y espera ver el cambio al instante, no al reconectar.
func _al_cambiar_depuracion(activado: bool) -> void:
	Utils.mostrar_depuracion = activado
	Utils.guardar_config()
	var mundo := _buscar_mundo()
	if mundo and mundo.has_method("_aplicar_visibilidad_depuracion"):
		mundo.call("_aplicar_visibilidad_depuracion")
	_avisar("Datos de desarrollo %s." % ("activados" if activado else "ocultados"))


## Se escucha EN VIVO (GestorSonido.aplicar_volumen vuelca esto al bus "SFX"
## de una) mientras se arrastra, pero recién se guarda a disco al soltar
## (ver _al_soltar_volumen_sfx) — value_changed dispara en cada pixel del
## arrastre, y escribir el .cfg esa cantidad de veces por segundo sería el
## mismo tipo de tirón que ya se evitó en otros lados con pools/diferido.
func _al_cambiar_volumen_sfx(valor: float) -> void:
	Utils.volumen_sfx = valor
	GestorSonido.aplicar_volumen()


func _al_soltar_volumen_sfx(_valor_cambio: bool) -> void:
	Utils.guardar_config()


## Mismo criterio que _al_cambiar_volumen_sfx — ver ese comentario.
func _al_cambiar_volumen_musica(valor: float) -> void:
	Utils.volumen_musica = valor
	GestorMusica.aplicar_volumen()


func _al_soltar_volumen_musica(_valor_cambio: bool) -> void:
	Utils.guardar_config()


## Mundo.gd es quien muestra/oculta los contadores (ver
## _aplicar_visibilidad_depuracion). Se busca por nombre igual que hace
## BotonOS para encontrar el OS: este panel vive dentro de Mundo.tscn, pero
## a varios niveles de profundidad, y no conviene cablear una ruta fija.
func _buscar_mundo() -> Node:
	return get_tree().get_root().find_child("Mundo", true, false)


func _al_guardar_partida() -> void:
	GestorGuardado.guardar_partida()
	_avisar("Partida guardada.")


func _al_cargar_partida() -> void:
	GestorGuardado.cargar_partida()
	_avisar("Partida cargada.")


## Nombre y PIN identifican la cuenta CONTRA EL SERVIDOR, y eso se negocia
## una sola vez al conectar (ver Jugador._registrar_identidad_red): cambiarlos
## en caliente no tendría efecto y daría la falsa impresión de que sí. Se
## guardan para la próxima conexión y se avisa con todas las letras.
func _al_aplicar_cuenta() -> void:
	var nombre := _campo_nombre.text.strip_edges().substr(0, 24)
	var pin := _campo_pin.text.strip_edges()
	if pin != "" and nombre == "":
		_avisar("Para usar PIN, escribí también un nombre.", true)
		return
	Utils.nombre_conexion = nombre
	Utils.pin_conexion = pin
	Utils.guardar_config()
	_avisar("Guardado. Se aplica la próxima vez que te conectes.")


func _avisar(texto: String, es_error: bool = false) -> void:
	_aviso.text = texto
	_aviso.add_theme_color_override(
		"font_color", Color(1, 0.4, 0.4) if es_error else Color(0.55, 0.85, 0.55))


## Cerrar sesión lo resuelve Mundo (ver Mundo.cerrar_sesion): cerrar el peer
## desde acá dispararía el manejo de "se cayó el servidor", que recarga la
## escena para reconectar — exactamente lo contrario de lo que se pidió.
func _al_cerrar_sesion() -> void:
	var mundo := _buscar_mundo()
	if mundo and mundo.has_method("cerrar_sesion"):
		mundo.call("cerrar_sesion")
	else:
		_avisar("No se pudo cerrar la sesión.", true)
