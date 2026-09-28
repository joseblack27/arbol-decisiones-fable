extends "res://escenas/enemigos/EnemigoJefe.gd"
class_name EnemigoReinaHormigas
## Reina de las Hormigas: jefa final del Hormiguero. Mecánica de fases común
## en EnemigoJefe.gd (umbrales 0.75/0.50/0.25, golpe de transición, furia
## final), con kit propio:
##   Desde el arranque: Mordida (golpe básico) + Pisotón Sísmico (área
##     telegrafiada centrada en ella, castiga quedarse en melee).
##   Fase 2: Escupitajo Ácido (área) + Marca de la Colonia (marca a un jugador
##     cercano al azar y detona sobre él y quien esté al lado, ver
##     HabilidadMarcaColonia.gd).
##   Fase 3: Llamada de Auxilio (ver HabilidadLlamadaAuxilio.gd) + Puesta de
##     Huevos (huevos que, si sobreviven, eclosionan en hormigas guardianas que
##     le dan resistencia mientras vivan, ver HabilidadPuestaHuevos.gd).
##   Fase 4: Embestida (carga, con la animación MORDIDA_PREPARACION/
##     MORDIDA_DASH heredada del esqueleto del Lobo Feroz; el nombre viene del
##     lobo, no de la habilidad Mordida) + refuerzos + furia.

@export_group("Fase 2 - Ácido de la Colonia")
@export var habilidad_escupitajo_bt: HabilidadBT
@export var habilidad_marca_colonia_bt: HabilidadBT

@export_group("Fase 3 - Instinto de Enjambre")
@export var habilidad_llamada_auxilio_bt: HabilidadBT
@export var habilidad_puesta_huevos_bt: HabilidadBT

@export_group("Fase 4 - Furia de la Reina")
@export var habilidad_embestida_bt: HabilidadBT

## Mientras tenga a alguien detectado, su radio de visión se duplica; al
## quedarse sin nadie vuelve al original (ver _ajustar_radio_deteccion()). Si
## no, con alejarse un poco del radio de VisionComponente ya perdía al
## jugador.
const MULTIPLICADOR_RADIO_DETECCION_CON_OBJETIVO := 2.0
var _radio_deteccion_base: float = 0.0

var _refuerzos_fase4: Array[PackedScene] = [
	preload("res://escenas/enemigos/EnemigoHormigaObrera.tscn"),
	preload("res://escenas/enemigos/EnemigoHormigaObrera.tscn"),
	preload("res://escenas/enemigos/EnemigoHormigaSoldado.tscn"),
]


func _init() -> void:
	dano_golpe_transicion = 45.0


func _ready() -> void:
	super._ready()
	_preparar_radio_deteccion()


func _ruta_embestida() -> String:
	return "Habilidades/HabilidadEmbestidaReina"


func _reanudar_fase(fase: int) -> void:
	match fase:
		2:
			_agregar_habilidades_ataque([habilidad_escupitajo_bt, habilidad_marca_colonia_bt])
		3:
			_agregar_habilidades_ataque([habilidad_llamada_auxilio_bt, habilidad_puesta_huevos_bt])
		4:
			_agregar_habilidades_ataque([habilidad_embestida_bt])
			_invocar_refuerzos(_refuerzos_fase4)
			_activar_furia_final()


## Duplica la forma ANTES de guardar el radio base -- es un sub_resource
## compartido en la escena empaquetada (CircleShape2D_itdr7), así que
## tocar .radius directo sin duplicar afectaría a CUALQUIER OTRA Reina
## que llegue a existir a la vez (ej. dos niveles de Hormiguero cargados
## juntos en una prueba) -- mismo criterio que otros duplicate() de forma
## en este proyecto (ver HabilidadParpadeo._forma_colision_de).
func _preparar_radio_deteccion() -> void:
	var forma := _forma_deteccion()
	if forma == null:
		return
	var col := componente_vision.get_node("CollisionShape2D") as CollisionShape2D
	col.shape = forma.duplicate()
	_radio_deteccion_base = (col.shape as CircleShape2D).radius


func _forma_deteccion() -> CircleShape2D:
	if componente_vision == null:
		return null
	var col := componente_vision.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col == null or not (col.shape is CircleShape2D):
		return null
	return col.shape as CircleShape2D


## Mientras siga habiendo AL MENOS un jugador detectado, radio doble; en
## cuanto se queda sin ninguno, vuelve al radio original -- ver el
## comentario grande de MULTIPLICADOR_RADIO_DETECCION_CON_OBJETIVO.
func _ajustar_radio_deteccion(con_objetivo: bool) -> void:
	if _radio_deteccion_base <= 0.0:
		return
	var forma := _forma_deteccion()
	if forma == null:
		return
	forma.radius = _radio_deteccion_base * MULTIPLICADOR_RADIO_DETECCION_CON_OBJETIVO if con_objetivo \
		else _radio_deteccion_base


func _on_objetivo_detectado(area: Area2D) -> void:
	var ya_tenia: bool = memoria.obtener("jugador_detectado", false) if memoria else false
	super._on_objetivo_detectado(area)
	if not ya_tenia:
		_ajustar_radio_deteccion(true)


func _on_objetivo_perdido(area: Area2D) -> void:
	super._on_objetivo_perdido(area)
	var sigue_detectando: bool = memoria.obtener("jugador_detectado", false) if memoria else false
	if not sigue_detectando:
		_ajustar_radio_deteccion(false)


## La misma animación MORDIDA_PREPARACION/MORDIDA_DASH que trae el esqueleto
## del Lobo Feroz del que se reskineó esta escena (ver
## EnemigoLobo._on_carga_preparacion/_on_carga_iniciada/_on_carga_terminada;
## copiada acá porque la Reina no hereda de EnemigoLobo).
func _on_embestida_preparacion() -> void:
	if componente_animacion:
		componente_animacion.establecer_condicion("parameters/conditions/debeMordidaPrep", true)
		componente_animacion.viajar_a_estado("MORDIDA_PREPARACION")


func _on_embestida_iniciada(_direccion: Vector2, _multiplicador: float) -> void:
	if componente_animacion:
		componente_animacion.establecer_condicion("parameters/conditions/debeMordidaPrep", false)
		componente_animacion.establecer_condicion("parameters/conditions/debeMordidaDash", true)
		componente_animacion.viajar_a_estado("MORDIDA_DASH")


func _on_embestida_terminada() -> void:
	if memoria:
		memoria.establecer("ataque_en_curso", false)
	if componente_animacion:
		componente_animacion.establecer_condicion("parameters/conditions/debeMordidaDash", false)
		componente_animacion.establecer_condicion("parameters/conditions/debeSalirMordida", true)
		componente_animacion.establecer_condicion("parameters/conditions/debeIdle", true)
