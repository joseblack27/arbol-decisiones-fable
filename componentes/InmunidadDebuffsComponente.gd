extends Node
class_name InmunidadDebuffsComponente
## Ventana de inmunidad a debuffs temporales "pegados" (ver
## EfectoTemporalPegado) que deja HabilidadPurga después de limpiar los que
## ya tenías encima. Mientras esté activa, cualquier EfectoTemporalPegado
## nuevo que intente pegarse a esta entidad se descarta solo en su propio
## _ready() — nunca llega a aplicar nada (ver EfectoTemporalPegado._ready()).
##
## Puramente un contador — no toca energía, vida ni ningún otro sistema, así
## que no depende de ningún autoload y puede vivir en cualquier entidad
## (jugador o mob) sin arrastrar nada más.

var _restante: float = 0.0


func _process(delta: float) -> void:
	if _restante > 0.0:
		_restante = maxf(0.0, _restante - delta)


## Renovar ANTES de que vença (no sumar): dos Purgas seguidas no deberían
## acumular tiempo sin límite, solo estirar la ventana al valor pedido.
func activar(duracion: float) -> void:
	_restante = maxf(_restante, duracion)


func esta_activa() -> bool:
	return _restante > 0.0


func tiempo_restante() -> float:
	return _restante
