extends Button

## 0=NINGUNO,1=TODOS,2=CONSUMIBLE,3=EQUIPABLE,4=RECURSO,5=MISION,6=ARMA
@export var filter_type: int = 0

@export var flow_items: FlujoItems

func _ready():
	pressed.connect(_on_pressed)

func _on_pressed():
	flow_items.filter_items(filter_type)
	owner.set_active_filter_button(self)
