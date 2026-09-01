extends Resource
class_name DatosItem

@export var name: String = ""
@export var icon: Texture2D
@export var quantity: int = 1

## Base para vender este ítem de vuelta a un comerciante (ver TiendaComponente
## .vender_item, PORCENTAJE_VENTA) — NO es el precio de compra, eso lo define
## cada NPC por separado en su propio DatosTienda/ItemTienda.precio. 0 = no se
## le puede vender a ningún comerciante (ítems de misión, por ejemplo).
@export var valor: int = 0

@export var description: String = ""

# 0=NINGUNO,1=TODOS,2=CONSUMIBLE,3=EQUIPABLE,4=RECURSO,5=MISION,6=ARMA
@export var type: Enums.Inventario.TipoItem = Enums.Inventario.TipoItem.NINGUNO

# 0=NINGUNO,1=CASCO,2=CUERPO,3=PANTALON,4=BOTAS,5=AMULETO,6=ANILLO,7=CINTURON,8=ARMA,9=ESCUDO
@export var type_equippable: Enums.Inventario.TipoItemEquipable = Enums.Inventario.TipoItemEquipable.NINGUNO:
	set(value):
		type_equippable = value
		type_equippable_descripcion = type_equippable_description[value]

@export var can_use: bool = false
@export var can_equip: bool = false
@export var can_drop: bool = true

## Vida que restaura al usarse (solo tiene efecto si can_use == true).
## 0 = sin efecto de curación.
@export var curacion: float = 0.0

## Energía que restaura al usarse (solo tiene efecto si can_use == true).
## 0 = sin efecto — ver jeringa_adrenalina.tres para el primer ítem que lo usa.
@export var energia: float = 0.0

## XP que otorga al usarse (solo tiene efecto si can_use == true). 0 = sin
## efecto — ver ticket_1.tres..ticket_4.tres, los primeros ítems que lo usan.
@export var experiencia: int = 0

## Bonos de atributos que aporta este ítem mientras esté equipado (solo
## tiene sentido si type == EQUIPABLE). Reutiliza el mismo AtributosBase
## que ya usan jugador/enemigos — lo que pongas acá se SUMA a los atributos
## base de quien lo tenga puesto. Dejar vacío (null) = sin bono.
@export var bonos: AtributosBase

## Conjunto de equipo al que pertenece esta pieza (ver ConjuntoDatos) — null
## = no pertenece a ningún conjunto. Varias piezas distintas deben apuntar
## a la MISMA instancia de .tres para contar como parte del mismo conjunto
## (AtributosComponente las agrupa por igualdad de este recurso).
@export var conjunto: ConjuntoDatos

## Escena de PasivaBase que este ítem desbloquea al usarse (solo tiene
## sentido si type == PASIVA y can_use == true) — ver InventarioComponente
## .usar_item()/PasivasComponente.desbloquear_gatillo(). null = sin efecto.
@export var escena_pasiva: PackedScene

## Ruta del .tres original del que sale este ítem — GestorInventario SIEMPRE
## duplica el recurso al guardarlo (ver su comentario), y un Resource
## duplicado pierde su resource_path; sin este campo, GestorGuardado no
## tendría forma de saber qué archivo volver a cargar al restaurar la
## partida. Se completa solo (GestorInventario.agregar_item), no hace falta
## tocarlo a mano en los .tres.
@export var id_recurso: String = ""

## Calculada (no cacheada en set()): el orden en que un .tres asigna sus
## propiedades no está garantizado (type podría llegar antes que
## type_equippable), así que cachear en el setter de "type" podía quedarse
## con type_equippable todavía en NINGUNO. Pedido del usuario: "cuando el
## tipo es equipable, mostrar el TipoItemEquipable en lugar de 'equipable'"
## — item.type_descripcion (usado por PanelCofre/PanelInventario en la
## fila "Tipo:") ahora resuelve el slot real (casco, anillo, arma...) para
## los ítems equipables, y el texto genérico para el resto.
var type_descripcion: String:
	get:
		if type == Enums.Inventario.TipoItem.EQUIPABLE:
			return type_equippable_description[type_equippable]
		return item_description[type]

var type_equippable_descripcion: String

const item_description := {
	Enums.Inventario.TipoItem.NINGUNO: "vacio",
	Enums.Inventario.TipoItem.TODOS: "todos",
	Enums.Inventario.TipoItem.CONSUMIBLE: "consumible",
	Enums.Inventario.TipoItem.RECURSO: "recurso",
	Enums.Inventario.TipoItem.ARMA: "arma",
	Enums.Inventario.TipoItem.MISION: "misión",
	Enums.Inventario.TipoItem.EQUIPABLE: "equipable",
	Enums.Inventario.TipoItem.PASIVA: "pasiva"
}

## Pedido del usuario para GrillaObjetos.ordenar por categoría: "la
## categoria no es que sea equipable, la categoria es el Enums.Inventario
## .TipoItemEquipable" — el slot real (casco, anillo, arma...), no el
## TipoItem genérico (que solo distingue equipable/consumible/recurso).
const type_equippable_description := {
	Enums.Inventario.TipoItemEquipable.NINGUNO: "ninguno",
	Enums.Inventario.TipoItemEquipable.CASCO: "casco",
	Enums.Inventario.TipoItemEquipable.CUERPO: "cuerpo",
	Enums.Inventario.TipoItemEquipable.PANTALON: "pantalón",
	Enums.Inventario.TipoItemEquipable.BOTAS: "botas",
	Enums.Inventario.TipoItemEquipable.AMULETO: "amuleto",
	Enums.Inventario.TipoItemEquipable.ANILLO: "anillo",
	Enums.Inventario.TipoItemEquipable.CINTURON: "cinturón",
	Enums.Inventario.TipoItemEquipable.ARMA: "arma",
	Enums.Inventario.TipoItemEquipable.ESCUDO: "escudo",
}
