extends Control
## Botón "Log" + panel desplegable con el registro de GestorLogRed — para
## diagnosticar problemas de conexión desde el celular mismo, sin cable USB
## ni logcat. Ver GestorLogRed (autoload) para de dónde salen las líneas.

@onready var _boton: Button = $BotonToggle
@onready var _panel: PanelContainer = $Panel
@onready var _scroll: ScrollContainer = $Panel/Scroll
@onready var _texto: RichTextLabel = $Panel/Scroll/Texto


func _ready() -> void:
	_panel.visible = false
	_boton.pressed.connect(_alternar)
	GestorLogRed.linea_agregada.connect(_agregar_linea)
	_texto.text = "\n".join(GestorLogRed.lineas)
	_desplazar_al_final.call_deferred()


func _alternar() -> void:
	_panel.visible = not _panel.visible
	if _panel.visible:
		_desplazar_al_final.call_deferred()


func _agregar_linea(linea: String) -> void:
	if _texto.text != "":
		_texto.text += "\n"
	_texto.text += linea
	if _panel.visible:
		_desplazar_al_final.call_deferred()


func _desplazar_al_final() -> void:
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)
