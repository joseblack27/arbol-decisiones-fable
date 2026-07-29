class_name OndaChoque
extends AreaEfecto
## Mismo AoE que AreaEfecto, pero además empuja lejos del centro a cada
## enemigo golpeado (ver MovimientoComponente.aplicar_empuje) — Combate.
## golpear_area() no expone hacia afuera la posición de cada objetivo
## golpeado, así que hace falta el propio recorrido de la consulta física
## acá (calcado de Combate.golpear_area, con el paso extra de empujar).

@export var fuerza_empuje: float = 400.0
@export var duracion_empuje: float = 0.25


func _aplicar_daño() -> void:
	_activado = true
	var espacio := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape               = _forma
	query.transform           = global_transform
	query.collision_mask      = 0xFFFFFFFF
	query.collide_with_areas  = true
	query.collide_with_bodies = true
	var resultados := espacio.intersect_shape(query)
	var ya_golpeados: Array = []
	for r in resultados:
		var col = r.get("collider")
		var vida: Node
		var objetivo: Node
		if col is VidaComponente:
			vida     = col
			objetivo = (col as VidaComponente).get_parent()
		elif col is Node and (col as Node).has_method("quitar_vida"):
			vida     = col
			objetivo = col
		else:
			continue
		if objetivo == entidad_fuente or objetivo in ya_golpeados:
			continue
		if Combate.mismo_equipo(entidad_fuente, objetivo):
			continue
		ya_golpeados.append(objetivo)

		var dano_final := AtributosComponente.calcular_pipeline(entidad_fuente, objetivo, daño, tipo_dano)
		var fue_critico := AtributosComponente.ultimo_pipeline_critico
		if vida is VidaComponente:
			(vida as VidaComponente).quitar_vida(dano_final, entidad_fuente, tipo_dano, fue_critico)
		else:
			vida.quitar_vida(dano_final, entidad_fuente, tipo_dano, fue_critico)
		if Utils.debe_mostrar_dano_local():
			BusEventos.daño_aplicado.emit(objetivo, dano_final, entidad_fuente, tipo_dano, fue_critico)
		BusEventos.habilidad_impacto.emit("onda_choque", objetivo)

		if objetivo is Node2D:
			var mov := (objetivo as Node2D).get_node_or_null("MovimientoComponente") as MovimientoComponente
			if mov:
				var direccion_empuje := global_position.direction_to((objetivo as Node2D).global_position)
				if direccion_empuje == Vector2.ZERO:
					direccion_empuje = Vector2.RIGHT  # mismo punto exacto: dirección arbitraria.
				mov.aplicar_empuje(direccion_empuje, fuerza_empuje, duracion_empuje)


func _draw() -> void:
	if _forma:
		draw_circle(Vector2.ZERO, _forma.radius, Color(1.0, 0.6, 0.1, 0.3))
		draw_arc(Vector2.ZERO, _forma.radius, 0.0, TAU, 32, Color(1.0, 0.7, 0.2, 0.9), 2.5)
