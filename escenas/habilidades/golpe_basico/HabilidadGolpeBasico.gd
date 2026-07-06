class_name HabilidadGolpeBasico
extends HabilidadBase
## Golpe cuerpo a cuerpo instantáneo en la dirección que mira el agente.
## Crea un hitbox de corta duración frente a la entidad.

## Sobreescrito por DatosHabilidad.aplicar_datos() al equipar.
var daño: float          = 15.0
var alcance_golpe: float = 48.0
## Sin equivalente en DatosHabilidad — configurable manualmente.
@export var radio_golpe: float    = 30.0
@export var duracion_golpe: float = 0.15
@export var escena_golpe: PackedScene = preload("res://escenas/habilidades/golpe_basico/GolpeBasico.tscn")

func _ready() -> void:
	super._ready()
	nombre_habilidad = "Golpe Básico"
	tipo_habilidad   = "golpe"

func aplicar_datos(d: DatosHabilidad) -> void:
	super.aplicar_datos(d)
	alcance_golpe = d.alcance_metros * ESCALA_METROS_PIXEL
	if d.radio_golpe > 0.0:
		radio_golpe = d.radio_golpe

func _ejecutar(direccion: Vector2, _poder: float) -> void:
	var golpe  := escena_golpe.instantiate() as GolpeBasico
	var frente := direccion if direccion.length() > 0.1 else Vector2.RIGHT
	# add_child primero para que _ready() del golpe se ejecute antes de configurar()
	entidad_dueña.get_tree().current_scene.add_child(golpe)
	golpe.global_position = entidad_dueña.global_position + frente * alcance_golpe
	golpe.configurar(_calcular_dano(int(daño)), radio_golpe, entidad_dueña, duracion_golpe, tipo_dano)
