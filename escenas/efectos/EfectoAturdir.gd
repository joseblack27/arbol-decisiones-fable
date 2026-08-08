extends EfectoTemporalPegado
class_name EfectoAturdir
## Aturde al objetivo: no puede moverse NI actuar durante "duracion"
## segundos. A diferencia de EfectoInmovilizar (zona: solo bloquea
## movimiento mientras está DENTRO de un área), esto es un debuff PEGADO —
## con su propia duración fija, como Veneno/Lentitud — y además pausa la
## IA y las habilidades del objetivo, no solo el movimiento: una
## preparación o un dash YA en curso queda congelado en el punto exacto
## donde estaba, no sigue corriendo mientras dura el aturdimiento.
##
## Extiende EfectoTemporalPegado (no solo por prolijidad): así HabilidadPurga
## también cura un aturdimiento si algún día un mob llega a aplicárselo al
## jugador, con el mismo criterio que cualquier otro debuff temporal.

@export var duracion: float = 1.0
@export var id_debuff: String = "aturdido"
## Ícono que muestra BarraBuffs. Null = sin indicador visual.
@export var icono_debuff: Texture2D = null

var _restante: float = 0.0
var _aplicado := false


func _ready() -> void:
	super._ready()
	if is_queued_for_deletion():
		return  # abortado por inmunidad (ver EfectoTemporalPegado._ready())
	if objetivo == null or not is_instance_valid(objetivo):
		queue_free()
		return
	# Un solo aturdimiento por objetivo: si ya hay uno pegado, renovarlo en
	# vez de apilar dos pausas independientes que se pisarían al levantarse.
	for hermano in objetivo.get_children():
		if hermano != self and hermano is EfectoAturdir \
				and (hermano as EfectoAturdir).id_debuff == id_debuff:
			(hermano as EfectoAturdir).renovar()
			queue_free()
			return
	_aplicar()
	_aplicado = true
	_restante = duracion
	_anotar_icono()


func _process(delta: float) -> void:
	if not _aplicado:
		return
	_restante -= delta
	if _restante <= 0.0:
		queue_free()


## Reinicia la cuenta regresiva (otro golpe de aturdimiento sobre el mismo objetivo).
func renovar() -> void:
	_restante = duracion
	_anotar_icono()


func _aplicar() -> void:
	var mov := objetivo.get_node_or_null("MovimientoComponente") as MovimientoComponente
	if mov:
		mov.agregar_inmovilizacion()
	# PROCESS_MODE_DISABLED corta _process/_physics_process de TODO lo que
	# esté debajo: el árbol de IA no elige una acción nueva, y cualquier
	# habilidad en curso (preparación de una embestida, el dash mismo) se
	# congela en seco en el fotograma donde estaba — al reanudar, sigue
	# desde ahí, sus timers internos ni se enteraron de la pausa.
	var arbol := objetivo.get_node_or_null("ArbolComportamiento")
	if arbol:
		arbol.process_mode = Node.PROCESS_MODE_DISABLED
	var habilidades := objetivo.get_node_or_null("Habilidades")
	if habilidades:
		habilidades.process_mode = Node.PROCESS_MODE_DISABLED
	# Un Jugador no tiene contenedor "Habilidades" (cuelgan directo de él, ver
	# SlotHabilidades._instanciar) — sin esto, aplicado a un jugador esto solo
	# bloqueaba el movimiento, no el uso de habilidades. bloquear_control()
	# ya existe en Jugador.gd y HabilidadBase.activar() ya lo consulta para
	# cualquier otro bloqueo (ver el chequeo de _bloqueos_control ahí).
	if objetivo.has_method("bloquear_control"):
		objetivo.bloquear_control()
		# Si estaba a mitad de apuntar una habilidad direccional (joystick
		# sostenido) cuando llega el aturdimiento, hay que soltarlo YA — mismo
		# mecanismo que Jugador._morir() usa para el mismo problema (pedido
		# del usuario: "si estoy apuntando alguna habilidad, debe cancelarse
		# el apuntado"). Solo el dueño local tiene esos botones en pantalla
		# (ver UIHabilidad._set_apunte, mismo corte).
		if objetivo.has_method(&"_es_dueño_local") and objetivo.call(&"_es_dueño_local") \
				and objetivo.is_inside_tree():
			UIHabilidad.cancelar_todos_los_apuntes(objetivo.get_tree())


func _quitar() -> void:
	if not is_instance_valid(objetivo):
		return
	var mov := objetivo.get_node_or_null("MovimientoComponente") as MovimientoComponente
	if mov:
		mov.quitar_inmovilizacion()
	var arbol := objetivo.get_node_or_null("ArbolComportamiento")
	if arbol:
		arbol.process_mode = Node.PROCESS_MODE_INHERIT
	var habilidades := objetivo.get_node_or_null("Habilidades")
	if habilidades:
		habilidades.process_mode = Node.PROCESS_MODE_INHERIT
	if objetivo.has_method("desbloquear_control"):
		objetivo.desbloquear_control()
	var buffs := objetivo.get_node_or_null("BuffsComponente") as BuffsComponente
	if buffs:
		buffs.quitar(id_debuff)


## Corre sea cual sea la vía de salida (venció solo, lo canceló Purga, o el
## objetivo murió y se lo llevó puesto) — mismo criterio que EfectoLentitud.
func _exit_tree() -> void:
	if _aplicado:
		_quitar()


func _anotar_icono() -> void:
	if icono_debuff == null:
		return
	var buffs := objetivo.get_node_or_null("BuffsComponente") as BuffsComponente
	if buffs == null:
		buffs = BuffsComponente.new()
		buffs.name = "BuffsComponente"
		objetivo.add_child(buffs)
	buffs.agregar(id_debuff, icono_debuff, duracion, true, "Aturdido", "No puede moverse ni actuar")
