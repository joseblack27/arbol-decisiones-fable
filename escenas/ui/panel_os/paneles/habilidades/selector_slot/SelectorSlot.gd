extends PanelContainer
class_name SelectorSlot
## Panel flotante para seleccionar en qué slot equipar una habilidad.

signal slot_elegido(slot_index: int)
signal cancelado

@onready var _titulo:     Label         = $MarginContainer/VBoxContainer/Titulo
@onready var _btn_cancel: Button        = $MarginContainer/VBoxContainer/BtnCancelar

@onready var _botones: Array[Button] = [
	$MarginContainer/VBoxContainer/HBoxSlots/Slot0/BtnSlot0,
	$MarginContainer/VBoxContainer/HBoxSlots/Slot1/BtnSlot1,
	$MarginContainer/VBoxContainer/HBoxSlots/Slot2/BtnSlot2,
	$MarginContainer/VBoxContainer/HBoxSlots/Slot3/BtnSlot3,
]

@onready var _labels: Array[Label] = [
	$MarginContainer/VBoxContainer/HBoxSlots/Slot0/LblSlot0,
	$MarginContainer/VBoxContainer/HBoxSlots/Slot1/LblSlot1,
	$MarginContainer/VBoxContainer/HBoxSlots/Slot2/LblSlot2,
	$MarginContainer/VBoxContainer/HBoxSlots/Slot3/LblSlot3,
]


func _ready() -> void:
	_btn_cancel.pressed.connect(func(): cancelado.emit())
	for i in 4:
		_botones[i].pressed.connect(func(): slot_elegido.emit(i))


func setup(skill: DatosHabilidad, slot_habs: SlotHabilidades) -> void:
	_titulo.text = "Equipar: %s" % skill.name
	for i in 4:
		var datos := slot_habs.obtener_datos(i) if slot_habs else null
		_botones[i].icon = datos.icon if datos and datos.icon else null
		_labels[i].text  = datos.name if datos else "Vacío"
