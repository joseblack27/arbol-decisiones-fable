class_name HabilidadPurga
extends HabilidadBase
## Te libera al instante de todos los debuffs TEMPORALES que lleves pegados
## (veneno, lentitud y cualquiera que extienda EfectoTemporalPegado) y te da
## unos segundos de inmunidad a uno nuevo. Auto-buff sin dirección, se usa
## como botón, como Camuflaje.
##
## A propósito NO toca efectos de ZONA (Inmovilizar, DoT, Marca; ver
## EfectoAreaBase): no son un estado que llevás encima sino un área donde
## estás parado, y volverían a aplicarse enseguida. Un debuff nuevo solo queda
## cubierto si extiende EfectoTemporalPegado.

@export_group("Purga")
@export var duracion_inmunidad: float = 3.0
## Ícono que muestra BarraBuffs mientras dura la inmunidad. Null = sin ícono.
@export var icono_inmunidad: Texture2D = null

var _inmunidad: InmunidadDebuffsComponente = null


func _ready() -> void:
	super._ready()
	nombre_habilidad = "Purga"
	tipo_habilidad   = "purga"
	requiere_direccion = false


## El ícono del buff de inmunidad es el mismo del botón (ver la nota igual en
## HabilidadCamuflaje).
func aplicar_datos(d: DatosHabilidad) -> void:
	super.aplicar_datos(d)
	if d.icono:
		icono_inmunidad = d.icono


func _ejecutar(_direccion: Vector2, _poder: float) -> void:
	if not is_instance_valid(entidad_dueña):
		return

	# Cancelar todo lo que ya lleve encima — solo lo que extienda la base
	# de "pegado" (ver EfectoTemporalPegado): un efecto de zona ni siquiera
	# vive colgado del jugador, así que este bucle nunca lo alcanza.
	for hijo in entidad_dueña.get_children():
		if hijo is EfectoTemporalPegado and (hijo as EfectoTemporalPegado).es_debuff:
			(hijo as EfectoTemporalPegado).cancelar()

	if duracion_inmunidad <= 0.0:
		return

	if _inmunidad == null:
		# Mismo criterio que HabilidadCamuflaje/HabilidadEscudo: se busca el
		# componente y, si la entidad no lo trae de fábrica, se crea solo.
		_inmunidad = entidad_dueña.get_node_or_null("InmunidadDebuffsComponente") \
			as InmunidadDebuffsComponente
		if _inmunidad == null:
			_inmunidad = InmunidadDebuffsComponente.new()
			_inmunidad.name = "InmunidadDebuffsComponente"
			entidad_dueña.add_child(_inmunidad)
	_inmunidad.activar(duracion_inmunidad)

	if icono_inmunidad != null:
		var buffs := entidad_dueña.get_node_or_null("BuffsComponente") as BuffsComponente
		if buffs == null:
			buffs = BuffsComponente.new()
			buffs.name = "BuffsComponente"
			entidad_dueña.add_child(buffs)
		buffs.agregar("inmunidad_debuffs", icono_inmunidad, duracion_inmunidad, false,
			"Inmunidad", "No podés recibir debuffs temporales")
