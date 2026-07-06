extends Button

## 0=NONE,1=ALL,2=CONSUMABLE,3=EQUIPPABLE,4=RESOURCE,5=QUEST,6=WEAPON
@export var filter_type: int = 0

@export var flow_items: FlujoItems

func _ready():
	pressed.connect(_on_pressed)

func _on_pressed():
	flow_items.filter_items(filter_type)
	owner.set_active_filter_button(self)
