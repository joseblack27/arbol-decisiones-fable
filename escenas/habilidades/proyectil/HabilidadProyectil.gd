class_name HabilidadProyectil
extends HabilidadBase
## Lanza un proyectil en la dirección indicada.

## Sobreescrito por DatosHabilidad.aplicar_datos() SOLO si dano_base_min/max
## son > 0 ahí (ver _calcular_dano en HabilidadBase) — de lo contrario
## queda este valor de fábrica, configurable por variante de escena (p. ej.
## en 0.0 para un proyectil de puro control, como HabilidadProyectilInmovilizador).
@export var daño_proyectil: float = 20.0
var alcance_maximo: float = 400.0
@export var escena_proyectil: PackedScene = preload("res://escenas/habilidades/proyectil/Proyectil.tscn")
## Si está activo, estirar menos el joystick acorta el alcance (poder 0..1).
## Apagado (por defecto): el proyectil siempre viaja recto hasta el alcance máximo.
@export var alcance_segun_poder := false
## Si está activo (por defecto), el proyectil usa el ÍCONO de la habilidad
## como sprite provisional (ver Proyectil.poner_textura_icono) mientras no
## haya arte dedicado. Apagar esto en variantes con escena_proyectil propia
## (arte real: Sprite2D/AnimatedSprite2D en su .tscn, como el abanico) —
## sin apagarlo, el ícono se dibujaría ENCIMA del arte real, duplicado.
@export var usar_icono_como_sprite := true

func _ready() -> void:
	super._ready()
	nombre_habilidad = "Proyectil"
	tipo_habilidad   = "proyectil"

## Ícono de la habilidad (DatosHabilidad.icono) — se usa como sprite
## provisional del proyectil, ver Proyectil.poner_textura_icono().
var _icono: Texture2D = null

func aplicar_datos(d: DatosHabilidad) -> void:
	super.aplicar_datos(d)
	alcance_maximo = d.alcance_metros * ESCALA_METROS_PIXEL
	alcance_segun_poder = d.alcance_segun_poder
	_icono = d.icono

func _ejecutar(direccion: Vector2, poder: float) -> void:
	# Reutiliza un proyectil ya creado en vez de instanciar uno nuevo cada
	# disparo (object pooling: ver GestorPiscinas).
	var proy := GestorPiscinas.obtener(escena_proyectil) as Proyectil
	proy.global_position = entidad_dueña.global_position
	proy.alcance_base = alcance_maximo
	var poder_efectivo := poder if alcance_segun_poder else 1.0
	proy.configurar(direccion, poder_efectivo, _calcular_dano(int(daño_proyectil)), entidad_dueña, tipo_dano)
	# SIEMPRE llamar (nunca "if usar_icono_como_sprite: ..."): con null,
	# poner_textura_icono() APAGA cualquier sprite-ícono que hubiera quedado
	# puesto en este mismo nodo reciclado del pool por una activación
	# ANTERIOR (de esta misma habilidad antes de desmarcar la casilla, o de
	# otra habilidad que comparte la misma escena_proyectil base) — omitir
	# la llamada dejaba ese sprite viejo colgado para siempre (reportado:
	# "lanza un proyectil de uno y los otros de otro sprite").
	proy.poner_textura_icono(_icono if usar_icono_como_sprite else null)
