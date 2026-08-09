extends Node
class_name CreditosComponente
## Monedero de créditos del jugador. Mutador simple, SIN RPC propio (mismo
## criterio que InventarioComponente.agregar_item()/quitar_item()): los
## créditos solo cambian por 2 vías controladas — comprar en una tienda
## (TiendaComponente) y cobrar recompensa de misión (MisionesComponente) —
## y las dos ya llevan su propio eco de confirmación dedicado (ver
## ComponenteConfirmacionesRed). No hace falta la réplica periódica de
## EnergiaComponente: esa existe porque la energía cambia todo el tiempo
## por fuentes impredecibles (regen por tick, gasto de habilidades); acá
## el propio "iniciador de acción" (Tienda/Misiones) ya avisa al cliente
## dueño cuándo cambió y con qué valor exacto.

signal creditos_cambiados(nuevo: int)

var _creditos_actuales: int = 0


func agregar_creditos(cantidad: int) -> void:
	if cantidad <= 0:
		return
	_creditos_actuales += cantidad
	creditos_cambiados.emit(_creditos_actuales)
	BusEventos.creditos_cambiados.emit(get_parent(), _creditos_actuales)


## Devuelve true si había suficiente y se descontó; false y no toca nada si no alcanzaba.
func quitar_creditos(cantidad: int) -> bool:
	if cantidad <= 0:
		return true
	if _creditos_actuales < cantidad:
		return false
	_creditos_actuales -= cantidad
	creditos_cambiados.emit(_creditos_actuales)
	BusEventos.creditos_cambiados.emit(get_parent(), _creditos_actuales)
	return true


func tiene_creditos(cantidad: int) -> bool:
	return _creditos_actuales >= cantidad


func obtener_creditos() -> int:
	return _creditos_actuales


## Usado por ComponenteConfirmacionesRed._recibir_compra_red — fija el
## valor exacto que ya calculó el servidor, en vez de restar de nuevo del
## lado del cliente (evita cualquier desfasaje si alguna vez hay más de
## una fuente de cambio en vuelo a la vez).
func _fijar_creditos_local(valor: int) -> void:
	_creditos_actuales = valor
	creditos_cambiados.emit(_creditos_actuales)
	BusEventos.creditos_cambiados.emit(get_parent(), _creditos_actuales)
