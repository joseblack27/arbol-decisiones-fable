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

## Ícono de la habilidad — sprite PROVISIONAL del proyectil mientras no haya
## arte dedicado (ver Proyectil.poner_textura_icono). Para una habilidad de
## catálogo, aplicar_datos() lo pisa con DatosHabilidad.icono; para una
## armada A MANO en su propia escena (sin DatosHabilidad — los ataques de
## jefe, como los de EnemigoArañaReina) se fija DIRECTO acá, en el
## Inspector de esa instancia, en vez de quedar en null (que hace caer a
## los círculos de debug de Proyectil._draw() — reportado por el usuario).
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
	# Si esta habilidad tiene daño REAL configurado (DatosHabilidad.dano_
	# base_min/max > 0, ver aplicar_datos en HabilidadBase), que el DoT que
	# deje el efecto de impacto (ej. EfectoVeneno) escale IGUAL que el
	# golpe inicial — sin esto, subir de nivel una habilidad como Veneno
	# cambiaba el golpe inicial pero el veneno seguía haciendo el mismo
	# daño de tick fijo de siempre (reportado por el usuario). Acotado a
	# _dano_min/_dano_max > 0 para NO afectar habilidades de jefe armadas a
	# mano en su propia escena (sin DatosHabilidad, esos campos se quedan
	# en 0) — esas conservan su propio dano_por_tick tal cual.
	if _dano_min > 0 or _dano_max > 0:
		proy.dano_para_efecto_tick = proy.daño
	# El ícono de buff/debuff que deje el efecto de impacto (veneno, lentitud...)
	# tiene que ser el de la HABILIDAD, no uno aparte hardcodeado en el .tscn
	# del efecto — ver Proyectil._spawnear_efecto_impacto().
	proy.icono_habilidad = icono_provisional
	# SIEMPRE llamar (nunca "if usar_icono_como_sprite: ..."): con null,
	# poner_textura_icono() APAGA cualquier sprite-ícono que hubiera quedado
	# puesto en este mismo nodo reciclado del pool por una activación
	# ANTERIOR (de esta misma habilidad antes de desmarcar la casilla, o de
	# otra habilidad que comparte la misma escena_proyectil base) — omitir
	# la llamada dejaba ese sprite viejo colgado para siempre (reportado:
	# "lanza un proyectil de uno y los otros de otro sprite").
	proy.poner_textura_icono(icono_provisional if usar_icono_como_sprite else null)
