extends Resource
class_name CampoEscalado
## Base abstracta: UN campo de una habilidad que crece con el nivel de
## mejora (ver EscaladoHabilidad/HabilidadBase.aplicar_nivel_mejora). Cada
## instancia real es una subclase concreta — CampoEscaladoPorcentaje
## (fórmula) o CampoEscaladoTabla (valores exactos por nivel, para
## rebalancear sin pelear con una fórmula).

## Campo CONCEPTUAL a escalar (ver Enums.Habilidad.CampoEscalable) — el
## enum evita errores de tipeo; HabilidadBase._nombre_campo_escalable()
## traduce esto al nombre real de la propiedad en cada habilidad.
@export var campo: Enums.Habilidad.CampoEscalable = Enums.Habilidad.CampoEscalable.DANO_MIN

## Alternativa a "campo" de arriba, para bonos de combate (potencia,
## crítico...) — ver Enums.Habilidad.AtributoEscalable. Si esto NO es
## NINGUNO, HabilidadBase lo usa en vez de "campo" (y no hace falta ningún
## override por habilidad, ver ese enum). Pedido del usuario: no tener que
## "descifrar" a qué propiedad real corresponde un campo genérico
## reutilizado (RANGO/RADIO/DURACION_EFECTO/PORCENTAJE_EFECTO) mirando el
## script de cada habilidad.
@export var campo_atributo: Enums.Habilidad.AtributoEscalable = Enums.Habilidad.AtributoEscalable.NINGUNO


## Sobreescribir en subclases. [valor_base] es el valor de fábrica (nivel
## 1, capturado por HabilidadBase.preparar_escalado). [nivel] va de 1 a
## EscaladoHabilidad.nivel_maximo.
func valor_para_nivel(_nivel: int, valor_base):
	return valor_base
