extends Control
## Chat global — botón colapsado + panel desplegable (mismo patrón que
## PanelLogRed) con un LineEdit para escribir y mandar. Ver GestorChat
## (autoload) para la lógica de red/validación — este panel solo refleja
## GestorChat.historial y llama GestorChat.enviar_mensaje().

@onready var _boton: Button = $BotonToggle
@onready var _panel: PanelContainer = $Panel
@onready var _scroll: ScrollContainer = $Panel/VBox/Scroll
@onready var _texto: RichTextLabel = $Panel/VBox/Scroll/Texto
@onready var _campo: LineEdit = $Panel/VBox/Entrada/Campo
@onready var _boton_enviar: Button = $Panel/VBox/Entrada/BotonEnviar


func _ready() -> void:
	_panel.visible = false
	_boton.pressed.connect(_alternar)
	_boton_enviar.pressed.connect(_enviar)
	_campo.text_submitted.connect(func(_texto_enviado: String) -> void: _enviar())
	GestorChat.mensaje_recibido.connect(_agregar_mensaje)
	for entrada: Dictionary in GestorChat.historial:
		_agregar_mensaje(entrada.get("nombre", ""), entrada.get("texto", ""), entrada.get("es_sistema", false))


func _alternar() -> void:
	_panel.visible = not _panel.visible
	if _panel.visible:
		# Bloquea el joystick/slots de habilidad mientras el chat está
		# expandido (ver GestorUI.abrir_chat) — sin esto, tocar el cuadro de
		# texto o "Enviar" también le llegaba al joystick de atrás.
		GestorUI.abrir_chat()
		_desplazar_al_final.call_deferred()
	else:
		GestorUI.cerrar_chat()


func _enviar() -> void:
	var texto := _campo.text.strip_edges()
	if texto == "":
		return
	GestorChat.enviar_mensaje(texto)
	_campo.text = ""
	_campo.grab_focus()


func _agregar_mensaje(nombre: String, texto: String, es_sistema: bool) -> void:
	if _texto.text != "":
		_texto.text += "\n"
	var nombre_escapado := nombre.replace("[", "[lb]")
	var texto_escapado := texto.replace("[", "[lb]")
	if es_sistema:
		_texto.text += "[color=#ffd166][%s] %s[/color]" % [nombre_escapado, texto_escapado]
	else:
		_texto.text += "[b]%s:[/b] %s" % [nombre_escapado, texto_escapado]
	if _panel.visible:
		_desplazar_al_final.call_deferred()


func _desplazar_al_final() -> void:
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)
