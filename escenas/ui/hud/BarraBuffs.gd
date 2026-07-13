extends HBoxContainer
class_name BarraBuffs
## Fila de íconos de buffs/debuffs ACTIVOS del jugador propio — una entrada
## por cada buff en su BuffsComponente (ver ese archivo), sincronizada por
## señales: agregar()/quitar() ahí instancia o libera el IndicadorBuff
## correspondiente acá, sin que este nodo tenga que saber qué habilidad lo
## generó. Crece de izquierda a derecha sola (HBoxContainer): agregar un
## buff nuevo más no requiere tocar este archivo.
##
## Vive en Mundo.tscn (solo clientes) y se engancha solo al jugador PROPIO,
## con el mismo reintento hasta encontrarlo que ya usa HudJugador.gd.

const ESCENA_INDICADOR := preload("res://escenas/ui/hud/IndicadorBuff.tscn")

var _buffs: BuffsComponente = null
var _indicadores: Dictionary[String, IndicadorBuff] = {}
var _acumulador_reintento := 0.0


func _process(delta: float) -> void:
	if _buffs == null or not is_instance_valid(_buffs):
		_acumulador_reintento += delta
		if _acumulador_reintento >= 0.5:
			_acumulador_reintento = 0.0
			_conectar()
		return

	for id in _indicadores.keys():
		var buff := _buffs.obtener(id)
		if buff == null:
			continue
		var ratio := (buff.tiempo_restante / buff.duracion_total) if buff.duracion_total > 0.0 else 0.0
		_indicadores[id].actualizar(ratio)


func _conectar() -> void:
	var jugador := Utils.jugador_local() as Node2D
	if jugador == null:
		return
	_buffs = jugador.get_node_or_null("BuffsComponente") as BuffsComponente
	if _buffs == null:
		return
	_buffs.buff_agregado.connect(_on_buff_agregado)
	_buffs.buff_quitado.connect(_on_buff_quitado)
	# Por si ya había buffs activos ANTES de que esta barra se conectara
	# (p. ej. la UI se recargó a mitad de partida).
	for id in _buffs.activos():
		_on_buff_agregado(id)


func _on_buff_agregado(id: String) -> void:
	if _indicadores.has(id):
		return
	var buff := _buffs.obtener(id)
	if buff == null:
		return
	var indicador: IndicadorBuff = ESCENA_INDICADOR.instantiate()
	add_child(indicador)
	indicador.configurar(buff.icono, buff.es_debuff)
	_indicadores[id] = indicador


func _on_buff_quitado(id: String) -> void:
	if not _indicadores.has(id):
		return
	_indicadores[id].queue_free()
	_indicadores.erase(id)
