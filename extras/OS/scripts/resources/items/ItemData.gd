extends Resource
class_name ItemData

@export var name: String = ""
@export var icon: Texture2D
@export var quantity: int = 1

# Opcional para más adelante
@export var description: String = ""
@export var type: Enums.Inventory.TypeItem = Enums.Inventory.TypeItem.NONE:
	set(value):
		type = value
		type_descripcion = item_description[value]
@export var type_equippable: Enums.Inventory.TypeItemEquippable = Enums.Inventory.TypeItemEquippable.NONE

@export var can_use: bool = false
@export var can_equip: bool = false
@export var can_drop: bool = true

var type_descripcion: String

const item_description := {
	Enums.Inventory.TypeItem.NONE: "vacio",
	Enums.Inventory.TypeItem.ALL: "todos",
	Enums.Inventory.TypeItem.CONSUMABLE: "consumible",
	Enums.Inventory.TypeItem.RESOURCE: "recurso",
	Enums.Inventory.TypeItem.WEAPON: "arma",
	Enums.Inventory.TypeItem.QUEST: "misión",
	Enums.Inventory.TypeItem.EQUIPPABLE: "equipable"
}
