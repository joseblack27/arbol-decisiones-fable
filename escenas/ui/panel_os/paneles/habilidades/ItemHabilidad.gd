extends Button
class_name ItemHabilidad

signal skill_selected(skill: DatosHabilidad)

@export var skill_data: DatosHabilidad

@onready var labels: Array[Label] = [
	$MarginContainer/HBoxContainer/VBoxContainer/NombreHabilidad,
	$MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/EtiquetaSinMejora,
]

@onready var icon_skill   := $MarginContainer/HBoxContainer/Control/IconoHabilidad
@onready var name_skill   := $MarginContainer/HBoxContainer/VBoxContainer/NombreHabilidad
## Insignia "E" en cuadrado verde, del lado derecho de la fila — pedido
## del usuario: identificar de un vistazo qué habilidades están equipadas
## sin entrar a cada una. Con su propio color fijo (no entra en "labels":
## el fondo verde no cambia con la selección de la fila, así que el texto
## tampoco necesita invertirse a negro como el resto).
@onready var _insignia_equipada: Control = $MarginContainer/HBoxContainer/MarginContainer/InsigniaEquipada
@onready var _contenedor_puntos: HBoxContainer = $MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/ContenedorPuntos
@onready var _etiqueta_sin_mejora: Label = $MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/EtiquetaSinMejora

## Instancia única de IndicadorNivelMejora (ver ese script), creada la
## primera vez que hace falta y reusada después — solo se le actualiza
## tier/max_tier, sin volver a instanciar en cada refresco.
var _indicador_puntos: Control = null

var _original_stylebox: StyleBoxFlat
var _pressed_stylebox: StyleBoxFlat
var presionado: bool = false

func _ready():
	toggled.connect(_on_toggled)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	mouse_exited.connect(_on_mouse_exited)
	# Gastar un punto en CUALQUIER habilidad/pasiva cambia el nivel de
	# mejora mostrado acá — refrescar sin esperar a que se repueble la
	# lista entera (antes esta fila se quedaba siempre en el mismo número,
	# reportado por el usuario: "las habilidades activas no cambian el
	# nivel en la lista").
	BusEventos.mejora_comprada.connect(func(_e, _t, _n): _actualizar_nivel())
	# Equipar/desequipar CUALQUIER habilidad (esta u otra, si esta se movió
	# de slot) cambia si ESTA fila debe mostrarse como "equipada" — pedido
	# del usuario: "indicador de equipado en la lista", antes no había
	# forma de saber de un vistazo cuáles de las 10 estaban en uso.
	BusEventos.habilidad_equipada.connect(func(_j, _i, _h): _actualizar_equipada())

	var estilos := Utils.crear_estilos_fila_seleccionable()
	_pressed_stylebox = estilos["presionado"]
	_original_stylebox = estilos["reposo"]

	label_font_white()
	background_black()
	update_ui()

func update_ui():
	if not skill_data:
		return
	icon_skill.texture = skill_data.icon
	name_skill.text     = skill_data.name
	_actualizar_nivel()
	_actualizar_equipada()

## Nivel de MEJORA (ver MejorasComponente/HabilidadBase.aplicar_nivel_
## mejora), no el nivel de catálogo requerido para equipar. Se muestra
## como puntos de progreso (ver IndicadorNivelMejora) en vez de un
## fracción de texto — la fila SIEMPRE queda con la misma altura, con o
## sin escalado configurado (antes se escondía entera, y las filas de la
## lista quedaban de alturas distintas sin razón aparente).
func _actualizar_nivel() -> void:
	var tiene_escalado := skill_data != null and skill_data.escalado != null
	_etiqueta_sin_mejora.visible = not tiene_escalado
	_contenedor_puntos.visible = tiene_escalado
	if not tiene_escalado:
		return
	if _indicador_puntos == null:
		_indicador_puntos = IndicadorNivelMejora.new()
		_contenedor_puntos.add_child(_indicador_puntos)
	var mejoras := Utils.mejoras_componente_local()
	var tier: int = mejoras.nivel_habilidad(skill_data.resource_path) if mejoras else 0
	_indicador_puntos.max_tier = skill_data.escalado.nivel_maximo
	_indicador_puntos.tier = 1 + tier

## true si esta habilidad está equipada en CUALQUIERA de los slots del
## jugador local ahora mismo.
func _actualizar_equipada() -> void:
	var equipada := false
	var slots := Utils.slot_habilidades_local()
	if slots and skill_data:
		for i in slots.total_slots:
			var datos: DatosHabilidad = slots.obtener_datos(i)
			if datos and datos.resource_path == skill_data.resource_path:
				equipada = true
				break
	_insignia_equipada.visible = equipada

func _on_toggled(_pressed: bool) -> void:
	if _pressed:
		label_font_black()
		background_white()
		skill_selected.emit(skill_data)
	else:
		label_font_white()
		background_black()

func _on_button_down():
	presionado = true
	if button_pressed:
		label_font_black()
		background_white()
	else:
		label_font_white()
		background_black()

func _on_button_up():
	if presionado:
		label_font_black()
		background_white()
		presionado = false

func _on_mouse_exited():
	if presionado:
		if button_pressed:
			label_font_black()
			background_white()
		else:
			label_font_white()
			background_black()
		presionado = false

func label_font_black():
	Utils.colorear_labels(labels, Color.BLACK)

func label_font_white():
	Utils.colorear_labels(labels, Color.WHITE)

func background_white():
	Utils.aplicar_fondo_fila(self, _pressed_stylebox)

func background_black():
	Utils.aplicar_fondo_fila(self, _original_stylebox)
