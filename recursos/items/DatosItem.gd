extends Resource
class_name DatosItem

@export var name: String = ""
@export var icon: Texture2D
@export var quantity: int = 1

@export var description: String = ""

# 0=NONE,1=ALL,2=CONSUMABLE,3=EQUIPPABLE,4=RESOURCE,5=QUEST,6=WEAPON
@export var type: Enums.Inventory.TypeItem = Enums.Inventory.TypeItem.NONE:
	set(value):
		type = value
		type_descripcion = item_description[value]

# 0=NONE,1=HELMET,2=BODY,3=PANT,4=BOOTS,5=NECK,6=RING,7=BELT,8=WEAPON,9=SHIELD
@export var type_equippable: Enums.Inventory.TypeItemEquippable = Enums.Inventory.TypeItemEquippable.NONE

@export var can_use: bool = false
@export var can_equip: bool = false
@export var can_drop: bool = true

## Vida que restaura al usarse (solo tiene efecto si can_use == true).
## 0 = sin efecto de curación.
@export var curacion: float = 0.0

## Energía que restaura al usarse (solo tiene efecto si can_use == true).
## 0 = sin efecto — ver jeringa_adrenalina.tres para el primer ítem que lo usa.
@export var energia: float = 0.0

## Bonos de atributos que aporta este ítem mientras esté equipado (solo
## tiene sentido si type == EQUIPPABLE). Reutiliza el mismo AtributosBase
## que ya usan jugador/enemigos — lo que pongas acá se SUMA a los atributos
## base de quien lo tenga puesto. Dejar vacío (null) = sin bono.
@export var bonos: AtributosBase

## Ruta del .tres original del que sale este ítem — GestorInventario SIEMPRE
## duplica el recurso al guardarlo (ver su comentario), y un Resource
## duplicado pierde su resource_path; sin este campo, GestorGuardado no
## tendría forma de saber qué archivo volver a cargar al restaurar la
## partida. Se completa solo (GestorInventario.agregar_item), no hace falta
## tocarlo a mano en los .tres.
@export var id_recurso: String = ""

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
