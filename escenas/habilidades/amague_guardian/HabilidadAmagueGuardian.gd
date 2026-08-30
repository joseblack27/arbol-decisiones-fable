class_name HabilidadAmagueGuardian
extends HabilidadBase
## Arranca la MISMA pose visual que HabilidadBarridoGuardian (estado
## "BARRIDO" del AnimationTree, indistinguible a simple vista) y, recién al
## terminar la pose, decide — por probabilidad, sesgada hacia el golpe único
## si Corte del jugador objetivo está en cooldown — si termina siendo un
## barrido de ÁREA real (parriable) o un GolpeVerdaderoGuardian de un solo
## golpe (NO parriable). Pedido explícito del usuario: "un amague que
## cancela a un golpe único que Corte no bloquea — enseña que Corte no es
## invencibilidad total".
##
## No repite el timer de pose ni telegrafía dos veces: HabilidadBarridoGuardian
## .golpear() es estático justo para que este script pueda entregar el golpe
## YA resuelto al final de SU PROPIA pose, sin instanciar otra HabilidadBase.
## El golpe único usa GolpeVerdaderoGuardian directo (la hitbox pooled), sin
## pasar por el wrapper HabilidadGolpeVerdaderoGuardian — por el mismo motivo:
## ese wrapper telegrafiaría una pose propia si se llamara a su _ejecutar().
##
## Sin .tscn propio — habilidad de MOB, se agrega como script node directo
## dentro de EnemigoGuardianQuebrado.tscn (ver HabilidadComboGuardian).

@export_group("Amague")
## OJO al tocar esto: mismo criterio que HabilidadBarridoGuardian.largo —
## HabilidadBT.rango_maximo en AmagueGuardian.tres tiene que quedar <= este
## valor, si no la IA elige atacar desde más lejos de lo que el rectángulo
## (rama barrido) o radio_golpe_verdadero (rama golpe único) llegan a cubrir.
@export var largo: float = 150.0
@export var ancho: float = 90.0
@export var dano_barrido: float = 18.0
@export var dano_golpe_verdadero: float = 20.0
@export var radio_golpe_verdadero: float = 56.0
@export var duracion_pose: float = 0.6
## Probabilidad BASE (0..1) de que el amague termine en golpe único — sube
## si Corte del objetivo está en cooldown (ver _probabilidad_golpe_unico).
@export var probabilidad_golpe_unico: float = 0.35
@export var deja_charco: bool = false
@export var escena_golpe_verdadero: PackedScene = preload("res://escenas/habilidades/golpe_verdadero_guardian/GolpeVerdaderoGuardian.tscn")

var _id_ataque := 0
## true mientras dura la pose — gatilla el reapuntado continuo en
## _process(), mismo mecanismo que HabilidadBarridoGuardian/
## HabilidadFrancotiradorGuardian.
var _en_pose := false
## Mismo indicador que HabilidadBarridoGuardian (rectángulo largo/ancho) —
## bug real reportado: "los amagues tampoco muestran el area de golpe".
## A propósito se usa SIEMPRE la forma del rectángulo (nunca el círculo
## más chico del golpe único), sea cual sea la rama que termine saliendo:
## el golpe único cae dentro de esa misma franja frontal (radio_golpe_
## verdadero < largo), así que mostrarla no delata por adelantado cuál de
## las dos ramas va a resolver — solo avisa POR DÓNDE, que es lo que pidió
## el usuario, sin arruinar el bluff del amague.
var _indicador_area: IndicadorZonaEfecto = null


func _ready() -> void:
	super._ready()
	nombre_habilidad = "Amague"
	tipo_habilidad   = "amague_guardian"


func _ejecutar(direccion: Vector2, _poder: float) -> void:
	if not is_instance_valid(entidad_dueña):
		return
	_id_ataque += 1
	var id_este := _id_ataque
	var dir := direccion.normalized() if direccion.length() > 0.1 else Vector2.RIGHT
	_en_pose = true

	if "memoria" in entidad_dueña:
		entidad_dueña.get("memoria").establecer("ataque_en_curso", true)

	var animacion: AnimacionComponente = null
	if "componente_animacion" in entidad_dueña:
		animacion = entidad_dueña.componente_animacion
	if animacion:
		animacion.establecer_condicion("parameters/conditions/debeBarrido", true)
		animacion.establecer_condicion("parameters/conditions/debeIdle", false)
		animacion.viajar_a_estado("BARRIDO")

	_mostrar_indicador_area(dir)

	get_tree().create_timer(duracion_pose).timeout.connect(
		_al_terminar_pose.bind(id_este, dir, animacion))


## Reapuntado continuo mientras dura la pose — ver el mismo comentario en
## HabilidadBarridoGuardian._process() (bug real: "el jefe no apunta las
## habilidades encima del jugador").
func _process(delta: float) -> void:
	super._process(delta)
	if not _en_pose or not is_instance_valid(entidad_dueña) or not ("memoria" in entidad_dueña):
		return
	var objetivo_raw = entidad_dueña.get("memoria").obtener("objetivo")
	if not is_instance_valid(objetivo_raw) or not (objetivo_raw is Node2D):
		return
	var hacia_objetivo: Vector2 = (objetivo_raw as Node2D).global_position - entidad_dueña.global_position
	if hacia_objetivo.length() > 0.1 and "direccion_mirada" in entidad_dueña:
		entidad_dueña.direccion_mirada = hacia_objetivo.normalized()
	if is_instance_valid(_indicador_area):
		_actualizar_indicador_area()


