extends Node
## Catálogo de cofres del juego — llenado a mano en el Inspector (arrastrar
## .tres de DatosCofre). Autoload de ESCENA (no de script suelto): mismo
## motivo que GestorMisiones, "catalogo" necesita persistir un array de
## recursos y un autoload de .gd puro no tiene Inspector abrible.
##
## Necesario para reasociar la DEFINICIÓN de un cofre (tabla de botín
## incluida) a partir de un id — el progreso (ver CofresComponente) solo
## guarda ids de cofres ya abiertos, nunca el DatosCofre entero.

@export var catalogo: Array[DatosCofre] = []


func obtener_por_id(id_cofre: String) -> DatosCofre:
	if id_cofre == "":
		return null
	for datos in catalogo:
		if datos and datos.id == id_cofre:
			return datos
	return null
