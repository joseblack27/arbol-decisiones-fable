class_name HabilidadGolpeVampirico
extends HabilidadBase
## Golpe cuerpo a cuerpo en área alrededor de quien la usa — mismo AoE que
## GolpeBasico/OndaChoque (antes golpeaba solo al enemigo más cercano dentro
## de un alcance; cambiado por pedido del usuario a "que se lance encima del
## jugador con un radio, como golpe básico"), conservando la ventaja de
## curar un % del daño infligido (ver GolpeVampirico._aplicar_daño).

## Sobreescrito por DatosHabilidad.aplicar_datos() SOLO si dano_base_min/max
## son > 0 ahí (ver _calcular_dano en HabilidadBase).
var daño: float = 12.0
## Radio del área — configurable manualmente (sin equivalente en DatosHabilidad).
@export var radio_golpe: float = 60.0
## 0.5 = cura la mitad del daño infligido (sumado entre todos los golpeados).
@export_range(0.0, 1.0, 0.05) var porcentaje_robo: float = 0.5
@export var escena_golpe: PackedScene = preload("res://escenas/habilidades/golpe_vampirico/GolpeVampirico.tscn")


func _ready() -> void:
	super._ready()
	nombre_habilidad = "Golpe Vampírico"
	tipo_habilidad   = "golpe_vampirico"
	requiere_direccion = false


func aplicar_datos(d: DatosHabilidad) -> void:
	super.aplicar_datos(d)
	if d.radio_golpe > 0.0:
		radio_golpe = d.radio_golpe


func _ejecutar(_direccion: Vector2, _poder: float) -> void:
	if not is_instance_valid(entidad_dueña):
		return
	var golpe := GestorPiscinas.obtener(escena_golpe) as GolpeVampirico
	golpe.global_position  = entidad_dueña.global_position
	golpe.radio_base       = radio_golpe
	golpe.porcentaje_robo  = porcentaje_robo
	golpe.configurar(_calcular_dano(int(daño)), entidad_dueña, tipo_dano)
