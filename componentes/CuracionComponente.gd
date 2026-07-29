extends Node
class_name CuracionComponente
## Curación EN EL TIEMPO (HoT): reparte "cantidad_total" en ticks de 1
## segundo a lo largo de "duracion" — a diferencia de un consumible
## (curación instantánea de golpe, ver InventarioComponente.usar_item), así
## la habilidad se siente distinta a tomar una poción, no es solo lo mismo
## con otro botón.
##
## Aplica el efecto real vía VidaComponente.agregar_vida() en cada tick —
## el mismo punto de siempre, ya server-autoritativo en red (agregar_vida()
## no-opea en el cliente puro y el servidor le manda el valor real de
## vuelta). Mismo criterio que EscudoComponente: componente genérico,
## activado por una habilidad (ver HabilidadCuracion), reusable por
## cualquier entidad futura que quiera este mismo efecto.

const _INTERVALO_TICK := 1.0

var _tiempo_restante: float = 0.0
var _duracion_total: float = 0.0
var _curacion_por_tick: float = 0.0
var _acumulador: float = 0.0


func _process(delta: float) -> void:
	if _tiempo_restante <= 0.0:
		return
	_tiempo_restante = maxf(0.0, _tiempo_restante - delta)
	_acumulador += delta
	if _acumulador >= _INTERVALO_TICK:
		_acumulador -= _INTERVALO_TICK
		_aplicar_tick()


## Activa (o renueva) el HoT: "cantidad_total" repartida en "duracion"
## segundos, un tick por segundo.
func activar(duracion: float, cantidad_total: float) -> void:
	_duracion_total     = maxf(_INTERVALO_TICK, duracion)
	_tiempo_restante     = _duracion_total
	var ticks_totales    := _duracion_total / _INTERVALO_TICK
	_curacion_por_tick   = cantidad_total / ticks_totales
	_acumulador          = 0.0


func esta_activo() -> bool:
	return _tiempo_restante > 0.0


func tiempo_restante() -> float:
	return maxf(0.0, _tiempo_restante)


func _aplicar_tick() -> void:
	var padre := get_parent()
	if padre == null:
		return
	var vida := padre.get_node_or_null("VidaComponente") as VidaComponente
	if vida:
		vida.agregar_vida(_curacion_por_tick)
