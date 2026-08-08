extends CampoEscalado
class_name CampoEscaladoPorcentaje
## Crecimiento por FÓRMULA — pensado para campos donde una curva simple
## alcanza (rango, recarga, radio...). Para daño, donde el usuario quiere
## control exacto para rebalancear a futuro, ver CampoEscaladoTabla.

## +10%/nivel adicional por defecto. NEGATIVO para que el campo BAJE con
## el nivel (ej. -0.05 en RECARGA: cada nivel recarga un 5% más rápido).
@export var porcentaje_por_nivel: float = 0.10


func valor_para_nivel(nivel: int, valor_base):
	var nuevo = valor_base * (1.0 + (nivel - 1) * porcentaje_por_nivel)
	return int(nuevo) if typeof(valor_base) == TYPE_INT else nuevo
