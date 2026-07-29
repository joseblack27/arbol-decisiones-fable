class_name HabilidadCuracion
extends HabilidadBase
## Curación EN EL TIEMPO (HoT, ver CuracionComponente) — a propósito
## distinta de un consumible: una poción cura de golpe, esto reparte la
## cura en ticks a lo largo de duracion_curacion segundos, con su propio
## ícono de buff mientras dura (ver BuffsComponente/BarraBuffs). Self-buff
## sin dirección (botón tap, como Escudo).

@export_group("Curación")
@export var cantidad_curacion: float = 60.0
@export var duracion_curacion: float = 6.0
## Ícono que muestra BarraBuffs mientras el HoT está activo. Null = no se
## anota en BuffsComponente (queda sin ícono en el HUD).
@export var icono_buff: Texture2D = null

var _componente_curacion: CuracionComponente = null


func _ready() -> void:
	super._ready()
	nombre_habilidad = "Curación"
	tipo_habilidad   = "curacion"
	requiere_direccion = false


func _ejecutar(_direccion: Vector2, _poder: float) -> void:
	if not is_instance_valid(entidad_dueña):
		return
	if _componente_curacion == null:
		_componente_curacion = entidad_dueña.get_node_or_null("CuracionComponente") as CuracionComponente
		if _componente_curacion == null:
			_componente_curacion = CuracionComponente.new()
			_componente_curacion.name = "CuracionComponente"
			entidad_dueña.add_child(_componente_curacion)
	_componente_curacion.activar(duracion_curacion, cantidad_curacion)

	if icono_buff != null:
		var buffs := entidad_dueña.get_node_or_null("BuffsComponente") as BuffsComponente
		if buffs == null:
			buffs = BuffsComponente.new()
			buffs.name = "BuffsComponente"
			entidad_dueña.add_child(buffs)
		buffs.agregar("curacion", icono_buff, duracion_curacion, false,
			nombre_habilidad, "Restaura %d de vida en %s" % [cantidad_curacion, Utils.formatear_segundos(duracion_curacion)])
