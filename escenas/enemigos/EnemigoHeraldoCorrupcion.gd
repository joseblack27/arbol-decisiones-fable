extends "res://escenas/enemigos/EnemigoJefe.gd"
class_name EnemigoHeraldoCorrupcion
## Heraldo de la Corrupción: jefe de la rama "Corrupción" de la Mina. Mecánica
## de fases común en EnemigoJefe.gd, con tema de corrupción y veneno. El kit
## de fases 2 y 3 se reusa TAL CUAL de EnemigoGuardianQuebrado.gd, cuya fase
## "Corrupción" ya encaja: Golpe Corrupto aplica veneno y lentitud, Miedo
## empuja y aturde, Escudo Reflectante devuelve el daño bloqueado.

@export_group("Fase 2 - Corrupción Manifestándose")
@export var habilidad_golpe_corrupto_bt: HabilidadBT
@export var habilidad_muro_bt: HabilidadBT

@export_group("Fase 3 - Terror y Sombras")
@export var habilidad_miedo_bt: HabilidadBT
@export var habilidad_escudo_bt: HabilidadBT

@export_group("Fase 4 - Quiebre Final")
@export var habilidad_embestida_bt: HabilidadBT

var _refuerzos_fase4: Array[PackedScene] = [
	preload("res://escenas/enemigos/EnemigoLobo.tscn"),
	preload("res://escenas/enemigos/EnemigoAraña.tscn"),
]


func _ruta_embestida() -> String:
	return "Habilidades/HabilidadEmbestidaSombras"


func _reanudar_fase(fase: int) -> void:
	match fase:
		2:
			_agregar_habilidades_ataque([habilidad_golpe_corrupto_bt, habilidad_muro_bt])
		3:
			_agregar_habilidades_ataque([habilidad_miedo_bt, habilidad_escudo_bt])
		4:
			_agregar_habilidades_ataque([habilidad_embestida_bt])
			_invocar_refuerzos(_refuerzos_fase4)
			_activar_furia_final()
