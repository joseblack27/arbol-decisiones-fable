extends Resource
class_name LineaDialogo
## Una línea dentro de un DatosDialogo. Sin "opciones", PanelDialogo avanza
## sola a la línea siguiente (índice + 1) al tocar "continuar"; con
## "opciones", muestra un botón por cada una en vez de avanzar sola.

@export var hablante: String = ""
@export_multiline var texto: String = ""
@export var opciones: Array[OpcionDialogo] = []

## A dónde salta "continuar" cuando ESTA línea no tiene opciones. -1
## (default) = comportamiento de siempre, cae a índice + 1. Pensado para
## una línea de cierre compartida por varias ramas (ej. "¡Gracias! Volvé
## cuando termines." después de aceptar cualquier misión de un NPC con
## varias) que necesita volver al MENÚ del NPC en vez de a lo que sea que
## venga después en el array — sin esto, agregar más líneas más adelante
## rompe en silencio el flujo de cualquier línea de cierre anterior (bug
## real: aceptar una misión y tocar Continuar mostraba la oferta de OTRA
## misión, porque esa pasó a ser "índice + 1").
@export var siguiente_linea: int = -1
