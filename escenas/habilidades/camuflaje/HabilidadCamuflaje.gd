class_name HabilidadCamuflaje
extends HabilidadBase
## Te vuelve OCULTO por unos segundos: los mobs dejan de poder tomarte como
## objetivo y los que ya te tenían fichado te sueltan (ver
## CamuflajeComponente). Self-buff sin dirección, se usa como botón tap.
##
## Para qué sirve: es la única herramienta del juego para SALIR de una pelea.
## Parpadeo te mueve pero los mobs te siguen persiguiendo, y Escudo aguanta el
## golpe sin resolver la situación. Con esto te despegás, te reposicionás y
## volvés a entrar cuando te conviene — pensado para sobrevivir jugando solo,
## que es la prioridad del juego.
##
## Se corta solo si atacás (lo maneja CamuflajeComponente): si no, sería una
## invulnerabilidad con golpes gratis.

@export_group("Camuflaje")
@export var duracion_camuflaje: float = 4.0
## Ícono que muestra BarraBuffs mientras dura. Null = sin ícono en el HUD.
@export var icono_buff: Texture2D = null

var _componente: CamuflajeComponente = null


func _ready() -> void:
	super._ready()
	nombre_habilidad = "Camuflaje"
	tipo_habilidad   = "camuflaje"
	requiere_direccion = false


## El ícono del buff tiene que ser el mismo que ves en el botón — pedido del
## usuario: "quiero que el icono que salga como debuff o buff sea el que se
## usa como habilidad no el del proyectil" (aplica también a self-buffs sin
## proyectil de por medio, mismo criterio).
func aplicar_datos(d: DatosHabilidad) -> void:
	super.aplicar_datos(d)
	if d.icono:
		icono_buff = d.icono


func _ejecutar(_direccion: Vector2, _poder: float) -> void:
	if not is_instance_valid(entidad_dueña):
		return
	if _componente == null:
		# Mismo criterio que HabilidadEscudo: se busca el componente y, si la
		# entidad no lo trae de fábrica, se crea solo — así la habilidad
		# funciona en cualquier entidad sin tener que tocar su escena.
		_componente = entidad_dueña.get_node_or_null("CamuflajeComponente") as CamuflajeComponente
		if _componente == null:
			_componente = CamuflajeComponente.new()
			_componente.name = "CamuflajeComponente"
			entidad_dueña.add_child(_componente)
	_componente.activar(duracion_camuflaje)

	if icono_buff != null:
		var buffs := entidad_dueña.get_node_or_null("BuffsComponente") as BuffsComponente
		if buffs == null:
			buffs = BuffsComponente.new()
			buffs.name = "BuffsComponente"
			entidad_dueña.add_child(buffs)
		buffs.agregar("camuflaje", icono_buff, duracion_camuflaje, false, "Camuflaje")
