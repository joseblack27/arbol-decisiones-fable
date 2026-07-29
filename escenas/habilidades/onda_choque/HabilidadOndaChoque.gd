class_name HabilidadOndaChoque
extends HabilidadBase
## Onda de Choque: AoE centrada en quien la usa que daña Y empuja lejos a
## los enemigos alcanzados — self-buff sin dirección (botón tap, como
## Curación/Escudo): siempre centrada en el propio agente, a diferencia de
## HabilidadAreaEfecto (que se desplaza hacia donde apunta el joystick).

## Sobreescrito por DatosHabilidad.aplicar_datos() SOLO si dano_base_min/max
## son > 0 ahí (ver _calcular_dano en HabilidadBase).
var daño_onda: float = 15.0
## Radio del área — configurable manualmente (sin equivalente en DatosHabilidad).
@export var radio_onda: float = 90.0
@export var fuerza_empuje: float = 400.0
@export var duracion_empuje: float = 0.25
@export var escena_onda: PackedScene = preload("res://escenas/habilidades/onda_choque/OndaChoque.tscn")


func _ready() -> void:
	super._ready()
	nombre_habilidad = "Onda de Choque"
	tipo_habilidad   = "onda_choque"
	requiere_direccion = false


func aplicar_datos(d: DatosHabilidad) -> void:
	super.aplicar_datos(d)
	if d.radio_golpe > 0.0:
		radio_onda = d.radio_golpe


func _ejecutar(_direccion: Vector2, _poder: float) -> void:
	if not is_instance_valid(entidad_dueña):
		return
	# Reutiliza una onda ya creada en vez de instanciar una nueva cada vez
	# (object pooling: ver GestorPiscinas). Sin tipar como OndaChoque (clase
	# recién creada): referenciarla por tipo estático desde otro script
	# recién editado falla al cargar ("Could not find type OndaChoque")
	# hasta que el proyecto pasa por el editor una vez — mismo artefacto ya
	# visto con otras clases nuevas en este proyecto.
	var efecto = GestorPiscinas.obtener(escena_onda)
	efecto.global_position  = entidad_dueña.global_position
	efecto.radio_base       = radio_onda
	efecto.fuerza_empuje    = fuerza_empuje
	efecto.duracion_empuje  = duracion_empuje
	efecto.configurar(_calcular_dano(int(daño_onda)), entidad_dueña, tipo_dano)
