extends VBoxContainer
class_name PanelNotificacionesLoot
## Lista de avisos rápidos: ítems obtenidos (BusEventos.item_agregado) y XP
## ganada (BusEventos.xp_agregada). No es interactuable (todo el árbol tiene
## mouse_filter=IGNORE). Sistema de cola: como máximo "max_filas_visibles"
## filas están en pantalla a la vez; lo que llega de más espera en _cola y se
## va mostrando a medida que las filas activas terminan su propio fundido.
##
## Las filas NUNCA se destruyen: como máximo puede haber max_filas_visibles
## en juego a la vez, así que se instancian una única vez y se reciclan
## (pool propio) — instanciar/liberar un PanelContainer+Label por cada aviso
## se sentía como un tirón notable en Android cada vez que moría un enemigo.

@export var escena_notificacion: PackedScene = preload("res://escenas/ui/notificaciones_loot/NotificacionLoot.tscn")
## Pedido explícito del usuario: "que no se vean 5 a la vez sino uno a la
## vez" — ocupaban demasiado espacio y a veces era información irrelevante,
## como los números flotantes de daño que muestran un valor a la vez.
@export var max_filas_visibles: int = 1

## Pedido explícito del usuario: si es la única notificación (o la última
## que queda en cola), se queda leíble 3s; si hay más detrás esperando,
## pasa rápido (0.5s) para no atrasar al resto — ver _mostrar().
const DURACION_UNICA: float = 3.0
const DURACION_ENCOLADA: float = 0.5

var _cola: Array[Dictionary] = []
var _libres: Array[NotificacionLoot] = []
var _activas := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	BusEventos.item_agregado.connect(_on_item_agregado)
	BusEventos.xp_agregada.connect(_on_xp_agregada)
	# nivel_subido NO pasa por acá a propósito: el aviso de nivel es un
	# cartel aparte, centrado arriba y más grande — ver AvisoNivel.gd. Este
	# panel queda solo para ítems/XP, sin tocar su comportamiento.


func _on_item_agregado(item: DatosItem, cantidad: int) -> void:
	if item == null:
		return
	_encolar({"tipo": "item", "item": item, "cantidad": cantidad})


func _on_xp_agregada(cantidad: int, _xp_total: int) -> void:
	_encolar({"tipo": "xp", "texto": "+%d XP" % cantidad})


func _encolar(datos: Dictionary) -> void:
	_cola.append(datos)
	# Diferido (no _procesar_cola() directo): un botín con varias filas
	# (ej. tabla_botin de un mob) emite item_agregado varias veces SEGUIDAS
	# dentro del mismo fotograma — si se procesara al toque, la primera fila
	# se mostraría antes de que las demás siquiera se hayan encolado, y
	# _mostrar() la creería "la última" (3s) por error. Diferir a fin de
	# fotograma deja que toda la tanda del mismo golpe entre a _cola ANTES
	# de decidir qué dura 0.5s y qué dura 3s.
	_procesar_cola.call_deferred()


func _procesar_cola() -> void:
	while _activas < max_filas_visibles and not _cola.is_empty():
		_mostrar(_cola.pop_front())


func _mostrar(datos: Dictionary) -> void:
	var noti := _obtener_notificacion()
	_activas += 1
	# _cola ya no tiene a "datos" (se sacó con pop_front() antes de llamar
	# acá) — que esté vacía significa que esta es la última (o la única).
	noti.duracion_visible = DURACION_UNICA if _cola.is_empty() else DURACION_ENCOLADA
	if datos.tipo == "item":
		noti.configurar(datos.item, datos.cantidad)
	else:
		noti.configurar_texto(datos.texto)


## Reutiliza una fila ya creada (pool propio, ver nota de clase); solo
## instancia una nueva la primera vez que hace falta ese cupo — como mucho
## se instancian max_filas_visibles filas en toda la partida.
func _obtener_notificacion() -> NotificacionLoot:
	if _libres.is_empty():
		var noti := escena_notificacion.instantiate() as NotificacionLoot
		add_child(noti)
		noti.terminada.connect(_on_fila_terminada.bind(noti))
		return noti
	var noti: NotificacionLoot = _libres.pop_back()
	move_child(noti, get_child_count() - 1)
	return noti


func _on_fila_terminada(noti: NotificacionLoot) -> void:
	noti.hide()
	_libres.append(noti)
	_activas -= 1
	_procesar_cola()
