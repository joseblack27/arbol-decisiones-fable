extends Resource
class_name EscaladoHabilidad
## Configuración de "nivel de mejora" de UNA habilidad activa (ver
## DatosHabilidad.escalado, HabilidadBase.aplicar_nivel_mejora y
## MejorasComponente). Reusable: varias habilidades pueden apuntar al MISMO
## EscaladoHabilidad para compartir la curva, en vez de repetir los números en
## cada .tres.
##
## null en DatosHabilidad.escalado = la habilidad no tiene mejora configurada.

@export var campos: Array[CampoEscalado] = []
@export var nivel_maximo: int = 5
@export var costo_puntos_por_nivel: int = 1


## Valor que tendría [campo] en [nivel] según ESTE escalado — para mostrar
## en UI (ver PanelDetalleHabilidad) sin necesitar una instancia viva de la
## habilidad (el catálogo puede listar una que ni siquiera está equipada).
## [valor_base] se devuelve tal cual si [campo] no está configurado acá.
func valor_para_campo(campo: Enums.Habilidad.CampoEscalable, nivel: int, valor_base):
	for c in campos:
		if c.campo == campo:
			return c.valor_para_nivel(nivel, valor_base)
	return valor_base
