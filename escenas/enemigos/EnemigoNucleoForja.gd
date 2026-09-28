extends "res://escenas/enemigos/EnemigoJefe.gd"
class_name EnemigoNucleoForja
## Núcleo de la Forja: jefe de la rama "Forja de Fuego" de la Mina. Misma
## mecánica de fases que el resto (ver EnemigoJefe.gd); el kit reusa
## habilidades genéricas con tema de fuego y forja.

@export_group("Fase 2 - Corazón Ardiente")
@export var habilidad_barrido_bt: HabilidadBT
@export var habilidad_muro_bt: HabilidadBT

@export_group("Fase 3 - Furia de la Forja")
@export var habilidad_terremoto_bt: HabilidadBT
@export var habilidad_combo_bt: HabilidadBT

@export_group("Fase 4 - Quiebre Final")
@export var habilidad_embestida_bt: HabilidadBT

var _refuerzos_fase4: Array[PackedScene] = [
	preload("res://escenas/enemigos/EnemigoLobo.tscn"),
	preload("res://escenas/enemigos/EnemigoAraña.tscn"),
]


func _ruta_embestida() -> String:
	return "Habilidades/HabilidadEmbestidaForja"


func _reanudar_fase(fase: int) -> void:
	match fase:
		2:
			_agregar_habilidades_ataque([habilidad_barrido_bt, habilidad_muro_bt])
		3:
			_agregar_habilidades_ataque([habilidad_terremoto_bt, habilidad_combo_bt])
		4:
			_agregar_habilidades_ataque([habilidad_embestida_bt])
			_invocar_refuerzos(_refuerzos_fase4)
			_activar_furia_final()
