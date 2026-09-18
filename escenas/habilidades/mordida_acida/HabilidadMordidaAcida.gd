class_name HabilidadMordidaAcida
extends HabilidadBase
## Wrapper de MordidaAcida — golpe cuerpo a cuerpo de área que además pega
## veneno + lentitud (ver esa clase). Segunda habilidad de las hormigas
## (junto a HabilidadGolpeBasico, la "Mordida" simple).

@export var daño: float = 6.0
## OJO: alcance real = alcance_golpe + radio_golpe (mismo criterio que
## HabilidadGolpeCorruptoGuardian.alcance_golpe).
@export var alcance_golpe: float = 40.0
@export var radio_golpe: float = 40.0
@export var duracion_golpe: float = 0.15
@export var escena_golpe: PackedScene = preload("res://escenas/habilidades/mordida_acida/MordidaAcida.tscn")

@export_group("Veneno + Lentitud")
@export var dano_por_tick: float = 3.0
@export var intervalo_tick: float = 1.0
@export var duracion_veneno: float = 4.0
## 0.8 = -20% de velocidad.
@export var factor_lentitud: float = 0.8
@export var duracion_lentitud: float = 4.0


func _ready() -> void:
	super._ready()
	nombre_habilidad = "Mordida Ácida"
	tipo_habilidad   = "mordida_acida"


func _ejecutar(direccion: Vector2, _poder: float) -> void:
	if not is_instance_valid(entidad_dueña):
		return
	var golpe := GestorPiscinas.obtener(escena_golpe) as MordidaAcida
	var frente := direccion if direccion.length() > 0.1 else Vector2.RIGHT
	var posicion: Vector2 = (entidad_dueña as Node2D).global_position + frente * alcance_golpe
	golpe.global_position = posicion
	golpe.configurar(_calcular_dano(int(daño)), radio_golpe, entidad_dueña, duracion_golpe, tipo_dano)
	golpe.dano_por_tick = dano_por_tick
	golpe.intervalo_tick = intervalo_tick
	golpe.duracion_veneno = duracion_veneno
	golpe.factor_lentitud = factor_lentitud
	golpe.duracion_lentitud = duracion_lentitud
	_mostrar_indicador_golpe(posicion)
	_reproducir_sonido()


func _mostrar_indicador_golpe(posicion: Vector2) -> void:
	if not is_instance_valid(entidad_dueña):
		return
	var indicador := IndicadorZonaEfecto.new()
	indicador.radio = radio_golpe
	indicador.color_relleno = Color(0.4, 0.85, 0.2, 0.35)
	indicador.color_borde   = Color(0.5, 1.0, 0.25, 0.9)
	(entidad_dueña as Node2D).get_tree().current_scene.add_child(indicador)
	indicador.global_position = posicion
