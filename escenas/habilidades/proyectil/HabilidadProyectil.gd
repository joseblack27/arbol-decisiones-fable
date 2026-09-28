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

## Ícono de la habilidad: sprite PROVISIONAL del proyectil mientras no haya
## arte dedicado (ver Proyectil.poner_textura_icono). En una habilidad de
## catálogo, aplicar_datos() lo pisa con DatosHabilidad.icono; en una armada A
## MANO en su escena (sin DatosHabilidad, como los ataques de EnemigoArañaReina)
## se fija acá en el Inspector. En null, Proyectil._draw() cae a los círculos
## de depuración.
@export var icono_provisional: Texture2D = null

func aplicar_datos(d: DatosHabilidad) -> void:
	super.aplicar_datos(d)
	alcance_maximo = d.alcance_metros * ESCALA_METROS_PIXEL
	alcance_segun_poder = d.alcance_segun_poder
	icono_provisional = d.icono

## RANGO: la propiedad real es "alcance_maximo" (píxeles), asignada arriba
## a partir de DatosHabilidad.alcance_metros — ver HabilidadBase
## ._nombre_campo_escalable/preparar_escalado.
func _nombre_campo_escalable(campo: Enums.Habilidad.CampoEscalable) -> String:
	if campo == Enums.Habilidad.CampoEscalable.RANGO:
		return "alcance_maximo"
	return super._nombre_campo_escalable(campo)

func _ejecutar(direccion: Vector2, poder: float) -> void:
	# Reutiliza un proyectil ya creado en vez de instanciar uno nuevo cada
	# disparo (object pooling: ver GestorPiscinas).
	var proy := GestorPiscinas.obtener(escena_proyectil) as Proyectil
	proy.global_position = entidad_dueña.global_position
	proy.alcance_base = alcance_maximo
	var poder_efectivo := poder if alcance_segun_poder else 1.0
	proy.configurar(direccion, poder_efectivo, _calcular_dano(int(daño_proyectil)), entidad_dueña, tipo_dano)
	# Con daño REAL configurado (DatosHabilidad.dano_base_min/max > 0), el
	# DoT del efecto de impacto (ej. EfectoVeneno) escala IGUAL que el golpe
	# inicial; si no, subir de nivel la habilidad solo cambiaba el golpe. Las
	# habilidades de jefe armadas a mano (sin DatosHabilidad, esos campos en
	# 0) conservan su dano_por_tick.
	if _dano_min > 0 or _dano_max > 0:
		proy.dano_para_efecto_tick = proy.daño
	# El ícono de buff/debuff que deje el efecto de impacto (veneno, lentitud...)
	# tiene que ser el de la HABILIDAD, no uno aparte hardcodeado en el .tscn
	# del efecto — ver Proyectil._spawnear_efecto_impacto().
	proy.icono_habilidad = icono_provisional
	# SIEMPRE llamar, también con null: así se APAGA el sprite-ícono que haya
	# quedado de una activación anterior en este nodo reciclado de la piscina
	# (de esta habilidad o de otra con la misma escena_proyectil base).
	proy.poner_textura_icono(icono_provisional if usar_icono_como_sprite else null)
	_reproducir_sonido()
