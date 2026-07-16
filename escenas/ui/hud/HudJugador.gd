extends Control
## HUD del jugador propio: nombre + nivel, barra de vida y barra de energía.
## Reemplaza al viejo panel de debug que colgaba del Jugador (label "Vida:"
## + botones de prueba), y a la vieja BarraEnergia suelta en la zona del
## joystick (ver Mundo.tscn) — ahora la energía vive acá, junto a vida.
##
## Vive en Mundo.tscn (solo clientes — el servidor dedicado usa otra escena)
## y se engancha solo al jugador PROPIO: en red el jugador aparece tarde
## (tras conectar y cargar el nivel), así que se reintenta hasta encontrarlo,
## igual que hace PanelTablero.

@onready var _nombre: Label = %Nombre
@onready var _barra_vida: ProgressBar = %BarraVida
@onready var _texto_vida: Label = %TextoVida
@onready var _barra_energia: ProgressBar = %BarraEnergia
@onready var _texto_energia: Label = %TextoEnergia
@onready var _barra_xp: ProgressBar = %BarraXP
@onready var _texto_xp: Label = %TextoXP

var _jugador: Node2D = null
var _vida: VidaComponente = null
var _energia: EnergiaComponente = null
var _acumulador := 0.0

## Cada cuánto se re-lee "nombre + nivel" mientras ya está conectado — no
## solo la primera vez. nombre_visible se replica por un MultiplayerSynchronizer
## cuya autoridad es el servidor (ver Jugador._enter_tree), y el servidor
## recién lo tiene bien puesto cuando procesa _registrar_identidad_red — si
## el HUD lee ANTES de que esa carrera termine, se queda mostrando el id
## numérico de nodo (fallback de Utils.nombre_visible) PARA SIEMPRE, porque
## antes solo se leía una vez al conectar. Este refresco periódico se
## autocorrige solo apenas el dato real llega, sin depender de acertar el
## timing exacto ("a veces se me cambia el nombre... al id").
const _INTERVALO_REFRESCO_NOMBRE := 1.0
var _acumulador_nombre := 0.0


func _ready() -> void:
	visible = false
	BusEventos.xp_agregada.connect(_on_xp)
	# La partida cargada (F9 / autocarga al conectar) puede pisar la XP sin
	# pasar por xp_agregada — refrescar todo al terminar de cargar.
	GestorGuardado.partida_cargada.connect(_refrescar_todo)


func _process(delta: float) -> void:
	if _jugador != null and is_instance_valid(_jugador):
		_acumulador_nombre += delta
		if _acumulador_nombre >= _INTERVALO_REFRESCO_NOMBRE:
			_acumulador_nombre = 0.0
			_actualizar_nombre()
		return
	# Reintento barato hasta que exista el jugador propio (y re-enganche si
	# la escena se recargó y el nodo viejo quedó liberado).
	_acumulador += delta
	if _acumulador < 0.5:
		return
	_acumulador = 0.0
	_conectar_jugador()


func _conectar_jugador() -> void:
	var jugador := Utils.jugador_local() as Node2D
	if jugador == null:
		return
	_jugador = jugador
	_vida = jugador.get_node_or_null("VidaComponente") as VidaComponente
	if _vida:
		_vida.cambio_valor_vida.connect(_on_vida)
	_energia = jugador.get_node_or_null("EnergiaComponente") as EnergiaComponente
	if _energia:
		_energia.energia_cambiada.connect(_on_energia)
	visible = true
	_refrescar_todo()


func _refrescar_todo() -> void:
	if _jugador == null or not is_instance_valid(_jugador):
		return
	_actualizar_nombre()
	_actualizar_xp()
	if _vida:
		_on_vida(_vida.obtener_vida())
	if _energia:
		_on_energia(_energia.obtener_energia(), _energia.obtener_energia_maxima())


func _actualizar_nombre() -> void:
	if _jugador == null or not is_instance_valid(_jugador):
		return
	_nombre.text = "%s Nv. %d" % [Utils.nombre_visible(_jugador), GestorExperiencia.nivel]


func _on_vida(_valor: float) -> void:
	if _vida == null:
		return
	var actual := _vida.obtener_vida()
	var maxima := _vida.obtener_vida_maxima()
	_barra_vida.max_value = maxima
	_barra_vida.value = actual
	_texto_vida.text = "%d / %d" % [int(actual), int(maxima)]


func _on_energia(nueva: float, maxima: float) -> void:
	_barra_energia.max_value = maxima
	_barra_energia.value = nueva
	_texto_energia.text = "%d / %d" % [int(nueva), int(maxima)]


func _on_xp(_cantidad: int, _xp_total: int) -> void:
	_actualizar_nombre()
	_actualizar_xp()


## Progreso DENTRO del nivel actual (no el acumulado total contra un techo
## fijo): TablaNiveles.progreso_en_nivel da "cuánto llevo / cuánto pide este
## tramo". En el nivel máximo, barra llena y "MAX".
func _actualizar_xp() -> void:
	var progreso := TablaNiveles.progreso_en_nivel(
		GestorExperiencia.xp_total, GestorExperiencia.nivel)
	if progreso == Vector2i.ZERO:
		_barra_xp.max_value = 1
		_barra_xp.value = 1
		_texto_xp.text = "MAX"
		return
	_barra_xp.max_value = progreso.y
	_barra_xp.value = progreso.x
	_texto_xp.text = "%d / %d" % [progreso.x, progreso.y]
