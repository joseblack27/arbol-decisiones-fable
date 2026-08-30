class_name HabilidadGolpeCorruptoGuardian
extends HabilidadBase
## Wrapper de GolpeCorruptoGuardian — golpe cuerpo a cuerpo de área que
## además aplica veneno o lentitud (ver esa clase). Fase "Corrupción".

@export var daño: float = 16.0
## OJO: alcance real = alcance_golpe + radio_golpe — HabilidadBT.
## rango_maximo en GolpeCorruptoGuardian.tres tiene que quedar <= esa suma
## (mismo criterio documentado en HabilidadComboGuardian.alcance_golpe).
@export var alcance_golpe: float = 60.0
@export var radio_golpe: float = 60.0
@export var duracion_golpe: float = 0.15
@export var escena_golpe: PackedScene = preload("res://escenas/habilidades/golpe_corrupto_guardian/GolpeCorruptoGuardian.tscn")


func _ready() -> void:
	super._ready()
	nombre_habilidad = "Golpe Corrupto"
	tipo_habilidad   = "golpe_corrupto_guardian"


func _ejecutar(direccion: Vector2, _poder: float) -> void:
	if not is_instance_valid(entidad_dueña):
		return
	var golpe := GestorPiscinas.obtener(escena_golpe) as GolpeCorruptoGuardian
	var frente := direccion if direccion.length() > 0.1 else Vector2.RIGHT
	var posicion: Vector2 = (entidad_dueña as Node2D).global_position + frente * alcance_golpe
	golpe.global_position = posicion
	golpe.configurar(_calcular_dano(int(daño)), radio_golpe, entidad_dueña, duracion_golpe, tipo_dano)
	_mostrar_indicador_golpe(posicion)


func _mostrar_indicador_golpe(posicion: Vector2) -> void:
	if not is_instance_valid(entidad_dueña):
		return
	var indicador := IndicadorZonaEfecto.new()
	indicador.radio = radio_golpe
	indicador.color_relleno = Color(0.5, 0.9, 0.2, 0.35)
	indicador.color_borde   = Color(0.6, 1.0, 0.25, 0.9)
	(entidad_dueña as Node2D).get_tree().current_scene.add_child(indicador)
	indicador.global_position = posicion
