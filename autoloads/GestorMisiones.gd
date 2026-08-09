extends Node
## Catálogo de misiones del juego — llenado a mano en el Inspector (arrastrar
## .tres de DatosMision). Autoload de ESCENA (no de script suelto): un
## autoload de .gd puro no tiene Inspector abrible en el editor, y "catalogo"
## necesita persistir un array de recursos — mismo criterio que GestorCarga.
##
## Necesario para reasociar la DEFINICIÓN de una misión a partir de un id
## guardado (el progreso, ver MisionesComponente, solo guarda ids — no
## serializa el DatosMision entero).

@export var catalogo: Array[DatosMision] = []


func obtener_por_id(id_mision: String) -> DatosMision:
	if id_mision == "":
		return null
	for datos in catalogo:
		if datos and datos.id == id_mision:
			return datos
	return null
