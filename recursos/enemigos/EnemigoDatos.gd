extends Resource
class_name EnemigoDatos
## Plantilla de datos para un tipo de enemigo.
## Crea un .tres por tipo y asígnalo en el Inspector de Enemigo.tscn.

@export_group("Identidad")
@export var nombre_tipo: String = "Normal"
## Color multiplicativo aplicado al Sprite2D (modulate).
@export var color: Color = Color.WHITE

@export_group("Vida")
@export var vida_maxima: float = 100.0

@export_group("Movimiento")
@export var velocidad_base: float = 150.0

@export_group("Energía")
@export var energia_maxima: float         = 80.0
@export var regeneracion_energia: float   = 10.0
