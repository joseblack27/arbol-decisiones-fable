class_name HabilidadAreaEfecto
extends HabilidadBase
## Crea un área de efecto (AoE) circular en un punto desplazado en la dirección dada.
## poder controla qué tan lejos del centro cae el área; el radio siempre es fijo.

## Sobreescrito por DatosHabilidad.aplicar_datos() al equipar.
var daño_area: float             = 30.0
var desplazamiento_maximo: float = 120.0
## Radio del área — configurable manualmente (sin equivalente en DatosHabilidad).
@export var radio_area: float    = 80.0
@export var escena_area: PackedScene = preload("res://escenas/habilidades/area_efecto/AreaEfecto.tscn")

func _ready() -> void:
	super._ready()
	nombre_habilidad = "Área de Efecto"
	tipo_habilidad   = "area"

func aplicar_datos(d: DatosHabilidad) -> void:
	super.aplicar_datos(d)
	desplazamiento_maximo = d.alcance_metros * ESCALA_METROS_PIXEL

func _ejecutar(direccion: Vector2, poder: float) -> void:
	var efecto := escena_area.instantiate() as AreaEfecto
	var desplazamiento := Vector2.ZERO
	if direccion.length() > 0.1:
		desplazamiento = direccion.normalized() * desplazamiento_maximo * clampf(poder, 0.0, 1.0)
	entidad_dueña.get_tree().current_scene.add_child(efecto)
	efecto.global_position = entidad_dueña.global_position + desplazamiento
	efecto.radio_base      = radio_area
	efecto.configurar(_calcular_dano(int(daño_area)), entidad_dueña, tipo_dano)
