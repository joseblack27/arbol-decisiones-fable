extends PanelContainer
class_name SelectorSlot
## Panel flotante para seleccionar en qué slot equipar una habilidad.
## Los botones se generan en RUNTIME según SlotHabilidades.total_slots — a
## diferencia de la versión vieja (4 nodos Slot0..Slot3 fijos en el .tscn),
## así este panel no necesita tocarse cada vez que total_slots cambie.

signal slot_elegido(slot_index: int)
signal cancelado

## Coincide con PaginadorHabilidades.POR_PAGINA solo por prolijidad visual
## (una fila por página) — no hay ninguna dependencia funcional real, este
## panel muestra TODOS los slots a la vez, sin paginar (hay espacio de
## sobra al ser un panel modal, a diferencia del HUD).
const COLUMNAS := 5

@onready var _titulo:     Label         = $MarginContainer/VBoxContainer/Titulo
@onready var _btn_cancel: Button        = $MarginContainer/VBoxContainer/BtnCancelar
@onready var _grid:       GridContainer = $MarginContainer/VBoxContainer/GridSlots

var _botones: Array[Button] = []
var _labels: Array[Label] = []


func _ready() -> void:
	_btn_cancel.pressed.connect(func(): cancelado.emit())
	_grid.columns = COLUMNAS


func setup(skill: DatosHabilidad, slot_habs: SlotHabilidades) -> void:
	_titulo.text = "Equipar: %s" % skill.name
	_reconstruir_grid(slot_habs.total_slots if slot_habs else 0)
	for i in _botones.size():
		var datos := slot_habs.obtener_datos(i) if slot_habs else null
		_botones[i].icon = datos.icon if datos and datos.icon else null
		_labels[i].text  = datos.name if datos else "Vacío"


## Arma un botón + etiqueta por slot desde cero cada vez que se abre — este
## panel no vive permanentemente en pantalla (se instancia al tocar
## "Equipar"), así que no hace falta optimizar reutilizando nodos viejos.
func _reconstruir_grid(cantidad: int) -> void:
	for hijo in _grid.get_children():
		hijo.queue_free()
	_botones.clear()
	_labels.clear()

	for i in cantidad:
		var columna := VBoxContainer.new()
		columna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columna.add_theme_constant_override("separation", 4)

		var boton := Button.new()
		boton.custom_minimum_size = Vector2(56, 56)
		boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		boton.expand_icon = true
		boton.pressed.connect(_on_boton_presionado.bind(i))
		columna.add_child(boton)

		var etiqueta := Label.new()
		etiqueta.custom_minimum_size = Vector2(0, 10)
		etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		etiqueta.add_theme_font_size_override("font_size", 10)
		etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		columna.add_child(etiqueta)

		_grid.add_child(columna)
		_botones.append(boton)
		_labels.append(etiqueta)


func _on_boton_presionado(slot_index: int) -> void:
	slot_elegido.emit(slot_index)
