extends Resource
class_name DatosMision

@export var id: String
@export var title: String

# Clasificación (0=HISTORIA,1=SECUNDARIA,2=EVENTO,3=DIARIA)
@export var type: int = 0
@export var level_required: int = 1
@export var region: String

@export_multiline var description: String

@export var objectives: Array[DatosObjetivoMision] = []
@export var rewards: DatosRecompensaMision

# Estado (0=LOCKED,1=AVAILABLE,2=IN_PROGRESS,3=COMPLETED,4=FAILED)
@export var status: int = 0
