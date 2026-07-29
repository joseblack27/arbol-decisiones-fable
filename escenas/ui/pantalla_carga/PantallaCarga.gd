extends CanvasLayer
## GestorCarga (autoload, ver project.godot): pantalla de carga con progreso
## REAL — no una animación decorativa de duración fija. Cubre toda la ventana
## desde que se inicia la conexión hasta que el jugador está de verdad listo
## para jugar, y recién ahí se va.
##
## El progreso sale de etapas con PESO: cada etapa aporta su fracción al
## total según cuánto tarda de verdad, medido en el flujo real (ver ETAPAS).
## La etapa más cara con diferencia es cargar el PackedScene del nivel
## (NivelPradera.tscn pesa ~660 KB) — esa es la única con un porcentaje
## genuino, servido por ResourceLoader.load_threaded_get_status() (ver
## GestorNiveles._cargar_escena_con_progreso). Las demás son hitos de red o
## pasos bloqueantes sin API de porcentaje: se marcan al completarse.
##
## layer 200 a propósito: el velo de fundido de GestorNiveles vive en la 100
## y taparía esta pantalla (ver GestorNiveles._ready).

## Etapas en ORDEN, con el peso que aporta cada una al total. Los pesos
## suman 1.0 y están repartidos según el costo real medido: cargar el
## PackedScene del nivel domina el tiempo de espera, así que se lleva la
## mayor parte de la barra — si se repartieran en partes iguales, la barra
## se clavaría en un tramo y saltaría en el resto.
const ETAPAS := [
	{"clave": &"conexion", "texto": "Conectando al servidor",  "peso": 0.10},
	{"clave": &"nivel",    "texto": "Cargando el nivel",       "peso": 0.50},
	{"clave": &"mundo",    "texto": "Construyendo el mundo",   "peso": 0.20},
	{"clave": &"jugador",  "texto": "Creando tu personaje",    "peso": 0.12},
	{"clave": &"partida",  "texto": "Restaurando tu partida",  "peso": 0.08},
]

@onready var _barra: ProgressBar = %Barra
@onready var _etiqueta_etapa: Label = %EtiquetaEtapa
@onready var _etiqueta_porcentaje: Label = %EtiquetaPorcentaje
@onready var _etiqueta_detalle: Label = %EtiquetaDetalle

## Progreso 0..1 ya alcanzado, sin contar la etapa en curso.
var _completado: float = 0.0
## Total mostrado — nunca retrocede (ver _fijar_total): una barra que vuelve
## para atrás se lee como un error aunque el flujo esté bien.
var _total_mostrado: float = 0.0
var _visible := false


func _ready() -> void:
	layer = 200
	# ALWAYS: la carga puede ocurrir con el árbol pausado (cambio de nivel,
	# menús) y la barra igual tiene que seguir animándose.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ocultar_inmediato()


## Arranca (o reinicia) la pantalla desde cero. Idempotente: llamarla dos
## veces seguidas no reinicia una carga ya en curso a la mitad.
func mostrar() -> void:
	if _visible:
		return
	_visible = true
	_completado = 0.0
	_total_mostrado = 0.0
	if _barra:
		_barra.value = 0.0
	if _etiqueta_detalle:
		_etiqueta_detalle.text = ""
	_fijar_etapa_texto(&"conexion")
	visible = true


## Reporta el avance DENTRO de una etapa. fraccion 0..1.
## Marca como completadas todas las etapas anteriores a "clave": el flujo es
## lineal, así que llegar a una etapa implica que las de antes terminaron —
## sin esto, un hito que no llegue a reportarse (p. ej. una partida nueva sin
## guardado previo) dejaría la barra trabada más atrás para siempre.
func avanzar(clave: StringName, fraccion: float = 0.0) -> void:
	if not _visible:
		return
	var acumulado := 0.0
	for etapa in ETAPAS:
		if etapa["clave"] == clave:
			_completado = acumulado
			_fijar_etapa_texto(clave)
			_fijar_total(acumulado + etapa["peso"] * clampf(fraccion, 0.0, 1.0))
			return
		acumulado += etapa["peso"]


## Da una etapa por terminada (equivale a avanzar(clave, 1.0)).
func completar(clave: StringName) -> void:
	avanzar(clave, 1.0)


## Línea secundaria: el dato concreto de lo que está pasando (intento de
## reconexión, tamaño cargado, etc.). "" la deja vacía.
func fijar_detalle(texto: String) -> void:
	if _etiqueta_detalle:
		_etiqueta_detalle.text = texto


## Todo listo: completa la barra y se va. El pequeño retardo deja ver el
## 100% — sin él la barra desaparece en el mismo fotograma en que se llena y
## parece que nunca terminó.
func terminar() -> void:
	if not _visible:
		return
	_fijar_total(1.0)
	_fijar_etapa_texto_libre("Listo")
	fijar_detalle("")
	_visible = false
	var temporizador := get_tree().create_timer(0.35)
	temporizador.timeout.connect(_ocultar_inmediato)


func esta_visible() -> bool:
	return _visible


func _ocultar_inmediato() -> void:
	_visible = false
	visible = false


func _fijar_total(nuevo: float) -> void:
	# Monotónico: ver el comentario de _total_mostrado.
	_total_mostrado = maxf(_total_mostrado, clampf(nuevo, 0.0, 1.0))
	if _barra:
		_barra.value = _total_mostrado * 100.0
	if _etiqueta_porcentaje:
		_etiqueta_porcentaje.text = "%d%%" % int(_total_mostrado * 100.0)


func _fijar_etapa_texto(clave: StringName) -> void:
	for etapa in ETAPAS:
		if etapa["clave"] == clave:
			_fijar_etapa_texto_libre(etapa["texto"])
			return


func _fijar_etapa_texto_libre(texto: String) -> void:
	if _etiqueta_etapa:
		_etiqueta_etapa.text = texto
