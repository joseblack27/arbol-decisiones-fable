extends Resource
class_name DatosMision
## Definición/plantilla de una misión — NO guarda progreso (ver el porqué
## en MisionesComponente: mutar "status" acá directo mutaría el MISMO
## Resource compartido entre el catálogo y el progreso de cada jugador,
## mismo riesgo que InventarioComponente.agregar_item() ya evita con
## .duplicate()). El progreso real vive aparte, por jugador, en
## MisionesComponente.progreso, indexado por "id".

@export var id: String
@export var titulo: String

@export var tipo: Enums.Mision.Tipo = Enums.Mision.Tipo.HISTORIA
@export var nivel_requerido: int = 1
@export var region: String

@export_multiline var descripcion: String

@export var objetivos: Array[DatosObjetivoMision] = []
@export var recompensas: DatosRecompensaMision

## true = al completarla (ver MisionesComponente._completar_mision_local)
## el progreso se borra en vez de quedar en COMPLETADA — vuelve a poder
## aceptarse como si fuera la primera vez, para siempre.
@export var repetible: bool = false

## true = los objetivos se cumplen EN EL ORDEN del array (ver
## MisionesComponente.objetivo_habilitado): el objetivo N recién puede
## empezar a acreditar progreso cuando el N-1 ya llegó a su cantidad_meta.
## Pensado para misiones "por fases" (ej. matar 3 arañas y DESPUÉS a la
## Araña Reina) — con false (default) todos los objetivos progresan en
## paralelo, como ya hacían las misiones existentes.
@export var secuencial: bool = false
