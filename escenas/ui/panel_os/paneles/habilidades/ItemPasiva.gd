extends Button
class_name ItemPasiva
## Fila SELECCIONABLE de una pasiva ya desbloqueada (de estadística o de
## gatillo, ver PanelHabilidades._poblar_pasivas) — mismo patrón visual y
## táctil que ItemHabilidad (lista de la izquierda), pero sin nada que
## equipar: tocarla solo muestra su descripción en PanelDetallePasiva. Sin
## tooltip a propósito — pedido del usuario: "como el juego es móvil no me
## sirve la descripción como tooltip".

## pasiva_stat != null SOLO para pasivas de ESTADÍSTICA (ver
## PanelHabilidades._poblar_pasivas) — le dice a PanelDetallePasiva si
## mostrar el botón "Mejorar" (las de gatillo no tienen niveles que comprar).
signal pasiva_selected(nombre: String, descripcion: String, icono: Texture2D, pasiva_stat: PasivaStatDesbloqueo)

@onready var icono_pasiva := $MarginContainer/HBoxContainer/Control/IconoPasiva
@onready var nombre_pasiva := $MarginContainer/HBoxContainer/VBoxContainer/NombrePasiva
@onready var _fila_nivel := $MarginContainer/HBoxContainer/VBoxContainer/HBoxNivel
@onready var _contenedor_puntos: HBoxContainer = $MarginContainer/HBoxContainer/VBoxContainer/HBoxNivel/ContenedorPuntos
@onready var _etiqueta_sin_nivel: Label = $MarginContainer/HBoxContainer/VBoxContainer/HBoxNivel/EtiquetaSinNivel

## Mismo criterio que ItemHabilidad.labels: las etiquetas que invierten a
## negro sobre fondo blanco cuando la fila está seleccionada/presionada.
@onready var _labels: Array[Label] = [nombre_pasiva, _etiqueta_sin_nivel]

var _indicador_puntos: Control = null

var _nombre: String = ""
var _descripcion: String = ""
var _icono: Texture2D = null
var _pasiva_stat: PasivaStatDesbloqueo = null

var _original_stylebox: StyleBoxFlat
var _pressed_stylebox: StyleBoxFlat


func _ready() -> void:
	toggled.connect(_on_toggled)
	# Gastar un punto en esta pasiva (u otra habilidad/pasiva cualquiera)
	# cambia el nivel mostrado acá — refrescar sin esperar a que se
	# repueble la lista entera (mismo pedido que para ItemHabilidad: "las
	# habilidades activas no cambian el nivel en la lista al igual que las
	# pasivas").
	BusEventos.mejora_comprada.connect(func(_e, _t, _n): _actualizar_nivel())

	var estilos := Utils.crear_estilos_fila_seleccionable()
	_pressed_stylebox = estilos["presionado"]
	_original_stylebox = estilos["reposo"]

	_label_font_white()
	_background_black()


func set_datos(nombre: String, descripcion: String, icono: Texture2D, pasiva_stat: PasivaStatDesbloqueo = null) -> void:
	_nombre = nombre
	_descripcion = descripcion
	_icono = icono
	_pasiva_stat = pasiva_stat
	nombre_pasiva.text = nombre
	icono_pasiva.texture = icono
	_actualizar_nivel()


## Nivel de mejora comprado en ESTA pasiva de estadística, como puntos de
## progreso (ver IndicadorNivelMejora) — las de GATILLO (pasiva_stat ==
## null) no tienen niveles, así que muestran una leyenda en su lugar en
## vez de dejar la fila vacía/de otra altura (antes se escondía entera).
func _actualizar_nivel() -> void:
	var es_stat := _pasiva_stat != null
	_etiqueta_sin_nivel.visible = not es_stat
	_contenedor_puntos.visible = es_stat
	if not es_stat:
		return
	if _indicador_puntos == null:
		_indicador_puntos = IndicadorNivelMejora.new()
		_contenedor_puntos.add_child(_indicador_puntos)
	var mejoras := Utils.mejoras_componente_local()
	var tier: int = mejoras.nivel_pasiva(_pasiva_stat.resource_path) if mejoras else 0
	# Tier CRUDO, sin sumarle el nivel gratis del desbloqueo automático —
	# max_niveles es el tope de TIERS COMPRADOS (ver MejorasComponente.
	# _gastar_en_pasiva_local, que compara tier_actual >= max_niveles
	# directo), no "1 + tier" como en las habilidades activas.
	_indicador_puntos.max_tier = _pasiva_stat.max_niveles
	_indicador_puntos.tier = tier


func _on_toggled(pressed: bool) -> void:
	if pressed:
		_label_font_black()
		_background_white()
		pasiva_selected.emit(_nombre, _descripcion, _icono, _pasiva_stat)
	else:
		_label_font_white()
		_background_black()


func _label_font_black() -> void:
	Utils.colorear_labels(_labels, Color.BLACK)


func _label_font_white() -> void:
	Utils.colorear_labels(_labels, Color.WHITE)


func _background_white() -> void:
	Utils.aplicar_fondo_fila(self, _pressed_stylebox)


func _background_black() -> void:
	Utils.aplicar_fondo_fila(self, _original_stylebox)
