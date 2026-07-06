extends Resource
class_name MissionData

@export var id: String
@export var title: String

# Clasificación
@export var type: Enums.Mission.Type
@export var level_required: int = 1
@export var region: String

# Descripción
@export_multiline var description: String

# Objetivos
@export var objectives: Array[MissionObjectiveData] = []

# Recompensas
@export var rewards: MissionRewardData

# Estado actual
@export var status: Enums.Mission.Status = Enums.Mission.Status.LOCKED
