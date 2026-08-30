class_name GolpeCorruptoGuardian
extends Area2D
## Hitbox de golpe corrupto, cuerpo a cuerpo, del Guardián Quebrado (fase
## "Corrupción"). A diferencia de GolpeVerdaderoGuardian, ESTE golpe SÍ es
## de área (parriable con Corte, como cualquier golpe normal) — lo único
## nuevo es que, tras dañar, sortea entre EfectoVeneno y EfectoLentitud
## sobre cada objetivo golpeado, empujando a usar Purga con criterio.
##
## Copia deliberada del cuerpo de Combate.golpear_area() (mismo motivo que
## GolpeVerdaderoGuardian y HabilidadCorte._golpear(): golpear_area() es
## void, no devuelve a quién golpeó, y acá hace falta esa lista para
## aplicar el debuff solo a quien de verdad conectó el golpe).

var _daño: float = 16.0
var _duracion: float = 0.15
var _entidad_fuente: Node = null
var _timer: float = 0.0
var _configurado: bool = false
var _tipo_dano: Enums.Habilidad.TipoDano = Enums.Habilidad.TipoDano.FISICO

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
	call_deferred("_aplicar_daño")


func _al_liberar_a_piscina() -> void:
	set_deferred("monitorable", false)


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
			# Preferir el VidaComponente real del objetivo si lo tiene, en vez
			# de quedarse con "col" — la query puede devolver el CUERPO y el
			# ÁREA del mismo objetivo en cualquier orden; si el cuerpo llega
			# primero y "gana" acá, _corromper() (más abajo, solo corre si
			# "vida is VidaComponente") nunca se disparaba aunque el daño sí
			# conectara (bug real: el debuff de fase 3 fallaba según el
			# orden, no según la moneda 50/50).
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
		BusEventos.habilidad_impacto.emit("golpe_corrupto_guardian", objetivo)
		if vida is VidaComponente and objetivo is Node:
			_corromper(objetivo as Node)


## Sortea entre veneno y lentitud (50/50) — mismo patrón que Proyectil.
## _spawnear_efecto_impacto(): objetivo/fuente asignados ANTES de add_child.
func _corromper(objetivo: Node) -> void:
	if randf() < 0.5:
		var veneno := EfectoVeneno.new()
		veneno.objetivo = objetivo
		veneno.fuente = _entidad_fuente
		veneno.dano_por_tick = _daño * 0.3
		veneno.duracion = 4.0
		objetivo.add_child(veneno)
	else:
		var lentitud := EfectoLentitud.new()
		lentitud.objetivo = objetivo
		lentitud.fuente = _entidad_fuente
		lentitud.factor_lentitud = 0.5
		lentitud.duracion = 3.0
		objetivo.add_child(lentitud)


func _process(delta: float) -> void:
	if not _configurado:
		return
	_timer += delta
	if _timer >= _duracion:
		GestorPiscinas.liberar(self)


func _draw() -> void:
	if _forma:
		draw_circle(Vector2.ZERO, _forma.radius, Color(0.5, 0.9, 0.2, 0.3))
