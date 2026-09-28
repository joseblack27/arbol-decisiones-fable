extends "res://escenas/enemigos/EnemigoJefe.gd"
class_name EnemigoCorazonCristal
## Jefe de 4 fases al fondo de la Mina de Cristal. Mecánica de fases común en
## EnemigoJefe.gd; el KIT reusa habilidades genéricas que ya existen (Golpe
## Básico, Arañazo, Proyectil, Área de Efecto, Muro, Sacudida, Carga) con tema
## de cristal, en vez de una habilidad a medida por fase.
##
## Fase 1 "Cristalización" (Golpe + Zarpazo, cuerpo a cuerpo).
## Fase 2 "Fractura" (<75%): suma Lluvia de Esquirlas (proyectil a
## distancia) y Erupción de Cristal (área).
## Fase 3 "Resonancia" (<50%): suma Muro de Cristal (bloquea la sala) y
## Pulso de Cristal (aturde en área corta; el mismo Sacudida.gd de la Araña
## Reina).
## Fase 4 "Quiebre Final" (<25%): suma Embestida de Cristal (carga de daño
## verdadero, la misma HabilidadCarga.gd base que ArremetidaGuardian), invoca
## refuerzos y aplica furia final (recarga más rápida, permanente).

@export_group("Fase 2 - Fractura")
@export var habilidad_esquirlas_bt: HabilidadBT
@export var habilidad_erupcion_bt: HabilidadBT

@export_group("Fase 3 - Resonancia")
@export var habilidad_muro_bt: HabilidadBT
@export var habilidad_pulso_bt: HabilidadBT

@export_group("Fase 4 - Quiebre Final")
@export var habilidad_embestida_bt: HabilidadBT

var _refuerzos_fase4: Array[PackedScene] = [
	preload("res://escenas/enemigos/EnemigoLobo.tscn"),
	preload("res://escenas/enemigos/EnemigoAraña.tscn"),
]


func _ruta_embestida() -> String:
	return "Habilidades/HabilidadEmbestidaCristal"


func _reanudar_fase(fase: int) -> void:
	match fase:
		2:
			_agregar_habilidades_ataque([habilidad_esquirlas_bt, habilidad_erupcion_bt])
		3:
			_agregar_habilidades_ataque([habilidad_muro_bt, habilidad_pulso_bt])
		4:
			_agregar_habilidades_ataque([habilidad_embestida_bt])
			_invocar_refuerzos(_refuerzos_fase4)
			_activar_furia_final()
