extends EfectoTemporalPegado
class_name EfectoCepo
## Cepo: PEGADO al objetivo (no es zona, ver EfectoInmovilizar) — lo
## inmoviliza durante "duracion" segundos Y le hace daño por tick cada
## "intervalo_tick", combinando EfectoAturdir (solo el bloqueo de
## movimiento, no de IA/habilidades — un mob atrapado sigue pudiendo
## atacar si ya te tiene al alcance) con el daño periódico de EfectoVeneno.
##
## Un solo Cepo por objetivo: si ya hay uno pegado, el nuevo renueva la
## duración del existente en vez de apilar dos inmovilizaciones en paralelo
## (mismo criterio que Veneno/Aturdir).

@export var dano_por_tick: float = 10.0
@export var intervalo_tick: float = 0.5
@export var duracion: float = 3.0
@export var tipo_dano: Enums.Habilidad.TipoDano = Enums.Habilidad.TipoDano.FISICO
@export var id_debuff: String = "cepo"
## Ícono que muestra BarraBuffs. Null = sin indicador visual.
@export var icono_debuff: Texture2D = null

## Asignado por Cepo._activar() antes de add_child (comparte "objetivo" con
## EfectoTemporalPegado, la base).
var fuente: Node = null

var _restante: float = 0.0
var _acumulador_tick: float = 0.0
var _aplicado := false


func _ready() -> void:
	super._ready()
	if is_queued_for_deletion():
		return  # abortado por inmunidad (ver EfectoTemporalPegado._ready())
	if objetivo == null or not is_instance_valid(objetivo):
		queue_free()
		return
	for hermano in objetivo.get_children():
		if hermano != self and hermano is EfectoCepo \
				and (hermano as EfectoCepo).id_debuff == id_debuff:
			(hermano as EfectoCepo).renovar()
			queue_free()
			return
	_aplicar()
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


## Reinicia la cuenta regresiva (otro Cepo sobre el mismo objetivo mientras
## el primero seguía activo) — la inmovilización ya está puesta, no hace
## falta volver a aplicarla.
func renovar() -> void:
	_restante = duracion
	_anotar_icono()


func _aplicar() -> void:
	var mov := objetivo.get_node_or_null("MovimientoComponente") as MovimientoComponente
	if mov:
		mov.agregar_inmovilizacion()


func _quitar() -> void:
	if not is_instance_valid(objetivo):
		return
	var mov := objetivo.get_node_or_null("MovimientoComponente") as MovimientoComponente
	if mov:
		mov.quitar_inmovilizacion()
	var buffs := objetivo.get_node_or_null("BuffsComponente") as BuffsComponente
	if buffs:
		buffs.quitar(id_debuff)


## Corre sea cual sea la vía de salida (venció solo, lo canceló Purga, o el
## objetivo murió y se lo llevó puesto) — mismo criterio que EfectoAturdir.
func _exit_tree() -> void:
	if _aplicado:
		_quitar()


func _aplicar_tick() -> void:
	if not is_instance_valid(objetivo):
		return
	var vida := objetivo.get_node_or_null("VidaComponente") as VidaComponente
	if not vida:
		return
	# fuente puede haber muerto y liberado; is_instance_valid() lo detecta,
	# "if fuente:" no (mismo criterio que EfectoVeneno.gd).
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
		"Cepo", "Inmovilizado, pierde vida cada %s" % Utils.formatear_segundos(intervalo_tick))
