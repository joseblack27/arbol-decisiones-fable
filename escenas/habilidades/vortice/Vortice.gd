class_name Vortice
extends AreaEfecto
## A diferencia de OndaChoque (un solo empujón al activarse), este campo
## queda FIJO en el punto donde se lanza y atrae repetidamente hacia su
## centro a todo enemigo en su radio durante TODA su duración — un campo
## sostenido, no un tirón instantáneo, para poder agrupar y MANTENER
## agrupados a los enemigos mientras se los remata con otra habilidad a
## distancia. Sin daño propio a propósito: es una herramienta de control,
## no de daño.

@export var fuerza_atraccion: float = 300.0
## Cada cuánto se repite el tirón mientras el campo sigue activo.
@export var intervalo_atraccion: float = 0.3
## Un poco más que intervalo_atraccion: el empuje de cada tirón dura lo
## suficiente para que el próximo ya lo encuentre frenando, sin un hueco
## donde el enemigo recupera control de golpe y se aleja solo.
@export var duracion_empuje_por_tiron: float = 0.4

var _acumulador_atraccion: float = 0.0


func configurar(cantidad_daño: float, fuente: Node, tipo: Enums.Habilidad.TipoDano = Enums.Habilidad.TipoDano.FISICO) -> void:
	super.configurar(cantidad_daño, fuente, tipo)
	_acumulador_atraccion = 0.0


func _aplicar_daño() -> void:
	_activado = true
	_atraer_una_vez()


## Sobreescribe AreaEfecto._process (que solo cuenta hasta duracion_efecto
## una vez): acá TAMBIÉN repite _atraer_una_vez() cada intervalo_atraccion
## mientras el campo sigue vivo, antes de liberarse a la piscina al vencer.
func _process(delta: float) -> void:
	if not _activado:
		return
	_timer += delta
	if _timer >= duracion_efecto:
		GestorPiscinas.liberar(self)
		return
	_acumulador_atraccion += delta
	if _acumulador_atraccion >= intervalo_atraccion:
		_acumulador_atraccion = 0.0
		_atraer_una_vez()


func _atraer_una_vez() -> void:
	var espacio := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape               = _forma
	query.transform           = global_transform
	query.collision_mask      = 0xFFFFFFFF
	query.collide_with_areas  = true
	query.collide_with_bodies = true
	var resultados := espacio.intersect_shape(query)
	var ya_atraidos: Array = []
	for r in resultados:
		var col = r.get("collider")
		var objetivo: Node
		if col is VidaComponente:
			objetivo = (col as VidaComponente).get_parent()
		elif col is Node and (col as Node).has_method("quitar_vida"):
			objetivo = col
		else:
			continue
		if objetivo == entidad_fuente or objetivo in ya_atraidos:
			continue
		if Combate.mismo_equipo(entidad_fuente, objetivo):
			continue
		ya_atraidos.append(objetivo)

		if objetivo is Node2D:
			var mov := (objetivo as Node2D).get_node_or_null("MovimientoComponente") as MovimientoComponente
			if mov:
				var distancia := (objetivo as Node2D).global_position.distance_to(global_position)
				# Reportado: "los jala a mucha velocidad que se pasan del
				# centro" — aplicar_empuje() es velocidad CONSTANTE durante
				# duracion_empuje_por_tiron, así que a fuerza_atraccion fija
				# un objetivo ya cerca del centro viajaba más de lo que le
				# faltaba y se pasaba de largo (para volver a pasarse en el
				# tirón siguiente, oscilando). Limitar la velocidad a "lo que
				# falta / el tiempo del tirón" hace que llegue justo al
				# centro y se quede ahí, en vez de rebotar.
				if distancia > 2.0:
					var direccion_atraccion := (objetivo as Node2D).global_position.direction_to(global_position)
					var velocidad_atraccion := minf(fuerza_atraccion, distancia / duracion_empuje_por_tiron)
					mov.aplicar_empuje(direccion_atraccion, velocidad_atraccion, duracion_empuje_por_tiron)
		BusEventos.habilidad_impacto.emit("vortice", objetivo)


func _draw() -> void:
	if _forma:
		draw_circle(Vector2.ZERO, _forma.radius, Color(0.35, 0.05, 0.55, 0.3))
		draw_arc(Vector2.ZERO, _forma.radius, 0.0, TAU, 32, Color(0.55, 0.15, 0.75, 0.9), 2.5)
