extends Resource
class_name DatosObjetivoMision
## Definición de un objetivo — sin estado de progreso (ver DatosMision
## para el porqué). El progreso real (cantidad actual) vive en
## MisionesComponente.progreso, por jugador.

@export var id: String
@export var descripcion: String

@export var tipo: Enums.Mision.TipoObjetivo = Enums.Mision.TipoObjetivo.MATAR
## Qué matchea este objetivo, según "tipo":
##   MATAR: EnemigoDatos.obtener_id() del enemigo a matar.
##   RECOLECTAR: DatosItem.name del ítem a juntar.
##   HABLAR: Npc.id del NPC con el que hay que hablar.
@export var id_meta: String
@export var cantidad_meta: int = 1
