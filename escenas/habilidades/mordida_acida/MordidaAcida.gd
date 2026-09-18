class_name MordidaAcida
extends Area2D
## Hitbox de la Mordida Ácida de las hormigas: golpe cuerpo a cuerpo normal
## (parriable con Corte, como cualquier golpe de área) que además pega
## SIEMPRE EfectoVeneno + EfectoLentitud al objetivo golpeado — mismo
## patrón que GolpeCorruptoGuardian.gd (ver ese archivo para el porqué de
## reimplementar el cuerpo de Combate.golpear_area() acá: esa función es
## void, no devuelve a quién golpeó, y hace falta esa lista para aplicar
## el debuff solo a quien de verdad conectó el golpe), pero sin el sorteo
## 50/50 — acá van los dos efectos juntos, siempre.
##
## No acumulable entre hormigas: EfectoVeneno/EfectoLentitud ya renuevan
## en vez de apilarse cuando encuentran un hermano con el mismo id_debuff
## (ver esas clases) — con id_debuff="mordida_acida" en ambos, una mordida
## ácida de OTRA hormiga solo resetea el contador existente, nunca suma un
## segundo DoT/slow en paralelo.

var _daño: float = 8.0
var _duracion: float = 0.15
var _entidad_fuente: Node = null
var _timer: float = 0.0
var _configurado: bool = false
var _tipo_dano: Enums.Habilidad.TipoDano = Enums.Habilidad.TipoDano.FISICO
var _daño_pendiente: bool = false

## Veneno/lentitud aplicados al objetivo golpeado.
var dano_por_tick: float = 3.0
var intervalo_tick: float = 1.0
var duracion_veneno: float = 4.0
var factor_lentitud: float = 0.8  ## 0.8 = -20% de velocidad.
var duracion_lentitud: float = 4.0
const ID_DEBUFF := "mordida_acida"

@onready var _col_shape: CollisionShape2D = $CollisionShape2D
var _forma: CircleShape2D


func _ready() -> void:
	_forma = _col_shape.shape as CircleShape2D


func configurar(cantidad_daño: float, radio: float, fuente: Node, duracion: float,
		tipo: Enums.Habilidad.TipoDano = Enums.Habilidad.TipoDano.FISICO) -> void:
	_daño = cantidad_daño
	_forma.radius = radio
	_entidad_fuente = fuente
	_duracion = duracion
	_tipo_dano = tipo
	_configurado = true
	_timer = 0.0
	set_deferred("monitorable", true)
	_daño_pendiente = true


func _al_liberar_a_piscina() -> void:
	set_deferred("monitorable", false)


func _physics_process(_delta: float) -> void:
	if _daño_pendiente:
		_daño_pendiente = false
		_aplicar_daño()


func _aplicar_daño() -> void:
	var espacio := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _forma
	query.transform = global_transform
	query.collision_mask = 0xFFFFFFFF
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var ya_dañados: Array = []
	for r in espacio.intersect_shape(query):
		var col = r.get("collider")
		var vida: Node
		var objetivo: Node
		if col is VidaComponente:
			vida = col
			objetivo = (col as VidaComponente).get_parent()
		elif (col is Node) and (col as Node).has_method("quitar_vida"):
			objetivo = col
			var vida_real := (col as Node).get_node_or_null("VidaComponente")
			vida = vida_real if vida_real is VidaComponente else col
		else:
			continue
		if objetivo == _entidad_fuente or objetivo in ya_dañados:
			continue
		if Combate.mismo_equipo(_entidad_fuente, objetivo):
			continue
		ya_dañados.append(objetivo)
		var dano_final := AtributosComponente.calcular_pipeline(
			_entidad_fuente, objetivo, _daño, _tipo_dano)
		var fue_critico := AtributosComponente.ultimo_pipeline_critico
		if vida is VidaComponente:
			(vida as VidaComponente).quitar_vida(dano_final, _entidad_fuente, _tipo_dano, fue_critico,
				true, global_position)
		else:
			vida.quitar_vida(dano_final, _entidad_fuente, _tipo_dano, fue_critico)
		if Utils.debe_mostrar_dano_local():
			BusEventos.daño_aplicado.emit(objetivo, dano_final, _entidad_fuente, _tipo_dano, fue_critico)
		BusEventos.habilidad_impacto.emit("mordida_acida", objetivo)
		if vida is VidaComponente and objetivo is Node:
			_envenenar_y_ralentizar(objetivo as Node)


func _envenenar_y_ralentizar(objetivo: Node) -> void:
	var veneno := EfectoVeneno.new()
	veneno.objetivo = objetivo
	veneno.fuente = _entidad_fuente
	veneno.dano_por_tick = dano_por_tick
	veneno.intervalo_tick = intervalo_tick
	veneno.duracion = duracion_veneno
	veneno.tipo_dano = _tipo_dano
	veneno.id_debuff = ID_DEBUFF
	objetivo.add_child(veneno)

	var lentitud := EfectoLentitud.new()
	lentitud.objetivo = objetivo
	lentitud.fuente = _entidad_fuente
	lentitud.factor_lentitud = factor_lentitud
	lentitud.duracion = duracion_lentitud
	lentitud.id_debuff = ID_DEBUFF
	objetivo.add_child(lentitud)


func _process(delta: float) -> void:
	if not _configurado:
		return
	_timer += delta
	if _timer >= _duracion:
		GestorPiscinas.liberar(self)


func _draw() -> void:
	if _forma:
		draw_circle(Vector2.ZERO, _forma.radius, Color(0.4, 0.85, 0.2, 0.3))
