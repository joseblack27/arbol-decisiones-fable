class_name HabilidadArremetidaGuardian
extends HabilidadCarga
## Arremetida de la fase "Quiebre": la MISMA embestida de HabilidadCarga
## (preparación y dash, daño por solape físico cada fotograma del dash), con
## el daño pasado por AtributosComponente.calcular_pipeline(...,
## ignora_defensa=true): daño verdadero, como el de HabilidadCorte.
##
## A propósito NO es es_area (el quitar_vida() de abajo no lo pasa): ni el
## parry de Corte la salva, hay que esquivarla moviéndose.
##
## Lo demás (fases, timers, contener_dentro_del_mapa, la corrección de
## dirección al iniciar el dash) se hereda de HabilidadCarga. _physics_process()
## se sobreescribe entero porque el bloque de daño está inline en el original.
##
## OJO: distancia_maxima_dash (heredada, configurada en el .tscn del jefe) es
## el alcance físico real: HabilidadBT.rango_maximo en ArremetidaGuardian.tres
## tiene que quedar <= ese valor (mismo criterio que
## HabilidadComboGuardian.alcance_golpe), o la IA arremete contra alguien más
## lejos de lo que el dash llega.

@export var ignora_defensa: bool = true


func _ready() -> void:
	super._ready()
	nombre_habilidad = "Arremetida"
	tipo_habilidad   = "arremetida_guardian"


func _physics_process(delta: float) -> void:
	if _fase != Fase.DASH or not componente_movimiento:
		return
	var entidad := entidad_dueña as CharacterBody2D
	if not entidad:
		return
	if "_muerto" in entidad_dueña and entidad_dueña.get("_muerto"):
		_terminar_carga()
		return

	var vel       := multiplicador_velocidad_carga * componente_movimiento.velocidad_base
	var pos_antes := entidad.global_position
	componente_movimiento.physics_process(delta, _direccion_carga, vel)
	componente_movimiento.contener_dentro_del_mapa()
	_distancia_recorrida += entidad.global_position.distance_to(pos_antes)

	if not _ya_impacto:
		var espacio := entidad.get_world_2d().direct_space_state
		var forma_query := CircleShape2D.new()
		forma_query.radius = 24.0
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape               = forma_query
		query.transform           = entidad.global_transform
		query.collision_mask      = 0xFFFFFFFF
		query.collide_with_bodies = true
		query.collide_with_areas  = true
		var hits := espacio.intersect_shape(query)
		for r in hits:
			var col = r.get("collider")
			if col == null or col == entidad_dueña:
				continue
			var objetivo: Node = col
			if col is VidaComponente:
				objetivo = col.get_parent()
			if objetivo == entidad_dueña:
				continue
			if Combate.mismo_equipo(entidad_dueña, objetivo):
				continue
			if objetivo.has_method("quitar_vida"):
				_ya_impacto = true
				# Único cambio real respecto a HabilidadCarga: ignora_defensa
				# =true en el pipeline — el resto del bloque es idéntico.
				var dano_final := AtributosComponente.calcular_pipeline(
					entidad_dueña, objetivo, dano_carga, tipo_dano, ignora_defensa)
				var fue_critico := AtributosComponente.ultimo_pipeline_critico
				objetivo.quitar_vida(dano_final, entidad_dueña, tipo_dano, fue_critico)
				if Utils.debe_mostrar_dano_local():
					BusEventos.daño_aplicado.emit(objetivo, dano_final, entidad_dueña, tipo_dano, fue_critico)
				BusEventos.habilidad_impacto.emit("arremetida_guardian", objetivo)
				break

	if _distancia_recorrida >= distancia_maxima_dash:
		_terminar_carga()
		return

	if entidad.is_on_wall():
		_terminar_carga()
