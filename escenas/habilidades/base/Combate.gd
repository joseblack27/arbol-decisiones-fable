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
## con respetar_equipo=true (el default, usado por TODAS las hitboxes hoy)
## tampoco a sus aliados — sin fuego amigo entre jugadores ni entre mobs.
##
## nombre_evento es el identificador emitido en BusEventos.habilidad_impacto
## ("arañazo", "golpe_basico", "area_efecto"...).
##
## "area" tipado Node2D (no Area2D): solo se usa para get_world_2d() y
## global_transform, que cualquier Node2D tiene — permite pasar directo la
## entidad_dueña (un CharacterBody2D) sin necesitar un Area2D dedicado, como
## hace HabilidadLanzallamas (cono de daño anclado al propio jugador).
##
## multiplicador_final escala el resultado YA calculado por el pipeline de
## atributos (bono plano + potencia + crítico + resistencias del defensor),
## NO el "dano" de entrada — a propósito: habilidades que reparten el golpe
## completo en varios ticks (el lanzallamas, con multiplicador_dano_tick)
## necesitan que el bono plano de "danos" se sume al golpe COMPLETO antes de
## repartirlo, igual que muestra el panel de detalle (PanelDetalleHabilidad
## calcula con los atributos primero, la fracción del tick al final). Escalar
## el "dano" de ENTRADA en cambio hacía que el bono plano del atacante se
## sumara DESPUÉS sobre un número ya achicado, dominando el resultado y
## desalineando lo que en verdad pegaba del número que mostraba la
## descripción ("dice 2-3 pero pega 10-12", reportado).
static func golpear_area(
		area: Node2D,
		forma: Shape2D,
		dano: float,
		fuente: Node,
		tipo_dano: Enums.Habilidad.TipoDano,
		nombre_evento: String,
		respetar_equipo: bool = true,
		multiplicador_final: float = 1.0) -> void:
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
		var dano_final := AtributosComponente.calcular_pipeline(fuente, objetivo, dano, tipo_dano) * multiplicador_final
		var fue_critico := AtributosComponente.ultimo_pipeline_critico
		# Todos los quitar_vida() del proyecto aceptan "fuente" como segundo
		# argumento (VidaComponente, Enemigo, Jugador, y Muro — este último
		# lo usa para no dejarse romper por su propio equipo, ver Muro.
		# _bloqueado_por_equipo), así que siempre se puede pasar derecho.
		if vida is VidaComponente:
			(vida as VidaComponente).quitar_vida(dano_final, fuente, tipo_dano, fue_critico)
		else:
			vida.quitar_vida(dano_final, fuente, tipo_dano, fue_critico)
		# El número flotante local solo se muestra donde el cálculo ES el
		# real (servidor / un jugador); en un cliente puro lo emite
		# VidaComponente._recibir_vida_red con el delta ya replicado.
		if Utils.debe_mostrar_dano_local():
			BusEventos.daño_aplicado.emit(objetivo, dano_final, fuente, tipo_dano, fue_critico)
		BusEventos.habilidad_impacto.emit(nombre_evento, objetivo)
