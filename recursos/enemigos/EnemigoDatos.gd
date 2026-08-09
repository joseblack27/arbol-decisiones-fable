extends Resource
class_name EnemigoDatos
## Plantilla de datos para un tipo de enemigo.
## Crea un .tres por tipo y asígnalo en el Inspector de Enemigo.tscn.

@export_group("Identidad")
@export var nombre_tipo: String = "Normal"
## Id estable para referenciar este tipo de enemigo desde afuera (p. ej.
## DatosObjetivoMision.id_meta de un objetivo MATAR) sin depender de
## nombre_tipo, que es texto de presentación y puede cambiar por cosmética/
## traducción. Vacío = usar nombre_tipo como id (obtener_id(), abajo) — los
## .tres existentes no necesitan llenarlo para seguir funcionando.
@export var id: String = ""
## Color multiplicativo aplicado al Sprite2D (modulate).
@export var color: Color = Color.WHITE

@export_group("Vida")
@export var vida_maxima: float = 100.0

@export_group("Movimiento")
@export var velocidad_base: float = 150.0

@export_group("Energía")
@export var energia_maxima: float         = 80.0
@export var regeneracion_energia: float   = 10.0
## Nivel del mob, para el nameplate (ver BarraVidaEnergiaComponente). Es solo
## informativo por ahora: no escala vida ni daño — eso sigue viniendo de los
## campos de abajo. Sirve para que el jugador sepa de un vistazo si un mob le
## queda grande antes de meterse.
@export var nivel: int = 1


## Id efectivo para matchear contra target_id de un objetivo de misión:
## el propio "id" si se llenó, si no nombre_tipo (fallback, ver el export).
func obtener_id() -> String:
	return id if id != "" else nombre_tipo
