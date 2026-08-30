class_name HabilidadGolpeVerdaderoGuardian
extends HabilidadBase
## Golpe único, cuerpo a cuerpo, que el parry de HabilidadCorte NO bloquea
## (ver GolpeVerdaderoGuardian.gd para el porqué). La usa el Guardián
## Quebrado en tres momentos distintos, con la MISMA escena: el amague de
## fase 1 (cuando cancela el barrido), el castigo por cooldown de fase 3, y
## el golpe de transición al cruzar cada umbral de vida.

@export var daño: float = 20.0
## OJO: alcance real = alcance_golpe + radio_golpe — cuando esta instancia
## se usa vía SelectorHabilidades (el castigo por cooldown de Corte, ver
## CastigoGuardian.tres), su HabilidadBT.rango_maximo tiene que quedar <=
## esa suma (mismo criterio documentado en HabilidadComboGuardian
## .alcance_golpe). La instancia de transición de fase no pasa por el
## selector (se activa directo desde EnemigoGuardianQuebrado._golpear_
## transicion), así que a ESA no le aplica este límite.
@export var alcance_golpe: float = 56.0
@export var radio_golpe: float = 56.0
@export var duracion_golpe: float = 0.15
## true solo en la instancia de fase 4 (arremetida/transición tardía).
@export var ignora_defensa: bool = false
@export var escena_golpe: PackedScene = preload("res://escenas/habilidades/golpe_verdadero_guardian/GolpeVerdaderoGuardian.tscn")


func _ready() -> void:
	super._ready()
	nombre_habilidad = "Golpe Verdadero"
	tipo_habilidad   = "golpe_verdadero_guardian"


func _ejecutar(direccion: Vector2, _poder: float) -> void:
	if not is_instance_valid(entidad_dueña):
		return
	var golpe := GestorPiscinas.obtener(escena_golpe) as GolpeVerdaderoGuardian
	var frente := direccion if direccion.length() > 0.1 else Vector2.RIGHT
	var posicion: Vector2 = (entidad_dueña as Node2D).global_position + frente * alcance_golpe
	golpe.global_position = posicion
	golpe.configurar(_calcular_dano(int(daño)), radio_golpe, entidad_dueña, duracion_golpe, tipo_dano, ignora_defensa)
	_mostrar_indicador_golpe(posicion)


## Rojo intenso — distinto del naranja de golpes normales y del blanco de
## Corte: esto es "no lo podés parar", una lectura visual propia.
func _mostrar_indicador_golpe(posicion: Vector2) -> void:
	if not is_instance_valid(entidad_dueña):
		return
	var indicador := IndicadorZonaEfecto.new()
	indicador.radio = radio_golpe
	indicador.color_relleno = Color(0.9, 0.15, 0.15, 0.4)
	indicador.color_borde   = Color(1.0, 0.2, 0.2, 0.95)
	(entidad_dueña as Node2D).get_tree().current_scene.add_child(indicador)
	indicador.global_position = posicion
