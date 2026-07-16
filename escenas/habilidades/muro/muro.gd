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
	_tipo_dano = tipo
	# Reinicia duración/objetivos y REarranca el temporizador — a diferencia
	# de fijar "duracion" directo, esto también sirve para reutilizar el muro
	# desde la piscina (ver GestorPiscinas): el Timer solo se crea una vez en
	# _ready(), que un muro reciclado nunca vuelve a ejecutar.
	reiniciar_temporizador(duracion_muro)
	set_deferred("monitorable", true)
	set_deferred("monitoring", true)

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

	# Los pilares son puro Node2D+Sprite2D (sin colisión propia, ver Pilar.gd)
	# — no vale la pena poolearlos aparte: se recrean cada vez, pero primero
	# hay que soltar los de una reutilización anterior desde la piscina.
	for hijo in get_children():
		if hijo is Pilar:
			hijo.queue_free()

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


## fuente_ataque (opcional): quién pega — si es del mismo equipo que quien
## INVOCÓ este muro (_fuente), el golpe no hace nada (ver _bloqueado_por_
## equipo). Sin fuente_ataque (null: daño ambiental sin atacante
## identificable) no se bloquea nada, igual que antes.
func quitar_vida(cantidad: float, fuente_ataque: Node = null) -> float:
	if _bloqueado_por_equipo(fuente_ataque):
		return _salud_actual
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
## caso el daño normal ya lo aplica quien llamó, vía quitar_vida()) o si el
## golpe se bloqueó por ser del mismo equipo que quien invocó el muro.
func recibir_impacto(impacto: float, fuente_ataque: Node = null) -> bool:
	if _bloqueado_por_equipo(fuente_ataque):
		return false
	if impacto > _defensa:
		_romper()
		return true
	return false


## Un jugador no puede destruir su propio muro (ni el de otro jugador), y
## un mob no puede destruir el de otro mob — solo bandos distintos pueden
## true si "nodo" es del mismo equipo de quien invocó este muro — Proyectil
## lo consulta para ATRAVESAR muros aliados sin gastarse (antes el proyectil
## moría contra el muro propio sin poder dañarlo: disparo desperdiciado).
func es_aliado_de(nodo: Node) -> bool:
	return _bloqueado_por_equipo(nodo)


## romperse los muros entre sí. _fuente es quien INVOCÓ este muro (ver
## configurar()); fuente_ataque es quien está pegando ahora.
func _bloqueado_por_equipo(fuente_ataque: Node) -> bool:
	return is_instance_valid(fuente_ataque) and Combate.mismo_equipo(fuente_ataque, _fuente)


func _romper() -> void:
	_salud_actual = 0.0
	muerte.emit(0.0)
	_al_terminar()


## Sobreescribe EfectoAreaBase._al_terminar(): en vez de liberar de verdad,
## el muro vuelve a su piscina (ver GestorPiscinas) — llega acá tanto por
## duración agotada (_terminar(), heredado) como por romperse en combate
## (_romper(), arriba).
func _al_terminar() -> void:
	GestorPiscinas.liberar(self)


## GestorPiscinas.liberar() llama esto justo antes de esconder el nodo: sin
## esto, un muro "en espera" en la piscina seguiría bloqueando/detectando
## golpes mientras está oculto, y sus pilares viejos quedarían colgados.
func _al_liberar_a_piscina() -> void:
	set_deferred("monitorable", false)
	set_deferred("monitoring", false)
	_bloqueo.set_deferred("collision_layer", 0)
	for hijo in get_children():
		if hijo is Pilar:
			hijo.queue_free()


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
	# Sin fuego amigo: el grupo_objetivo del .tscn ya filtra hoy ("enemigos"
	# para el muro del jugador), pero este corte por equipo real de quien
	# invocó el muro lo mantiene correcto si algún día un mob lanza muros.
	if Combate.mismo_equipo(_fuente, objetivo):
		return
	var vida_obj := objetivo.get_node_or_null("VidaComponente") as VidaComponente
	if not vida_obj:
		return
	var dano_final := AtributosComponente.calcular_pipeline(_fuente, objetivo, _dano, _tipo_dano)
	vida_obj.quitar_vida(dano_final, _fuente)
	if Utils.debe_mostrar_dano_local():
		BusEventos.daño_aplicado.emit(objetivo, dano_final, _fuente)
