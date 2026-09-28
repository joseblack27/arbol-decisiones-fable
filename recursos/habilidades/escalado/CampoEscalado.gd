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

## Alternativa a "campo" para bonos de combate (ver Enums.Atributos.Campo,
## espejo de los campos de AtributosBase). Si NO es NINGUNO, HabilidadBase lo
## usa en vez de "campo", sin traducción a mano ni override por habilidad: el
## nombre real sale por reflexión del enum (ver
## HabilidadBase._nombre_campo_de). Así un atributo nuevo solo toca Enums.
@export var campo_atributo: Enums.Atributos.Campo = Enums.Atributos.Campo.NINGUNO


## Sobreescribir en subclases. [valor_base] es el valor de fábrica (nivel
## 1, capturado por HabilidadBase.preparar_escalado). [nivel] va de 1 a
## EscaladoHabilidad.nivel_maximo.
func valor_para_nivel(_nivel: int, valor_base):
	return valor_base
