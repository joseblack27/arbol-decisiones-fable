class_name HabilidadProyectil
extends HabilidadBase
## Lanza un proyectil en la dirección indicada.

## Sobreescrito por DatosHabilidad.aplicar_datos() al equipar.
var daño_proyectil: float = 20.0
var alcance_maximo: float = 400.0
@export var escena_proyectil: PackedScene = preload("res://escenas/habilidades/proyectil/Proyectil.tscn")
## Si está activo, estirar menos el joystick acorta el alcance (poder 0..1).
## Apagado (por defecto): el proyectil siempre viaja recto hasta el alcance máximo.
@export var alcance_segun_poder := false

func _ready() -> void:
	super._ready()
	nombre_habilidad = "Proyectil"
	tipo_habilidad   = "proyectil"

func aplicar_datos(d: DatosHabilidad) -> void:
	super.aplicar_datos(d)
	alcance_maximo = d.alcance_metros * ESCALA_METROS_PIXEL
	alcance_segun_poder = d.alcance_segun_poder

func _ejecutar(direccion: Vector2, poder: float) -> void:
	# Reutiliza un proyectil ya creado en vez de instanciar uno nuevo cada
	# disparo (object pooling: ver GestorPiscinas).
	var proy := GestorPiscinas.obtener(escena_proyectil) as Proyectil
	proy.global_position = entidad_dueña.global_position
	proy.alcance_base = alcance_maximo
	var poder_efectivo := poder if alcance_segun_poder else 1.0
	proy.configurar(direccion, poder_efectivo, _calcular_dano(int(daño_proyectil)), entidad_dueña, tipo_dano)