## Mismo esquema que HabilidadBarridoGuardian._mostrar_indicador_area.
func _mostrar_indicador_area(dir: Vector2) -> void:
	if not is_instance_valid(entidad_dueña) or not (entidad_dueña is Node2D):
		return
	_indicador_area = IndicadorZonaEfecto.new()
	_indicador_area.color_relleno = Color(0.9, 0.2, 0.2, 0.3)
	_indicador_area.color_borde   = Color(1.0, 0.25, 0.2, 0.9)
	_indicador_area.duracion      = duracion_pose + 0.1
	(entidad_dueña as Node2D).get_tree().current_scene.add_child(_indicador_area)
	_indicador_area.global_position = (entidad_dueña as Node2D).global_position
	_trazar_indicador_area(dir)


func _actualizar_indicador_area() -> void:
	var dir: Vector2 = entidad_dueña.direccion_mirada if "direccion_mirada" in entidad_dueña else Vector2.RIGHT
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	_indicador_area.global_position = (entidad_dueña as Node2D).global_position
	_trazar_indicador_area(dir)


func _trazar_indicador_area(dir: Vector2) -> void:
	var lado := dir.orthogonal() * (ancho * 0.5)
	var punta := dir * largo
	_indicador_area.poligono = PackedVector2Array([-lado, lado, punta + lado, punta - lado])
	_indicador_area.queue_redraw()


func _al_terminar_pose(id_este: int, dir: Vector2, animacion: AnimacionComponente) -> void:
	if id_este != _id_ataque or not is_instance_valid(entidad_dueña):
		return
	_en_pose = false
	if "memoria" in entidad_dueña:
		entidad_dueña.get("memoria").establecer("ataque_en_curso", false)
	if animacion and is_instance_valid(animacion):
		animacion.establecer_condicion("parameters/conditions/debeBarrido", false)
		animacion.establecer_condicion("parameters/conditions/debeIdle", true)

	var origen := entidad_dueña as Node2D
	# dir queda como último respaldo si direccion_mirada no fuera
	# utilizable (mismo criterio que HabilidadFlechaArquero/
	# HabilidadBarridoGuardian) — pisado acá con el valor reapuntado en
	# _process() durante toda la pose, no el capturado al arrancar.
	if "direccion_mirada" in entidad_dueña:
		var mirada: Vector2 = entidad_dueña.direccion_mirada
		if mirada != Vector2.ZERO:
			dir = mirada
	# Ninguna de las dos ramas pasa por activar() (golpear() es estático,
	# _golpear_unico() usa la hitbox pooled directo — ver la cabecera de la
	# clase para el porqué) — habilidad_activada, ya emitida cuando ARRANCÓ
	# la pose, quedó apuntando solo a "Amague" sin decir en qué terminó.
	# Bug real reportado: "no todas las habilidades escriben su nombre" —
	# cualquier barrido/golpe verdadero que salió de un amague nunca
	# aparecía como tal en la etiqueta. Se reemite acá a mano, con el
	# nombre que de verdad describe lo que pasó, mismo mecanismo que ya
	# escucha EnemigoGuardianQuebrado._on_habilidad_activada_para_etiqueta.
	if randf() < _probabilidad_golpe_unico():
		_golpear_unico(origen, dir)
		nombre_habilidad = "Amague (golpe verdadero)"
	else:
		HabilidadBarridoGuardian.golpear(
			origen, dir, largo, ancho, _calcular_dano(int(dano_barrido)), tipo_dano, deja_charco)
		nombre_habilidad = "Amague (barrido)"
	habilidad_activada.emit(self)


## Sesga hacia el golpe único (no bloqueable) si Corte del objetivo actual
## está gastado — misma API que consulta CondicionHabilidadObjetivoEnCooldown
## (SlotHabilidades.obtener_por_tipo + HabilidadBase.puede_usarse()), pero a
## mano acá: esta decisión vive DENTRO de la habilidad, no en el árbol BT.
func _probabilidad_golpe_unico() -> float:
	var objetivo := _objetivo_actual()
	if objetivo == null:
		return probabilidad_golpe_unico
	var slots := objetivo.get_node_or_null("SlotHabilidades") as SlotHabilidades
	if slots == null:
		return probabilidad_golpe_unico
	var corte := slots.obtener_por_tipo("corte")
	if corte and not corte.puede_usarse():
		return minf(1.0, probabilidad_golpe_unico + 0.4)
	return probabilidad_golpe_unico


func _objetivo_actual() -> Node:
	if not (entidad_dueña and "memoria" in entidad_dueña):
		return null
	var objetivo_raw = entidad_dueña.get("memoria").obtener("objetivo")
	return objetivo_raw if is_instance_valid(objetivo_raw) else null


func _golpear_unico(origen: Node2D, dir: Vector2) -> void:
	if not is_instance_valid(origen):
		return
	var golpe := GestorPiscinas.obtener(escena_golpe_verdadero) as GolpeVerdaderoGuardian
	var posicion := origen.global_position + dir * radio_golpe_verdadero
	golpe.global_position = posicion
	golpe.configurar(_calcular_dano(int(dano_golpe_verdadero)), radio_golpe_verdadero,
		entidad_dueña, 0.15, tipo_dano, false)
