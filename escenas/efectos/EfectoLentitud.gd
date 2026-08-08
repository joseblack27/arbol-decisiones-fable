extends EfectoTemporalPegado
class_name EfectoLentitud
## Debuff de lentitud PEGADO al objetivo (no es una zona): se agrega como
## hijo del objetivo golpeado, reduce su velocidad por factor_lentitud
## durante "duracion" segundos y se libera solo. Si el objetivo muere o se
## libera antes, el efecto cae con él y la lentitud se limpia en
## _exit_tree — no puede quedar un slow "fantasma" colgado.
##
## Mismo patrón que curación/escudo con BuffsComponente: el efecto REAL
## (agregar_lentitud en MovimientoComponente) lo maneja este nodo con su
## propio timer; BuffsComponente solo recibe el ícono/duración para que la
## UI lo muestre — crea el componente al vuelo si el objetivo no lo tiene,
## así también funciona sobre mobs sin tocar sus escenas.
##
## Un solo slow del mismo tipo por objetivo: si otro EfectoLentitud con el
## mismo id_debuff ya está pegado, el nuevo RENUEVA la duración del
## existente en vez de apilarse (dos esquirlas no dejan al mob a 25%).

## 0.5 = mitad de velocidad.
@export var factor_lentitud: float = 0.5
@export var duracion: float = 3.0
## Identificador del debuff (para renovar en vez de apilar, y para el ícono).
@export var id_debuff: String = "lentitud"
## Ícono que muestra BarraBuffs. Null = sin indicador visual.
@export var icono_debuff: Texture2D = null

## Asignado por Proyectil._spawnear_efecto_impacto() antes de add_child
## (comparte "objetivo" con EfectoTemporalPegado, la base).
var fuente: Node = null

var _restante: float = 0.0
var _aplicado := false


func _ready() -> void:
	super._ready()
	if is_queued_for_deletion():
		return  # abortado por inmunidad (ver EfectoTemporalPegado._ready())
	if objetivo == null or not is_instance_valid(objetivo):
		queue_free()
		return
	# Ya hay un slow del mismo tipo pegado a este objetivo: renovar el suyo
	# y descartarse — nunca dos factores iguales apilados.
	for hermano in objetivo.get_children():
		if hermano != self and hermano is EfectoLentitud \
				and (hermano as EfectoLentitud).id_debuff == id_debuff:
			(hermano as EfectoLentitud).renovar()
			queue_free()
			return
	var mov := objetivo.get_node_or_null("MovimientoComponente") as MovimientoComponente
	if mov == null:
		queue_free()
		return
	mov.agregar_lentitud(factor_lentitud)
	_aplicado = true
	_restante = duracion
	_anotar_icono()


func _process(delta: float) -> void:
	if not _aplicado:
		return
	_restante -= delta
	if _restante <= 0.0:
		queue_free()


## Reinicia la cuenta regresiva (otro impacto del mismo tipo de slow).
func renovar() -> void:
	_restante = duracion
	_anotar_icono()


## La limpieza vive acá y no en _process: así también corre si el efecto se
## libera por otra vía (el objetivo muere y libera a sus hijos con él).
func _exit_tree() -> void:
	if not _aplicado or objetivo == null or not is_instance_valid(objetivo):
		return
	var mov := objetivo.get_node_or_null("MovimientoComponente") as MovimientoComponente
	if mov:
		mov.quitar_lentitud(factor_lentitud)
	var buffs := objetivo.get_node_or_null("BuffsComponente") as BuffsComponente
	if buffs:
		buffs.quitar(id_debuff)


func _anotar_icono() -> void:
	if icono_debuff == null:
		return
	# Mismo criterio que HabilidadCuracion/HabilidadEscudo: crear el
	# BuffsComponente al vuelo si la entidad no lo tiene.
	var buffs := objetivo.get_node_or_null("BuffsComponente") as BuffsComponente
	if buffs == null:
		buffs = BuffsComponente.new()
		buffs.name = "BuffsComponente"
		objetivo.add_child(buffs)
	buffs.agregar(id_debuff, icono_debuff, duracion, true,
		"Lentitud", "Reduce la velocidad al %d%%" % int(factor_lentitud * 100))
