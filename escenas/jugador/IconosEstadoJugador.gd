extends Node2D
## Fila de íconos de estado (veneno, lentitud, aturdido...) ENCIMA del
## jugador, visible para cualquiera que lo mire (réplicas incluidas): el
## aturdimiento se nota sin tener que mirar BarraBuffs en la esquina. Mismo
## criterio visual que Enemigo._dibujar_iconos_estado_mob. Lo crea Jugador.gd
## como hijo en todos los peers.
##
## BuffsComponente puede no existir todavía al arrancar (ver EfectoVeneno/
## EfectoAturdir._anotar_icono), así que se reintenta encontrarlo (mismo
## criterio que Enemigo.gd y BarraBuffs.gd).

@export var tamano_icono: float = 16.0
@export var separacion_iconos: float = 3.0
## Separación entre el borde superior REAL del sprite y la fila de íconos. El
## borde se calcula (ver _altura_sobre_el_sprite) en vez de fijar un Y a ojo,
## que queda mal apenas cambia la escala del sprite. Mismo criterio que
## Enemigo.margen_iconos_estado; lo vigila prueba_iconos_estado_jugador.
@export var margen: float = 4.0

const _COLOR_CONTORNO := Color(0.0, 0.0, 0.0, 0.9)
const _INTERVALO_REINTENTO_BUFFS := 0.5

var _buffs: BuffsComponente = null
var _buffs_activos: Array[String] = []
var _acumulador_reintento := 0.0


func _ready() -> void:
	position = Vector2(0.0, _altura_sobre_el_sprite())
	_intentar_conectar_buffs()


func _process(delta: float) -> void:
	if _buffs != null:
		set_process(false)
		return
	_acumulador_reintento += delta
	if _acumulador_reintento >= _INTERVALO_REINTENTO_BUFFS:
		_acumulador_reintento = 0.0
		_intentar_conectar_buffs()


func _draw() -> void:
	Utils.dibujar_iconos_estado(self, _buffs, _buffs_activos,
		tamano_icono, separacion_iconos, _COLOR_CONTORNO)


## Y local (negativo = arriba) donde se apoya la fila, contra el borde superior
## REAL del sprite del jugador (mismo criterio que Enemigo._altura_iconos_estado).
func _altura_sobre_el_sprite() -> float:
	var sprite := get_parent().get_node_or_null("Sprite2D") as Sprite2D
	if not sprite or not sprite.texture or sprite.vframes <= 0:
		return -(margen + tamano_icono)
	var alto_frame := (sprite.texture.get_height() / float(sprite.vframes)) * sprite.scale.y
	var borde_superior_sprite := sprite.position.y - alto_frame / 2.0
	return borde_superior_sprite - margen - tamano_icono


func _intentar_conectar_buffs() -> void:
	if _buffs != null:
		return
	var comp := get_parent().get_node_or_null("BuffsComponente") as BuffsComponente
	if comp == null:
		return
	_buffs = comp
	_buffs.buff_agregado.connect(_al_cambiar_buffs)
	_buffs.buff_quitado.connect(_al_cambiar_buffs)
	_al_cambiar_buffs("")


## Se relee la lista completa en vez de agregar/quitar un id puntual: mismo
## criterio que Enemigo._al_cambiar_buffs_estado.
func _al_cambiar_buffs(_id: String) -> void:
	_buffs_activos = _buffs.activos()
	queue_redraw()
