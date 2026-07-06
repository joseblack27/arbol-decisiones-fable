extends EfectoAreaBase
class_name Muro
## Muro de pilares invocado por HabilidadMuroJugador: una fila perpendicular
## a la dirección de lanzamiento que hace el mismo daño, una vez por
## segundo, a los enemigos que la tocan mientras dure — y también AL
## ENTRAR (tanto a quien ya estaba encima al invocarse como a quien entra
## después, en cualquier momento entre ticks), y que, opcionalmente, los
## bloquea físicamente.
##
## Es destructible: lleva su propia vida encima (mismo Area2D "Hitbox" que ya
## usa para detectar a quién dañar) en vez de un VidaComponente aparte —
## Proyectil/Arañazo ya saben golpear a cualquier objetivo con un método
## quitar_vida(), sea VidaComponente o no. Al llegar a 0, el muro se destruye.

## Capa física reservada para obstáculos de habilidades del jugador (activa
## solo si bloquea_enemigos=true). Los enemigos deben incluirla en su
## collision_mask para chocar contra ella — ver Enemigo.CAPA_OBSTACULOS_HABILIDAD,
## que se aplica automáticamente a todos los mobs. El jugador NO la incluye
## en la suya, así que nunca queda atrapado por su propio muro.
const CAPA_BLOQUEO := 4

signal muerte(valor: float)

@export var intervalo_dano: float = 1.0

@onready var _hitbox: CollisionShape2D = $Hitbox
@onready var _bloqueo: StaticBody2D            = $Bloqueo
@onready var _forma_bloqueo: CollisionShape2D  = $Bloqueo/CollisionShape2D

var _fuente: Node = null
var _tipo_dano: Enums.Skill.TypeDamage = Enums.Skill.TypeDamage.PHYSIC
var _dano: float = 10.0

var _salud_maxima: float = 50.0
var _salud_actual: float = 50.0
## Umbral de penetración de armadura: un proyectil con más "impacto" que
## esto revienta el muro de un golpe y sigue de largo (ver recibir_impacto()).
var _defensa: float = 20.0

var _timer_dano: Timer


func _ready() -> void:
	super._ready()
	_timer_dano = Timer.new()
	_timer_dano.wait_time = intervalo_dano
	_timer_dano.one_shot  = false
	_timer_dano.timeout.connect(_aplicar_tick)
	add_child(_timer_dano)
	_timer_dano.start()


## Llamado por HabilidadMuroJugador justo tras instanciar el muro (con
## global_position ya asignada al punto de invocación). Configura la vida
## del muro, su daño, su forma (fila de "cantidad_pilares" a lo ancho de
## "distancia_entre_pilares", perpendicular a "direccion") y si bloquea
## físicamente a los enemigos.
func configurar(
		fuente: Node,
		direccion: Vector2,
		vida_maxima: float,
		defensa: float,
		dano: float,
		duracion_muro: float,
		bloquea_enemigos: bool,
		cantidad_pilares: int,
		distancia_entre_pilares: float,
		radio_pilar: float,
		escena_pilar: PackedScene,
		tipo: Enums.Skill.TypeDamage = Enums.Skill.TypeDamage.PHYSIC) -> void:
	_fuente    = fuente
	_dano      = dano
	_defensa   = defensa
	duracion   = duracion_muro
	_tipo_dano = tipo

	_salud_maxima = maxf(vida_maxima, 1.0)
	_salud_actual = _salud_maxima

	var dir := direccion.normalized() if direccion.length() > 0.01 else Vector2.RIGHT
	var cantidad := maxi(cantidad_pilares, 1)
	var span := float(cantidad - 1) * distancia_entre_pilares + radio_pilar * 2.0

	_hitbox.rotation = dir.angle()
	(_hitbox.shape as RectangleShape2D).size = Vector2(radio_pilar * 2.0, span)

	_forma_bloqueo.rotation = dir.angle()
	(_forma_bloqueo.shape as RectangleShape2D).size = Vector2(radio_pilar * 2.0, span)
	_bloqueo.set_deferred("collision_layer", CAPA_BLOQUEO if bloquea_enemigos else 0)

	var normal := dir.rotated(PI / 2.0)
	var offset_max := float(cantidad - 1) * distancia_entre_pilares / 2.0
	for i in cantidad:
		var pilar := escena_pilar.instantiate()
		add_child(pilar)
		var offset := (float(i) - float(cantidad - 1) / 2.0) * distancia_entre_pilares
		offset = clampf(offset, -offset_max, offset_max)
		pilar.position = normal * offset
		if "radio_placeholder" in pilar:
			pilar.radio_placeholder = radio_pilar


# =============================================================================
# VIDA PROPIA (misma API pública que VidaComponente, sin necesitar un
# Area2D aparte: Proyectil/Arañazo detectan cualquier objetivo con
# quitar_vida(), aunque no sea VidaComponente — ver Proyectil._on_area_entrada).
# =============================================================================

func obtener_vida() -> float:
	return _salud_actual


func obtener_vida_maxima() -> float:
	return _salud_maxima


func quitar_vida(cantidad: float) -> float:
	if cantidad <= 0.0:
		return _salud_actual
	_salud_actual -= cantidad
	if _salud_actual <= 0.0:
		_romper()
	return maxf(0.0, _salud_actual)


## Un proyectil con más "impacto" (penetración de armadura) que la defensa
## del muro lo revienta de un solo golpe — quien lo golpeó no debe gastarse
## en el intento: ver Proyectil._on_area_entrada, que al recibir true aquí
## no se destruye a sí mismo y sigue de largo.
## Devuelve true si el muro se rompió, false si lo absorbió sin más (en ese
## caso el daño normal ya lo aplica quien llamó, vía quitar_vida()).
func recibir_impacto(impacto: float) -> bool:
	print(impacto, " > ", _defensa)
	if impacto > _defensa:
		_romper()
		return true
	return false


func _romper() -> void:
	_salud_actual = 0.0
	muerte.emit(0.0)
	queue_free()


## EfectoAreaBase la llama al entrar alguien del grupo objetivo — tanto a
## quien ya estaba encima cuando el muro apareció (el motor dispara
## body_entered igual para solapes preexistentes) como a quien entra más
## tarde, en cualquier punto entre dos ticks: así nadie se libra del golpe
## inicial esperando a que caiga el próximo tick del timer.
func _aplicar_efecto(objetivo: Node) -> void:
	_danar(objetivo)


func _aplicar_tick() -> void:
	for objetivo in _objetivos_actuales:
		if not is_instance_valid(objetivo):
			continue
		_danar(objetivo)


func _danar(objetivo: Node) -> void:
	var vida_obj := objetivo.get_node_or_null("VidaComponente") as VidaComponente
	if not vida_obj:
		return
	var dano_final := AtributosComponente.calcular_pipeline(_fuente, objetivo, _dano, _tipo_dano)
	vida_obj.quitar_vida(dano_final)
	BusEventos.daño_aplicado.emit(objetivo, dano_final, _fuente)
