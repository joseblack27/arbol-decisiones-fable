extends Node
class_name EnergiaComponente
## Componente de energía reutilizable para jugador y enemigos.
## Colócalo como hijo de la entidad. La energía se regenera pasivamente con el tiempo.

signal energia_cambiada(nueva: float, maxima: float)
signal energia_agotada()

@export_group("Energía")
@export var energia_maxima: float       = 100.0
@export var regeneracion_por_segundo: float = 15.0

var _energia_actual: float = 0.0


func _ready() -> void:
	_energia_actual = energia_maxima


func _process(delta: float) -> void:
	if _energia_actual < energia_maxima:
		_energia_actual = minf(_energia_actual + regeneracion_por_segundo * delta, energia_maxima)
		energia_cambiada.emit(_energia_actual, energia_maxima)
		BusEventos.energia_cambiada.emit(get_parent(), _energia_actual, energia_maxima)


# =============================================================================
# API pública
# =============================================================================

## Intenta consumir cantidad. Devuelve true si había suficiente.
func consumir(cantidad: float) -> bool:
	if cantidad <= 0.0:
		return true
	if _energia_actual < cantidad:
		energia_agotada.emit()
		return false
	_energia_actual -= cantidad
	energia_cambiada.emit(_energia_actual, energia_maxima)
	BusEventos.energia_cambiada.emit(get_parent(), _energia_actual, energia_maxima)
	return true


func tiene_energia(cantidad: float) -> bool:
	return _energia_actual >= cantidad


func agregar_energia(cantidad: float) -> void:
	_energia_actual = minf(_energia_actual + cantidad, energia_maxima)
	energia_cambiada.emit(_energia_actual, energia_maxima)
	BusEventos.energia_cambiada.emit(get_parent(), _energia_actual, energia_maxima)


func obtener_energia() -> float:
	return _energia_actual


func obtener_energia_maxima() -> float:
	return energia_maxima


func obtener_fraccion() -> float:
	return _energia_actual / energia_maxima if energia_maxima > 0.0 else 0.0
