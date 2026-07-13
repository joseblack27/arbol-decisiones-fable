extends Control
## HUD del jugador propio: nombre, barra de vida, barra de energía y barra
## de XP (amarilla, progreso DENTRO del nivel actual — ver TablaNiveles).
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
@onready var _barra_xp: ProgressBar = %BarraXp
@onready var _texto_xp: Label = %TextoXp

var _jugador: Node2D = null
var _vida: VidaComponente = null
var _energia: EnergiaComponente = null
var _acumulador := 0.0


func _ready() -> void:
	visible = false
	BusEventos.xp_agregada.connect(_on_xp)
	# La partida cargada (F9 / autocarga al conectar) puede pisar la XP sin
	# pasar por xp_agregada — refrescar todo al terminar de cargar.
	GestorGuardado.partida_cargada.connect(_refrescar_todo)


func _process(delta: float) -> void:
	# Reintento barato hasta que exista el jugador propio (y re-enganche si
	# la escena se recargó y el nodo viejo quedó liberado).
	if _jugador != null and is_instance_valid(_jugador):
		return
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
	_nombre.text = Utils.nombre_visible(_jugador)
	if _vida:
		_on_vida(_vida.obtener_vida())
	if _energia:
		_on_energia(_energia.obtener_energia(), _energia.obtener_energia_maxima())
	_on_xp(0, 0)


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
	var nivel := GestorExperiencia.nivel
	var progreso := TablaNiveles.progreso_en_nivel(GestorExperiencia.xp_total, nivel)
	if progreso.y > 0:
		_barra_xp.max_value = progreso.y
		_barra_xp.value = progreso.x
		_texto_xp.text = "Nv %d · XP %d/%d" % [nivel, progreso.x, progreso.y]
	else:
		_barra_xp.max_value = 1
		_barra_xp.value = 1
		_texto_xp.text = "Nv %d · XP MAX" % nivel
