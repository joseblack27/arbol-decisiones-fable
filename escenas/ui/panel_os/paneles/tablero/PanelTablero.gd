extends Control
class_name PanelTablero

# =============================================================================
# Rutas base para no repetir el path completo en cada @onready
# =============================================================================
const _P_ESTADO  := "VBoxContainer/MarginContainer/HBoxContainer/PanelEstado/MarginContainer/ScrollContainer/VBoxContainer"
const _P_PANEL   := "VBoxContainer/MarginContainer/HBoxContainer/Panel/MarginContainer/ScrollContainer/VBoxContainer"

const _PRIN   := _P_ESTADO + "/Container/VBoxContainer/MarginContainer/VBoxContainer"
const _OFENS  := _P_ESTADO + "/Container2/VBoxContainer/MarginContainer/VBoxContainer"
const _DEFENS := _P_PANEL  + "/Container/VBoxContainer/MarginContainer/VBoxContainer"

# ── Características Principales ───────────────────────────────────────────────
@onready var _lbl_nombre     : Label = get_node(_PRIN + "/HBoxContainer/EtiquetaNombre")
@onready var _lbl_nivel      : Label = get_node(_PRIN + "/HBoxContainer3/EtiquetaNivel")
@onready var _lbl_vida       : Label = get_node(_PRIN + "/HBoxContainer4/LifeLabel")
@onready var _lbl_energia    : Label = get_node(_PRIN + "/HBoxContainer2/EnergyLabel")
@onready var _lbl_estamina   : Label = get_node(_PRIN + "/HBoxContainer5/LifeLabel")
@onready var _lbl_experiencia: Label = get_node(_PRIN + "/HBoxContainer6/LifeLabel")

# ── Características Ofensivas ─────────────────────────────────────────────────
@onready var _lbl_danos        : Label = get_node(_OFENS + "/HBoxContainer/EtiquetaNombre")
@onready var _lbl_potencia     : Label = get_node(_OFENS + "/HBoxContainer2/EnergyLabel")
@onready var _lbl_impacto      : Label = get_node(_OFENS + "/HBoxContainer3/EnergyLabel")
@onready var _lbl_afliccion    : Label = get_node(_OFENS + "/HBoxContainer4/EnergyLabel")
@onready var _lbl_impulso      : Label = get_node(_OFENS + "/HBoxContainer5/EnergyLabel")
@onready var _lbl_prob_critico : Label = get_node(_OFENS + "/HBoxContainer6/EnergyLabel")
@onready var _lbl_dano_critico : Label = get_node(_OFENS + "/HBoxContainer7/EnergyLabel")

# ── Características Defensivas ────────────────────────────────────────────────
@onready var _lbl_defensa    : Label = get_node(_DEFENS + "/HBoxContainer5/EtiquetaNivel")
@onready var _lbl_tenacidad  : Label = get_node(_DEFENS + "/HBoxContainer7/EtiquetaNivel")
@onready var _lbl_fortaleza  : Label = get_node(_DEFENS + "/HBoxContainer6/EtiquetaNivel")
@onready var _lbl_res_fisica : Label = get_node(_DEFENS + "/HBoxContainerResFisica/ResFisicaLabel")
@onready var _lbl_res_aire   : Label = get_node(_DEFENS + "/HBoxContainer/ResWindLabel")
@onready var _lbl_res_agua   : Label = get_node(_DEFENS + "/HBoxContainer2/ResWaterLabel")
@onready var _lbl_res_fuego  : Label = get_node(_DEFENS + "/HBoxContainer3/ResFireLabel")
@onready var _lbl_res_tierra : Label = get_node(_DEFENS + "/HBoxContainer4/ResEarthLabel")

# ── Referencias a componentes del jugador ─────────────────────────────────────
var _vida_comp    : VidaComponente    = null
var _energia_comp : EnergiaComponente = null
var _atributos    : AtributosBase     = null
var _datos_jugador: DatosJugador      = null


func _ready() -> void:
	_conectar_jugador()
	visibility_changed.connect(_on_visibilidad_cambiada)


# =============================================================================
# Conexión al jugador
# =============================================================================

func _conectar_jugador() -> void:
	var jugadores := get_tree().get_nodes_in_group("jugadores")
	if jugadores.is_empty():
		return
	var jugador: Node = jugadores[0]

	_vida_comp    = jugador.get_node_or_null("VidaComponente") as VidaComponente
	_energia_comp = jugador.get_node_or_null("EnergiaComponente") as EnergiaComponente

	var atrib_comp := jugador.get_node_or_null("AtributosComponente") as AtributosComponente
	if atrib_comp:
		_atributos = atrib_comp.base

	if "datos_jugador" in jugador:
		_datos_jugador = jugador.get("datos_jugador") as DatosJugador

	if _vida_comp:
		_vida_comp.cambio_valor_vida.connect(_on_vida_cambiada)
	if _energia_comp:
		_energia_comp.energia_cambiada.connect(_on_energia_cambiada)

	_actualizar_todo()


# =============================================================================
# Actualización de datos
# =============================================================================

func _on_visibilidad_cambiada() -> void:
	if visible:
		if _vida_comp == null:
			_conectar_jugador()
		_actualizar_todo()

func _on_vida_cambiada(_valor: float) -> void:
	_actualizar_principales()

func _on_energia_cambiada(_nueva: float, _maxima: float) -> void:
	_actualizar_principales()


func _actualizar_todo() -> void:
	_actualizar_principales()
	_actualizar_ofensivas()
	_actualizar_defensivas()


func _actualizar_principales() -> void:
	if _datos_jugador:
		_lbl_nombre.text      = _datos_jugador.nombre
		_lbl_nivel.text       = str(_datos_jugador.nivel)
		_lbl_estamina.text    = str(int(_datos_jugador.estamina))
		_lbl_experiencia.text = "%s / %s" % [int(_datos_jugador.experiencia), int(_datos_jugador.experiencia_max)]

	if _vida_comp:
		_lbl_vida.text = "%s / %s" % [int(_vida_comp.salud_actual), int(_vida_comp.salud_maxima)]

	if _energia_comp:
		_lbl_energia.text = "%s / %s" % [int(_energia_comp.obtener_energia()), int(_energia_comp.obtener_energia_maxima())]


func _actualizar_ofensivas() -> void:
	if not _atributos:
		return
	_lbl_danos.text        = str(_atributos.danos)
	_lbl_potencia.text     = "%.1f%%" % _atributos.potencia
	_lbl_impacto.text      = str(_atributos.impacto)
	_lbl_afliccion.text    = str(_atributos.afliccion)
	_lbl_impulso.text      = str(_atributos.impulso)
	_lbl_prob_critico.text = "%.1f%%" % _atributos.probabilidad_critico
	_lbl_dano_critico.text = "%.1f%%" % _atributos.dano_critico


func _actualizar_defensivas() -> void:
	if not _atributos:
		return
	_lbl_defensa.text    = str(_atributos.defensa)
	_lbl_tenacidad.text  = str(_atributos.tenacidad)
	_lbl_fortaleza.text  = "%.1f%%" % _atributos.fortaleza
	_lbl_res_fisica.text = "%.1f%%" % _atributos.resistencia_fisica
	_lbl_res_aire.text   = "%.1f%%" % _atributos.resistencia_aire
	_lbl_res_agua.text   = "%.1f%%" % _atributos.resistencia_agua
	_lbl_res_fuego.text  = "%.1f%%" % _atributos.resistencia_fuego
	_lbl_res_tierra.text = "%.1f%%" % _atributos.resistencia_tierra
