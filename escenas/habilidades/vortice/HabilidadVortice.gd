class_name HabilidadVortice
extends HabilidadBase
## Campo que se lanza a distancia (como HabilidadAreaEfecto) y queda fijo
## en el punto donde cae, atrayendo repetidamente hacia su centro a los
## enemigos en su radio durante toda su duración — agrupa y MANTIENE
## agrupados a los enemigos, para poder rematarlos con otra habilidad a
## distancia. Sin daño propio a propósito: es una herramienta de control
## (ver Vortice.gd), no de daño. requiere_direccion=true está puesto en la
## escena (mismo criterio que HabilidadAreaEfecto), no acá.

## Sobreescrito por DatosHabilidad.aplicar_datos() al equipar.
var desplazamiento_maximo: float = 150.0
## Radio y duración del campo — configurables manualmente (sin equivalente
## en DatosHabilidad, mismo criterio que HabilidadAreaEfecto.radio_area).
@export var radio_vortice: float = 90.0
@export var duracion_vortice: float = 3.5
@export var fuerza_atraccion: float = 300.0
@export var intervalo_atraccion: float = 0.3
@export var escena_vortice: PackedScene = preload("res://escenas/habilidades/vortice/Vortice.tscn")


func _ready() -> void:
	super._ready()
	nombre_habilidad = "Vórtice"
	tipo_habilidad   = "vortice"


func aplicar_datos(d: DatosHabilidad) -> void:
	super.aplicar_datos(d)
	desplazamiento_maximo = d.alcance_metros * ESCALA_METROS_PIXEL


func _ejecutar(direccion: Vector2, poder: float) -> void:
	if not is_instance_valid(entidad_dueña) or not (entidad_dueña is Node2D):
		return
	var vortice := GestorPiscinas.obtener(escena_vortice) as Vortice
	var desplazamiento := Vector2.ZERO
	if direccion.length() > 0.1:
		desplazamiento = direccion.normalized() * desplazamiento_maximo * clampf(poder, 0.0, 1.0)
	vortice.global_position     = (entidad_dueña as Node2D).global_position + desplazamiento
	vortice.radio_base          = radio_vortice
	vortice.duracion_efecto     = duracion_vortice
	vortice.fuerza_atraccion    = fuerza_atraccion
	vortice.intervalo_atraccion = intervalo_atraccion
	vortice.configurar(0.0, entidad_dueña, tipo_dano)
