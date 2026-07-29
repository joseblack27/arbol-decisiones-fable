class_name GolpeVampirico
extends AreaEfecto
## Mismo AoE que AreaEfecto, pero además cura a quien lo usa un % de TODO el
## daño infligido a los golpeados — Combate.golpear_area() no expone hacia
## afuera cuánto daño hizo cada golpe (necesario para saber cuánto curar),
## así que hace falta el propio recorrido de la consulta física acá (calcado
## de OndaChoque.gd, con el paso extra de acumular robo de vida en vez de
## empujar).

@export_range(0.0, 1.0, 0.05) var porcentaje_robo: float = 0.5


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
	var dano_total := 0.0
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
		BusEventos.habilidad_impacto.emit("golpe_vampirico", objetivo)
		dano_total += dano_final

	# agregar_vida ya se gatea sola a "solo servidor" en red (ver VidaComponente):
	# el cliente predictor NO cura de la nada, espera la réplica real como
	# cualquier otra curación.
	if dano_total > 0.0 and is_instance_valid(entidad_fuente):
		var vida_propia := entidad_fuente.get_node_or_null("VidaComponente") as VidaComponente
		if vida_propia:
			vida_propia.agregar_vida(dano_total * porcentaje_robo)


func _draw() -> void:
	if _forma:
		draw_circle(Vector2.ZERO, _forma.radius, Color(0.7, 0.0, 0.1, 0.3))
		draw_arc(Vector2.ZERO, _forma.radius, 0.0, TAU, 32, Color(0.85, 0.1, 0.15, 0.9), 2.5)
