class_name HabilidadAura
extends HabilidadBase
## Aura de daño continuo alrededor de quien la activa — mientras dura,
## cualquier enemigo a "radio" px recibe daño cada "intervalo_tick"
## segundos, entre y salga del radio las veces que quiera. Self-buff sin
## dirección (botón tap), como Curación/Escudo.

@export_group("Aura")
@export var radio: float = 25.0
@export var dano_por_tick: float = 6.0
@export var intervalo_tick: float = 1.0
@export var duracion_aura: float = 6.0
## Fracción del daño YA calculado que de verdad pega cada tick (pedido
## del usuario: "que el daño sea el 50% del calculado, y ese mismo valor
## lo muestre en el detalle"). Mismo nombre de propiedad que
## HabilidadLanzallamas.multiplicador_dano_tick a propósito:
## PanelDetalleHabilidad.gd ya sabe leerlo por ese nombre para mostrar el
## "Daño Calculado" correcto, sin tocar ese panel para nada.
@export_range(0.05, 1.0, 0.05) var multiplicador_dano_tick: float = 0.5
## Ícono que muestra BarraBuffs (ver BuffsComponente) mientras el aura
## está activa. Null = no se anota en BuffsComponente.
@export var icono_buff: Texture2D = null

var _componente_aura: AuraDanoComponente = null


func _ready() -> void:
	super._ready()
	nombre_habilidad = "Aura"
	tipo_habilidad   = "aura"
	requiere_direccion = false


func _ejecutar(_direccion: Vector2, _poder: float) -> void:
	if not is_instance_valid(entidad_dueña):
		return
	if _componente_aura == null:
		_componente_aura = entidad_dueña.get_node_or_null("AuraDanoComponente") as AuraDanoComponente
		if _componente_aura == null:
			_componente_aura = AuraDanoComponente.new()
			_componente_aura.name = "AuraDanoComponente"
			entidad_dueña.add_child(_componente_aura)
	_componente_aura.radio                    = radio
	_componente_aura.dano_por_tick            = dano_por_tick
	_componente_aura.intervalo_tick           = intervalo_tick
	_componente_aura.tipo_dano                = tipo_dano
	_componente_aura.multiplicador_dano_tick  = multiplicador_dano_tick
	_componente_aura.activar(entidad_dueña as Node2D, self, duracion_aura)

	if icono_buff != null:
		var buffs := entidad_dueña.get_node_or_null("BuffsComponente") as BuffsComponente
		if buffs == null:
			buffs = BuffsComponente.new()
			buffs.name = "BuffsComponente"
			entidad_dueña.add_child(buffs)
		buffs.agregar("aura_dano", icono_buff, duracion_aura, false,
			nombre_habilidad, _descripcion_buff())


## Mismo número que muestra "Daño Calculado" en el detalle de la habilidad
## — mismo helper compartido (AtributosComponente.calcular_rango_con_
## factor), así los dos números nunca pueden desincronizarse entre sí (la
## primera versión de esto calculaba el rango a mano y se saltaba los
## atributos del jugador, reportado: "el daño que se muestra... no es el
## calculado para el aura"). Sin rango cargado (DatosHabilidad no
## aplicado), cae al dano_por_tick de fábrica de la escena.
func _descripcion_buff() -> String:
	var base_min: float = _dano_min if _dano_min > 0 else dano_por_tick
	var base_max: float = _dano_max if _dano_max > 0 else dano_por_tick
	var atrib: AtributosComponente = null
	if is_instance_valid(entidad_dueña):
		atrib = entidad_dueña.get_node_or_null("AtributosComponente") as AtributosComponente
	var rango := AtributosComponente.calcular_rango_con_factor(atrib, base_min, base_max, multiplicador_dano_tick)
	var texto_dano := "%d" % rango.x if rango.x == rango.y else "%d-%d" % [rango.x, rango.y]
	return "%s de daño a los enemigos cerca tuyo cada %s" % [texto_dano, Utils.formatear_segundos(intervalo_tick)]
