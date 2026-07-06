extends Button

@export var filter_type: Enums.Inventory.TypeItem = Enums.Inventory.TypeItem.NONE

@export var flow_items: FlowItems # Seleccionado desde el inspector

func _ready():
	pressed.connect(_on_pressed)

func _on_pressed():
	flow_items.filter_items(filter_type)
	owner.set_active_filter_button(self)
