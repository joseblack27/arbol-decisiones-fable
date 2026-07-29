extends Node
class_name EfectoVeneno
## Veneno PEGADO al objetivo (no es una zona, a diferencia de EfectoDoT):
## se agrega como hijo del enemigo golpeado y le hace daño por tick
## durante "duracion" segundos, SIGUIÉNDOLO a donde vaya — una nube de
## veneno en el suelo (EfectoDoT) deja de dañar apenas el objetivo camina
## fuera de ella; esto no, se queda envenenado se mueva o no. Mismo
## patrón que EfectoLentitud (self-manage con su propio timer, cae con el
## objetivo si este muere/se libera antes).
##
## Un solo veneno del mismo tipo por objetivo: si otro EfectoVeneno con el
## mismo id_debuff ya está pegado, el nuevo RENUEVA la duración del
## existente en vez de apilarse (mismo criterio que EfectoLentitud — dos
## flechas envenenadas no deben acumular dos DoT en paralelo).

@export var dano_por_tick: float = 8.0
@export var intervalo_tick: float = 1.0
@export var duracion: float = 5.0
@export var tipo_dano: Enums.Habilidad.TipoDano = Enums.Habilidad.TipoDano.FISICO
## Identificador del debuff (para renovar en vez de apilar, y para el ícono).
@export var id_debuff: String = "veneno"
## Ícono que muestra BarraBuffs — solo tiene efecto real si el objetivo es
## el jugador local (esta misma habilidad hoy solo se usa contra
## enemigos, así que en la práctica queda sin ícono visible en ningún
## lado; se deja el campo por si el veneno algún día lo lanza un enemigo
## contra un jugador).
@export var icono_debuff: Texture2D = null

## Asignados por Proyectil._spawnear_efecto_impacto() antes de add_child.
var objetivo: Node = null
var fuente: Node = null

var _restante: float = 0.0
var _acumulador_tick: float = 0.0
var _aplicado := false


func _ready() -> void:
	if objetivo == null or not is_instance_valid(objetivo):
		queue_free()
		return
	# Ya hay un veneno del mismo tipo pegado a este objetivo: renovar el
	# suyo y descartarse — nunca dos DoT del mismo tipo en paralelo.
	for hermano in objetivo.get_children():
		if hermano != self and hermano is EfectoVeneno \
				and (hermano as EfectoVeneno).id_debuff == id_debuff:
			(hermano as EfectoVeneno).renovar()
			queue_free()
			return
	_aplicado = true
	_restante = duracion
	_acumulador_tick = 0.0
	_anotar_icono()


func _process(delta: float) -> void:
	if not _aplicado:
		return
	_restante -= delta
	_acumulador_tick += delta
	if _acumulador_tick >= intervalo_tick:
		_acumulador_tick -= intervalo_tick
		_aplicar_tick()
	if _restante <= 0.0:
		queue_free()


## Reinicia la cuenta regresiva (otro impacto del mismo tipo de veneno).
func renovar() -> void:
	_restante = duracion
	_anotar_icono()


func _aplicar_tick() -> void:
	if not is_instance_valid(objetivo):
		return
	var vida := objetivo.get_node_or_null("VidaComponente") as VidaComponente
	if not vida:
		return
	# fuente puede haber muerto y liberado; is_instance_valid() lo detecta,
	# "if fuente:" no (mismo criterio que EfectoDoT.gd).
	var fuente_valida: Node = fuente if is_instance_valid(fuente) else null
	if Combate.mismo_equipo(fuente_valida, objetivo):
		return
	var dano_final := AtributosComponente.calcular_pipeline(fuente_valida, objetivo, dano_por_tick, tipo_dano)
	var fue_critico := AtributosComponente.ultimo_pipeline_critico
	vida.quitar_vida(dano_final, fuente_valida, tipo_dano, fue_critico)
	if Utils.debe_mostrar_dano_local():
		BusEventos.daño_aplicado.emit(objetivo, dano_final, fuente_valida, tipo_dano, fue_critico)


func _anotar_icono() -> void:
	if icono_debuff == null:
		return
	var buffs := objetivo.get_node_or_null("BuffsComponente") as BuffsComponente
	if buffs == null:
		buffs = BuffsComponente.new()
		buffs.name = "BuffsComponente"
		objetivo.add_child(buffs)
	buffs.agregar(id_debuff, icono_debuff, duracion, true,
		"Veneno", _descripcion_buff())


## Mismo criterio que HabilidadAura._descripcion_buff(): el daño real de
## cada tick pasa por el pipeline COMPLETO (con roll de crítico incluido,
## ver _aplicar_tick), pero acá se muestra la vista previa SIN crítico —
## igual que "Daño Calculado" en el detalle de cualquier habilidad (el
## crítico es aleatorio, no tiene sentido fijo en un texto). La versión
## anterior mostraba dano_por_tick crudo, sin pasar por los atributos de
## quien disparó el veneno — mismo bug ya encontrado y arreglado en Aura.
func _descripcion_buff() -> String:
	var atrib: AtributosComponente = null
	if is_instance_valid(fuente):
		atrib = fuente.get_node_or_null("AtributosComponente") as AtributosComponente
	var rango := AtributosComponente.calcular_rango_con_factor(atrib, dano_por_tick, dano_por_tick)
	return "Pierde %d de vida cada %s" % [rango.x, Utils.formatear_segundos(intervalo_tick)]
