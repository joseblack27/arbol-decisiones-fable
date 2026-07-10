class_name Combate
extends RefCounted
## Helpers de combate compartidos por todas las hitboxes instantáneas
## (Arañazo, GolpeBasico, AreaEfecto) y por Proyectil. Antes cada una
## llevaba su propia copia idéntica de esta lógica — cualquier fix de
## combate (p. ej. el gate de números de daño en red) había que repetirlo
## archivo por archivo; ahora vive en un solo lugar.


## Devuelve true si fuente y objetivo son del mismo equipo (ambos enemigos
## o ambos jugadores).
static func mismo_equipo(fuente: Node, objetivo: Node) -> bool:
	if fuente == null or objetivo == null:
		return false
	if fuente.is_in_group("enemigos") and objetivo.is_in_group("enemigos"):
		return true
	if fuente.is_in_group("jugadores") and objetivo.is_in_group("jugadores"):
		return true
	return false


## Golpe instantáneo de área: consulta qué colisiona con "forma" (en la
## posición/rotación de "area") y aplica "dano" —pasado por el pipeline de
## atributos— a cada objetivo válido una sola vez.
##
## Un objetivo válido es el VidaComponente de una entidad (jugador o mob;
## el objetivo real es su padre) o, genérico, cualquier collider con un
## método quitar_vida() propio (p. ej. Muro). Nunca golpea a la fuente, y
## si respetar_equipo=true tampoco a sus aliados (AreaEfecto lo apaga: un
## AoE golpea a todo lo que pise, de siempre).
##
## nombre_evento es el identificador emitido en BusEventos.habilidad_impacto
## ("arañazo", "golpe_basico", "area_efecto"...).
static func golpear_area(
		area: Area2D,
		forma: Shape2D,
		dano: float,
		fuente: Node,
		tipo_dano: Enums.Skill.TypeDamage,
		nombre_evento: String,
		respetar_equipo: bool = true) -> void:
	var espacio := area.get_world_2d().direct_space_state
	var query   := PhysicsShapeQueryParameters2D.new()
	query.shape               = forma
	query.transform           = area.global_transform
	query.collision_mask      = 0xFFFFFFFF
	query.collide_with_areas  = true
	query.collide_with_bodies = true
	var resultados := espacio.intersect_shape(query)
	var ya_dañados: Array = []
	for r in resultados:
		var col = r.get("collider")
		var vida: Node
		var objetivo: Node
		if col is VidaComponente:
			vida     = col
			objetivo = (col as VidaComponente).get_parent()
		elif col.has_method("quitar_vida"):
			vida     = col
			objetivo = col
		else:
			continue
		if objetivo == fuente or objetivo in ya_dañados:
			continue
		if respetar_equipo and mismo_equipo(fuente, objetivo):
			continue
		ya_dañados.append(objetivo)
		var dano_final := AtributosComponente.calcular_pipeline(fuente, objetivo, dano, tipo_dano)
		# VidaComponente y los cuerpos de enemigos/jugadores aceptan el
		# atacante (se replica al cliente para el log de Actividad Reciente);
		# los quitar_vida() genéricos (Muro...) mantienen su firma de un arg.
		if vida is VidaComponente:
			(vida as VidaComponente).quitar_vida(dano_final, fuente)
		elif vida.is_in_group("enemigos") or vida.is_in_group("jugadores"):
			vida.quitar_vida(dano_final, fuente)
		else:
			vida.quitar_vida(dano_final)
		# El número flotante local solo se muestra donde el cálculo ES el
		# real (servidor / un jugador); en un cliente puro lo emite
		# VidaComponente._recibir_vida_red con el delta ya replicado.
		if Utils.debe_mostrar_dano_local():
			BusEventos.daño_aplicado.emit(objetivo, dano_final, fuente)
		BusEventos.habilidad_impacto.emit(nombre_evento, objetivo)
