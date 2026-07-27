extends EfectoAreaBase
class_name EfectoInmovilizar
## Efecto de área que impide moverse al objetivo mientras esté dentro.
## Usa un contador en MovimientoComponente para soportar efectos apilados.

## Ícono que muestra BarraBuffs/el panel "Buffs Activos" mientras el
## objetivo está inmovilizado. Null = sin indicador visual (antes esto no
## se anotaba en BuffsComponente para nada — reportado: "si te inmoviliza
## un enemigo no aparece ningún ícono").
@export var icono_debuff: Texture2D = null


func _aplicar_efecto(objetivo: Node) -> void:
	var mov := objetivo.get_node_or_null("MovimientoComponente") as MovimientoComponente
	if mov:
		mov.agregar_inmovilizacion()
	_anotar_icono(objetivo)


func _quitar_efecto(objetivo: Node) -> void:
	var mov := objetivo.get_node_or_null("MovimientoComponente") as MovimientoComponente
	if mov:
		mov.quitar_inmovilizacion()
	var buffs := objetivo.get_node_or_null("BuffsComponente") as BuffsComponente
	if buffs:
		buffs.quitar("inmovilizado")


## A diferencia de Veneno/Lentitud (pegados al objetivo, con su propia
## duración fija propia): esto es una ZONA — el objetivo queda
## inmovilizado mientras esté DENTRO, no un tiempo fijo desde que entró.
## Se usa lo que le queda al temporizador de la zona (_timer, ver
## EfectoAreaBase) como duración del buff, para que el conteo en pantalla
## no muestre un número arbitrario. _quitar_efecto() (arriba) ya saca el
## buff si el objetivo se va ANTES de que la zona expire — no hace falta
## que el timer interno de BuffsComponente coincida al segundo.
func _anotar_icono(objetivo: Node) -> void:
	if icono_debuff == null:
		return
	var buffs := objetivo.get_node_or_null("BuffsComponente") as BuffsComponente
	if buffs == null:
		buffs = BuffsComponente.new()
		buffs.name = "BuffsComponente"
		objetivo.add_child(buffs)
	buffs.agregar("inmovilizado", icono_debuff, _timer.time_left, true,
		"Inmovilizado", "No podés moverte mientras estés en la zona")
