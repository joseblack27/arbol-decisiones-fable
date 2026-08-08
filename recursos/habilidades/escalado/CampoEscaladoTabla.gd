extends CampoEscalado
class_name CampoEscaladoTabla
## Valores EXACTOS por nivel, sin fórmula — pensado para daño: el usuario
## define directo cuánto pega cada nivel (10-12 / 14-17 / 18-22...), sin
## tener que reversear un porcentaje compuesto para rebalancear más
## adelante. Para daño, se usan DOS instancias (una campo=DANO_MIN, otra
## campo=DANO_MAX) dentro del mismo EscaladoHabilidad.campos.

## valores_por_nivel[i] = valor exacto para el nivel (i+1) — índice 0 es
## nivel 1 (aunque nivel 1 normalmente ya sea el valor de fábrica, se
## puede repetir acá para que la tabla quede completa y explícita).
@export var valores_por_nivel: Array[float] = []


## Si se pide un nivel más allá de lo definido, se queda en el ÚLTIMO
## valor de la lista — no sigue creciendo solo ni revienta el índice.
func valor_para_nivel(nivel: int, valor_base):
	if valores_por_nivel.is_empty():
		return valor_base
	var indice: int = clampi(nivel - 1, 0, valores_por_nivel.size() - 1)
	var nuevo: float = valores_por_nivel[indice]
	return int(nuevo) if typeof(valor_base) == TYPE_INT else nuevo
