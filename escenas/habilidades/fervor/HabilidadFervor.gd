class_name HabilidadFervor
extends HabilidadBase
## Self-buff: durante "duracion_fervor" segundos, el resto de tus
## habilidades equipadas recargan más rápido (multiplicador_velocidad veces).
## No se afecta a sí misma — usarla en cadena para extenderse solo no tiene
## sentido y sería spam gratis.
##
## Distinta de Grito de guerra (que sube el NÚMERO de daño): esto deja
## encadenar más golpes en la misma ventana, no pegar más fuerte cada uno.
##
## Se re-evalúa cada frame (en vez de un Timer de una sola vez) para que
## usarla de nuevo ANTES de que venza la anterior extienda la ventana en
## vez de cortarla a mitad de camino cuando el primer timer disparara.

@export_group("Fervor")
@export var duracion_fervor: float = 6.0
## 2.0 = el doble de rápido (la mitad de tiempo de recarga).
@export var multiplicador_velocidad: float = 2.0
## Ícono que muestra BarraBuffs mientras dura. Null = sin ícono en el HUD.
@export var icono_buff: Texture2D = null

var _fin_fervor: float = -INF


func _ready() -> void:
	super._ready()
	nombre_habilidad = "Fervor"
	tipo_habilidad   = "fervor"
	requiere_direccion = false


## El ícono del buff tiene que ser el mismo que ves en el botón — pedido
## del usuario, ver la nota igual en HabilidadCamuflaje.
func aplicar_datos(d: DatosHabilidad) -> void:
	super.aplicar_datos(d)
	if d.icono:
		icono_buff = d.icono


func _process(delta: float) -> void:
	super._process(delta)
	if not is_instance_valid(entidad_dueña):
		return
	var activo := Time.get_ticks_msec() / 1000.0 < _fin_fervor
	var objetivo := multiplicador_velocidad if activo else 1.0
	for hijo in entidad_dueña.get_children():
		if hijo is HabilidadBase and hijo != self and hijo.multiplicador_recarga != objetivo:
			hijo.multiplicador_recarga = objetivo


func _ejecutar(_direccion: Vector2, _poder: float) -> void:
	if not is_instance_valid(entidad_dueña):
		return
	_fin_fervor = Time.get_ticks_msec() / 1000.0 + duracion_fervor

	if icono_buff != null:
		var buffs := entidad_dueña.get_node_or_null("BuffsComponente") as BuffsComponente
		if buffs == null:
			buffs = BuffsComponente.new()
			buffs.name = "BuffsComponente"
			entidad_dueña.add_child(buffs)
		buffs.agregar("fervor", icono_buff, duracion_fervor, false, "Fervor",
			"El resto de tus habilidades recargan %dx más rápido" % int(multiplicador_velocidad))
