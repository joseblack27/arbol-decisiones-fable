extends Node
class_name BuffsComponente
## Registro genérico de buffs/debuffs ACTIVOS de una entidad, puramente para
## PRESENTACIÓN (ver BarraBuffs/IndicadorBuff) — no aplica ningún efecto de
## gameplay por sí mismo. Cada sistema real (EscudoComponente, y los que
## vengan) sigue resolviendo su propio efecto por su cuenta; esto solo lleva
## la lista de "qué mostrar" y cuenta el tiempo hacia atrás en paralelo, así
## queda totalmente desacoplado — cualquier habilidad futura puede anotar un
## buff o debuff acá con un ícono y una duración, sin que este componente
## necesite saber nada de lo que hace ese efecto de verdad.
##
## Un solo id por entrada: agregar() con un id que ya existe renueva esa
## entrada (mismo ícono o no) en vez de duplicarla — sirve para refrescar un
## buff reactivado antes de que venza el anterior.

signal buff_agregado(id: String)
signal buff_actualizado(id: String)
signal buff_quitado(id: String)


class Buff:
	var id: String
	var icono: Texture2D
	var es_debuff: bool = false
	var duracion_total: float = 0.0
	var tiempo_restante: float = 0.0


var _buffs: Dictionary[String, Buff] = {}


func _process(delta: float) -> void:
	if _buffs.is_empty():
		return
	for id in _buffs.keys():
		var buff: Buff = _buffs[id]
		buff.tiempo_restante -= delta
		if buff.tiempo_restante <= 0.0:
			_buffs.erase(id)
			buff_quitado.emit(id)
		else:
			buff_actualizado.emit(id)


## Agrega (o renueva) un buff/debuff visible por "duracion" segundos.
func agregar(id: String, icono: Texture2D, duracion: float, es_debuff: bool = false) -> void:
	var es_nuevo := not _buffs.has(id)
	var buff: Buff = _buffs.get(id, Buff.new())
	buff.id              = id
	buff.icono            = icono
	buff.es_debuff         = es_debuff
	buff.duracion_total    = duracion
	buff.tiempo_restante   = duracion
	_buffs[id] = buff
	if es_nuevo:
		buff_agregado.emit(id)
	else:
		buff_actualizado.emit(id)


func quitar(id: String) -> void:
	if not _buffs.has(id):
		return
	_buffs.erase(id)
	buff_quitado.emit(id)


func obtener(id: String) -> Buff:
	return _buffs.get(id)


func esta_activo(id: String) -> bool:
	return _buffs.has(id)


## Copia de los ids activos AHORA MISMO — útil para poblar una barra recién
## conectada (buffs que ya estaban activos antes de que la UI se enganchara).
func activos() -> Array[String]:
	var lista: Array[String] = []
	for id in _buffs.keys():
		lista.append(id)
	return lista
