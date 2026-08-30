class_name HabilidadFrancotiradorGuardian
extends HabilidadProyectil
## Disparo cargado de largo alcance: el Guardián Quebrado se detiene,
## "carga" el tiro (pose del AnimationTree, estado CARGANDO) durante
## duracion_pose_ataque segundos, y recién al terminar sale el proyectil de
## verdad — mismo mecanismo de pose+timer+reapuntado continuo que
## HabilidadFlechaArquero.gd (ver ese archivo para el porqué completo de
## cada pieza), adaptado al Guardián en vez del Esqueleto Arquero.
##
## Agrega, además, un retículo de advertencia (IndicadorZonaEfecto) en la
## posición del objetivo mientras dura la carga — sin precedente en
## HabilidadFlechaArquero, pero necesario acá: un disparo de "alto daño,
## un solo punto lejano" sin marcar dónde va a caer sería invisible de
## esquivar hasta que ya es tarde.

## Cuánto dura la pose antes de que salga el disparo — deliberadamente
## largo (telegraph "largo, alto daño", pedido del diseño), a diferencia
## del 1.2s del arquero normal.
@export var duracion_pose_ataque: float = 1.8
## Radio del retículo de advertencia — debería coincidir con el radio real
## de daño del proyectil/su efecto de impacto, si tuviera uno.
@export var radio_reticulo: float = 40.0

var _id_disparo := 0
var _en_pose := false
var _reticulo: IndicadorZonaEfecto = null


func _ready() -> void:
	super._ready()
	nombre_habilidad = "Francotirador"
	tipo_habilidad   = "francotirador_guardian"


func _ejecutar(direccion: Vector2, poder: float) -> void:
	if not is_instance_valid(entidad_dueña):
		return
	_id_disparo += 1
	var id_esta_preparacion := _id_disparo
	_en_pose = true

	if "memoria" in entidad_dueña:
		entidad_dueña.get("memoria").establecer("ataque_en_curso", true)

	var animacion: AnimacionComponente = null
	if "componente_animacion" in entidad_dueña:
		animacion = entidad_dueña.componente_animacion
	if animacion:
		animacion.establecer_condicion("parameters/conditions/debeCargando", true)
		animacion.establecer_condicion("parameters/conditions/debeIdle", false)
		animacion.viajar_a_estado("CARGANDO")

	_mostrar_reticulo()

	get_tree().create_timer(duracion_pose_ataque).timeout.connect(
		_al_terminar_pose.bind(id_esta_preparacion, direccion, poder, animacion)
	)


## Reapuntado continuo y retículo siguiendo al objetivo mientras dura la
## pose — mismo criterio que HabilidadFlechaArquero: sin esto, sería muy
## fácil esquivarlo simplemente moviéndose apenas empieza la carga.
func _process(delta: float) -> void:
	super._process(delta)
	if not _en_pose or not is_instance_valid(entidad_dueña) or not ("memoria" in entidad_dueña):
		return
	var objetivo_raw = entidad_dueña.get("memoria").obtener("objetivo")
	if not is_instance_valid(objetivo_raw) or not (objetivo_raw is Node2D):
		return
	var objetivo := objetivo_raw as Node2D
	var hacia_objetivo: Vector2 = objetivo.global_position - entidad_dueña.global_position
	if hacia_objetivo.length() > 0.1 and "direccion_mirada" in entidad_dueña:
		entidad_dueña.direccion_mirada = hacia_objetivo.normalized()
	if _reticulo and is_instance_valid(_reticulo):
		_reticulo.global_position = objetivo.global_position


func _mostrar_reticulo() -> void:
	if not is_instance_valid(entidad_dueña) or not (entidad_dueña is Node2D):
		return
	var objetivo_raw = entidad_dueña.get("memoria").obtener("objetivo") if "memoria" in entidad_dueña else null
	var posicion: Vector2 = (objetivo_raw as Node2D).global_position \
		if is_instance_valid(objetivo_raw) and objetivo_raw is Node2D \
		else (entidad_dueña as Node2D).global_position
	_reticulo = IndicadorZonaEfecto.new()
	_reticulo.radio = radio_reticulo
	_reticulo.color_relleno = Color(1.0, 0.15, 0.1, 0.35)
	_reticulo.color_borde = Color(1.0, 0.2, 0.15, 0.95)
	_reticulo.duracion = duracion_pose_ataque
	(entidad_dueña as Node2D).get_tree().current_scene.add_child(_reticulo)
	_reticulo.global_position = posicion


func _al_terminar_pose(id_esta_preparacion: int, direccion: Vector2, poder: float, animacion: AnimacionComponente) -> void:
	if id_esta_preparacion != _id_disparo or not is_instance_valid(entidad_dueña):
		return
	_en_pose = false
	if "memoria" in entidad_dueña:
		entidad_dueña.get("memoria").establecer("ataque_en_curso", false)
	if animacion and is_instance_valid(animacion):
		animacion.establecer_condicion("parameters/conditions/debeCargando", false)
		animacion.establecer_condicion("parameters/conditions/debeIdle", true)
	var direccion_final := direccion
	if "direccion_mirada" in entidad_dueña:
		var mirada: Vector2 = entidad_dueña.direccion_mirada
		if mirada != Vector2.ZERO:
			direccion_final = mirada
	super._ejecutar(direccion_final, poder)
