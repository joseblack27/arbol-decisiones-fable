extends Control
class_name RewardItemView

@onready var icon: TextureRect = $Icon
@onready var amount_label: Label = $AmountLabel

var _item: ItemData
var _amount: int

func setup(item: ItemData, amount: int):
	_item = item
	_amount = amount

	# Si ya está en el árbol, refrescamos
	if is_inside_tree():
		_refresh()

func _ready():
	_refresh()

func _refresh():
	if _item == null:
		return

	if _item.icon != null:
		icon.texture = _item.icon
		icon.visible = true
	else:
		icon.texture = null
		icon.visible = false

	amount_label.text = "x%d" % _amount
