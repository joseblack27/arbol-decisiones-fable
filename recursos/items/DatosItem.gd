extends Resource
class_name DatosItem

@export var name: String = ""
@export var icon: Texture2D
@export var quantity: int = 1

@export var description: String = ""

# 0=NINGUNO,1=TODOS,2=CONSUMIBLE,3=EQUIPABLE,4=RECURSO,5=MISION,6=ARMA
@export var type: Enums.Inventario.TipoItem = Enums.Inventario.TipoItem.NINGUNO:
	set(value):
		type = value
		type_descripcion = item_description[value]

# 0=NINGUNO,1=CASCO,2=CUERPO,3=PANTALON,4=BOTAS,5=AMULETO,6=ANILLO,7=CINTURON,8=ARMA,9=ESCUDO
@export var type_equippable: Enums.Inventario.TipoItemEquipable = Enums.Inventario.TipoItemEquipable.NINGUNO

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
## tiene sentido si type == EQUIPABLE). Reutiliza el mismo AtributosBase
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
	Enums.Inventario.TipoItem.NINGUNO: "vacio",
	Enums.Inventario.TipoItem.TODOS: "todos",
	Enums.Inventario.TipoItem.CONSUMIBLE: "consumible",
	Enums.Inventario.TipoItem.RECURSO: "recurso",
	Enums.Inventario.TipoItem.ARMA: "arma",
	Enums.Inventario.TipoItem.MISION: "misión",
	Enums.Inventario.TipoItem.EQUIPABLE: "equipable"
}
