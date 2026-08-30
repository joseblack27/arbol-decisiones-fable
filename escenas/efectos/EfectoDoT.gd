extends EfectoAreaBase
class_name EfectoDoT
## Efecto de área que aplica daño por tick a los objetivos dentro.
## Se combina con cualquier proyectil que tenga escena_al_impactar asignada.

@export var dano_por_tick: float = 5.0
@export var intervalo: float     = 1.0
@export var tipo_dano: Enums.Habilidad.TipoDano = Enums.Habilidad.TipoDano.FISICO

## Se asigna automáticamente desde Proyectil si tiene la propiedad "fuente".
var fuente: Node = null

var _timer_dano: Timer


func _ready() -> void:
	super._ready()
	_timer_dano = Timer.new()
	_timer_dano.wait_time = intervalo
	_timer_dano.one_shot  = false
	_timer_dano.timeout.connect(_aplicar_tick)
	add_child(_timer_dano)
	_timer_dano.start()


func _aplicar_tick() -> void:
	for objetivo in _objetivos_actuales:
		if not is_instance_valid(objetivo):
			continue
		var vida := objetivo.get_node_or_null("VidaComponente") as VidaComponente
		if not vida:
			continue
		# fuente puede haber muerto y liberado (p. ej. la araña que dejó esta
		# telaraña); is_instance_valid() lo detecta, "if fuente:" no.
		var fuente_valida: Node = fuente if is_instance_valid(fuente) else null
		# Sin fuego amigo: grupo_objetivo ya filtra hoy (la telaraña de la
		# araña solo agarra "jugadores"), pero este corte mantiene el efecto
		# correcto si se reutiliza la escena para una habilidad del otro bando.
		if Combate.mismo_equipo(fuente_valida, objetivo):
			continue
		var dano_final := AtributosComponente.calcular_pipeline(fuente_valida, objetivo, dano_por_tick, tipo_dano)
		var fue_critico := AtributosComponente.ultimo_pipeline_critico
		# es_area=true + origen = ESTE charco, no quien lo creó (que puede
		# estar del otro lado del mapa, o muerto y liberado — ver arriba).
		# Así ParryComponente resuelve bien el caso "el jugador está parado
		# ENCIMA del ataque" que pidió el usuario para HabilidadCorte: el
		# origen coincide con los pies del jugador, no con el jefe lejano.
		vida.quitar_vida(dano_final, fuente_valida, tipo_dano, fue_critico,
			true, global_position)
		# Se emite SIEMPRE en single-player/servidor (incluso con
		# fuente_valida = null): el golpe fue real y debe verse (número
		# flotante vía GestorNumerosDano), aunque ya no haya quién reclamar
		# el crédito por él. En un cliente puro el número real ya lo emite
		# VidaComponente._recibir_vida_red() — ver Utils.debe_mostrar_dano_local().
		if Utils.debe_mostrar_dano_local():
			BusEventos.daño_aplicado.emit(objetivo, dano_final, fuente_valida, tipo_dano, fue_critico)
