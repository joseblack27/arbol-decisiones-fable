class_name HabilidadPurga
extends HabilidadBase
## Te libera al instante de todos los debuffs TEMPORALES que lleves pegados
## (veneno, lentitud, y cualquier futuro que extienda EfectoTemporalPegado) y
## te da unos segundos de inmunidad a que te apliquen uno nuevo. Self-buff
## sin dirección, se usa como botón tap — mismo criterio que Camuflaje.
##
## A propósito NO toca efectos de ZONA (Inmovilizar, DoT, Marca — ver
## EfectoAreaBase): esos no son un "estado que llevás encima", son mientras
## estás parado en un área, y volverían a aplicarse solos apenas sigas ahí.
## Tampoco toca ningún debuff de zona/mapa que se agregue más adelante,
## salvo que ese efecto nuevo decida extender EfectoTemporalPegado a
## propósito — la separación es intencional, pedida por el usuario.

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


## El ícono del buff de inmunidad tiene que ser el mismo que ves en el
## botón — pedido del usuario, ver la nota igual en HabilidadCamuflaje.
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
