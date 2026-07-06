@abstract
extends Button
class_name ButtonListItem

signal button_clicked(data_resource: Resource)

@onready var labels: Array[Label]

@export var resource: Resource

var _original_stylebox: StyleBoxFlat
var _pressed_stylebox: StyleBoxFlat
var presionado: bool = false

func _ready():
	toggled.connect(_on_toggled)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	mouse_exited.connect(_on_mouse_exited)
	
	_pressed_stylebox = StyleBoxFlat.new()
	_pressed_stylebox.bg_color = Color.WHITE
	_pressed_stylebox.set_border_width_all(1)
	_pressed_stylebox.border_color = Color(0,0,0)
	
	_original_stylebox = StyleBoxFlat.new()
	_original_stylebox.bg_color = Color.BLACK
	_original_stylebox.set_border_width_all(1)
	_original_stylebox.border_color = Color(0.267, 0.267, 0.267)
	
	label_font_white()
	background_black()

#region Eventos

func _on_toggled(_pressed: bool) -> void:
	if _pressed:
		label_font_black()
		background_white()
		button_clicked.emit(resource)
	else:
		label_font_white()
		background_black()

func _on_button_down():
	presionado = true
	if button_pressed == true:
		label_font_black()
		background_white()
	else:
		label_font_white()
		background_black()

func _on_button_up():
	if presionado == true:
		label_font_black()
		background_white()
		presionado = false

func _on_mouse_exited():
	if presionado == true:
		if button_pressed == true:
			label_font_black()
			background_white()
		else:
			label_font_white()
			background_black()
		presionado = false

#endregion

#region Funciones

func label_font_black():
	for label in labels:
		label.add_theme_color_override("font_color", Color.BLACK)

func label_font_white():
	for label in labels:
		label.add_theme_color_override("font_color", Color.WHITE)

func background_white():
	add_theme_stylebox_override("pressed", _pressed_stylebox)
	add_theme_stylebox_override("focus", _pressed_stylebox)

func background_black():
	add_theme_stylebox_override("pressed", _original_stylebox)
	add_theme_stylebox_override("focus", _original_stylebox)

#endregion
