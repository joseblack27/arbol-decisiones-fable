class_name HabilidadBarridoGuardian
extends HabilidadBase
## Barrido de ÁREA telegrafiado: el Guardián Quebrado se detiene, "carga" el
## golpe (pose del AnimationTree, mismo mecanismo pose+timer que
## HabilidadFlechaArquero) y tras duracion_pose segundos golpea un
## rectángulo alargado en la dirección apuntada — vía Combate.golpear_area()
## (es_area=true), así que el parry direccional de HabilidadCorte SÍ lo
## bloquea de frente. Construcción de rectángulo rotado calcada de
## HabilidadCorte._puntos_rectangulo().
##
## golpear() es estático a propósito: HabilidadAmagueGuardian arranca la
## MISMA pose visual y, recién al terminar, decide si completa como este
## barrido real o cancela a un GolpeVerdaderoGuardian — necesita aplicar
## este mismo golpe sin telegrafiar una segunda pose por su cuenta.
##
## Sin .tscn propio — habilidad de MOB, se agrega como script node directo
## dentro de EnemigoGuardianQuebrado.tscn (ver HabilidadComboGuardian).

@export_group("Barrido")
## OJO al tocar esto: el alcance real hacia adelante del rectángulo ES
## "largo" — HabilidadBT.rango_maximo en BarridoGuardian.tres tiene que
## quedar <= este valor, o la IA elige atacar desde una distancia que el
## rectángulo después no llega a cubrir (bug real reportado: golpes que no
## conectaban con el jugador quieto — no era de apuntado, era este
## desajuste entre "en rango" y "alcance físico real").
@export var largo: float = 150.0
@export var ancho: float = 90.0
@export var dano: float = 18.0
@export var duracion_pose: float = 0.6
## Si true, tras golpear deja un charco de veneno (EfectoDoT) en el centro
## del golpe — se activa recién al entrar la fase 2 ("Cazador").
@export var deja_charco: bool = false

const _ESCENA_CHARCO := preload("res://escenas/efectos/EfectoCharcoJefe.tscn")

var _id_ataque := 0
## true mientras dura la pose — gatilla el reapuntado continuo en
## _process(), mismo campo/idea que HabilidadFrancotiradorGuardian.
var _en_pose := false
## Franja de advertencia (IndicadorZonaEfecto con polígono rotado, mismo
## mecanismo que el retículo de HabilidadFrancotiradorGuardian) que marca
## el rectángulo real donde va a pegar el barrido mientras dura la pose —
## bug real reportado: "el barrido del boss no muestra el área donde
## pega", solo se veía la pose CARGANDO sin ninguna pista de hacia dónde
## ni hasta dónde llega. Sigue la reapuntado continuo (ver _process), así
## que queda sincronizada con el rectángulo real que golpea() termina
## trazando.
var _indicador_area: IndicadorZonaEfecto = null


func _ready() -> void:
	super._ready()
	nombre_habilidad = "Barrido"
	tipo_habilidad   = "barrido_guardian"


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


## Reapuntado continuo mientras dura la pose — bug real reportado: "el jefe
## no apunta las habilidades encima del jugador, algunas las tira antes y
## otras después". La dirección que llega a _ejecutar() se capturaba UNA
## sola vez al arrancar (0.6s antes de golpear de verdad); si el jugador se
## movía en ese rato, el rectángulo salía apuntando a donde estaba, no a
## donde está. Mismo mecanismo que ya usa HabilidadFrancotiradorGuardian
## (y HabilidadFlechaArquero del Esqueleto Arquero): mientras ataque_en_
## curso=true, AccionAtacar deja de reapuntar por su cuenta (ver el
## comentario de esa función) — la propia habilidad tiene que hacerse cargo
## durante su ventana.
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


## Mismo polígono que traza golpear() más abajo — se arma UNA vez con la
## dirección inicial y se reorienta en cada _process() mientras dura la
## pose (ver _actualizar_indicador_area), así queda sincronizado con el
## reapuntado continuo en vez de quedarse clavado en la dirección con la
## que arrancó la pose.
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
	# dir queda como último respaldo si direccion_mirada no fuera
	# utilizable — mismo criterio que HabilidadFlechaArquero._al_terminar_pose.
	var dir_final := dir
	if "direccion_mirada" in entidad_dueña:
		var mirada: Vector2 = entidad_dueña.direccion_mirada
		if mirada != Vector2.ZERO:
			dir_final = mirada
	golpear(entidad_dueña as Node2D, dir_final, largo, ancho, _calcular_dano(int(dano)), tipo_dano, deja_charco)


## Estático: ver cabecera de la clase (reusado por HabilidadAmagueGuardian).
static func golpear(origen: Node2D, dir: Vector2, largo: float, ancho: float,
		dano: float, tipo_dano: Enums.Habilidad.TipoDano, deja_charco: bool) -> void:
	if not is_instance_valid(origen):
		return
	var lado := dir.orthogonal() * (ancho * 0.5)
	var punta := dir * largo
	var forma := ConvexPolygonShape2D.new()
	forma.points = PackedVector2Array([-lado, lado, punta + lado, punta - lado])
	Combate.golpear_area(origen, forma, dano, origen, tipo_dano, "barrido_guardian")
	if deja_charco and origen.get_tree() and origen.get_tree().current_scene:
		var charco := _ESCENA_CHARCO.instantiate()
		origen.get_tree().current_scene.add_child(charco)
		charco.global_position = origen.global_position + dir * (largo * 0.5)
