extends Resource
class_name DatosItem

@export var name: String = ""
@export var icon: Texture2D
@export var quantity: int = 1

@export var description: String = ""

# 0=NONE,1=ALL,2=CONSUMABLE,3=EQUIPPABLE,4=RESOURCE,5=QUEST,6=WEAPON
@export var type: int = 0:
	set(value):
		type = value
		type_descripcion = item_description.get(value, "desconocido")

# 0=NONE,1=HELMET,2=BODY,3=PANT,4=BOOTS,5=NECK,6=RING,7=BELT,8=WEAPON,9=SHIELD
@export var type_equippable: int = 0

@export var can_use: bool = false
@export var can_equip: bool = false
@export var can_drop: bool = true

var type_descripcion: String

const item_description := {
	0: "vacio",
	1: "todos",
	2: "consumible",
	3: "equipable",
	4: "recurso",
	5: "mision",
	6: "arma"
}
