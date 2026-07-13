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
@onready var _lbl_regen_vida    : Label = get_node(_PRIN + "/FilaRegenVida/ValorRegenVida")
@onready var _lbl_regen_energia : Label = get_node(_PRIN + "/FilaRegenEnergia/ValorRegenEnergia")

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

# ── Actividad reciente (log de daño) ─────────────────────────────────────────
@onready var _registro_actividad: RichTextLabel = get_node(
	"VBoxContainer/MarginContainer/HBoxContainer/PanelActividadReciente/MarginContainer/VBoxContainer/RegistroActividad")
## Tope de líneas del registro para que no crezca sin límite en partidas largas.
const _MAX_LINEAS_REGISTRO := 200
var _lineas_registro: int = 0

# ── Referencias a componentes del jugador ─────────────────────────────────────
var _vida_comp    : VidaComponente    = null
var _energia_comp : EnergiaComponente = null
var _atributos    : AtributosBase     = null
var _datos_jugador: DatosJugador      = null


func _ready() -> void:
	_conectar_jugador()
	visibility_changed.connect(_on_visibilidad_cambiada)
	# Refresco inmediato al equipar/quitar/reemplazar algo, aunque esta
	# pestaña ya esté abierta (si no, solo se enteraría al volver a abrirla).
	BusEventos.equipo_cambiado.connect(_on_equipo_cambiado)
	# Ídem para la XP: GestorExperiencia es quien de verdad la acumula (ver
	# Enemigo._on_muerte) — DatosJugador.experiencia es un campo aparte que
	# nadie más actualiza, por eso el panel nunca la mostraba subir.
	BusEventos.xp_agregada.connect(_on_xp_agregada)
	# Log de daño en "Actividad Reciente": para rastrear el "daño fantasma"
	# (el jugador pierde vida sin ver quién lo golpeó). Se registra TODO
	# daño que reciba un jugador, incluso con el panel cerrado — al abrirlo
	# se ve el historial completo.
	BusEventos.daño_aplicado.connect(_on_dano_registrado)
	# En cliente puro el daño real llega por daño_replicado, que trae el
	# nombre del atacante YA resuelto como texto — incluso si su nodo no
	# existe en este peer ("EnemigoAraña@5 [invisible]" en vez de "???").
	# _on_dano_registrado se salta esos casos para no duplicar la línea.
	BusEventos.daño_replicado.connect(_on_dano_replicado)


# =============================================================================
# Conexión al jugador
# =============================================================================

func _conectar_jugador() -> void:
	# Utils.jugador_local(), NO get_nodes_in_group("jugadores")[0]: con más
	# de un jugador en escena (multijugador real), "el primero" del grupo
	# podía ser el de OTRO jugador — este panel entonces mostraba y
	# cacheaba (_atributos = atrib_comp.base) los atributos de alguien más,
	# así que equipar/desequipar tu propio equipo nunca se reflejaba acá
	# (bug reportado: "al desequipar un equipo no se actualizan los
	# atributos").
	var jugador := Utils.jugador_local()
	if jugador == null:
		return

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


func _on_equipo_cambiado(_equipados: Array[DatosItem]) -> void:
	_actualizar_ofensivas()
	_actualizar_defensivas()


func _on_xp_agregada(_cantidad: int, _xp_total: int) -> void:
	_actualizar_principales()


## Escribe "A hizo X daño a B" en el registro de Actividad Reciente cada vez
## que un JUGADOR recibe daño. A y B son los nombres de nodo de las escenas
## involucradas; si la fuente no se conoce (p. ej. en un cliente puro, donde
## el daño real llega replicado desde el servidor sin atacante — ver
## VidaComponente._recibir_vida_red, que emite fuente=null), se registra
## "???": justo la firma del "daño fantasma" que se busca rastrear.
func _on_dano_registrado(objetivo: Node, cantidad: float, fuente: Node) -> void:
	# En cliente puro esta misma línea llega (mejor) por daño_replicado —
	# con el nombre del atacante aunque su nodo no exista en este peer.
	if Utils.en_red() and not multiplayer.is_server():
		return
	# Utils.nombre_visible: para jugadores usa el nombre replicado (el de
	# nodo es el peer id, un número pelado); para mobs cae al nombre de nodo.
	var nombre_fuente: String = Utils.nombre_visible(fuente) if is_instance_valid(fuente) else "???"
	_registrar_linea(objetivo, cantidad, nombre_fuente)


func _on_dano_replicado(objetivo: Node, cantidad: float, nombre_fuente: String) -> void:
	_registrar_linea(objetivo, cantidad, nombre_fuente)


func _registrar_linea(objetivo: Node, cantidad: float, nombre_fuente: String) -> void:
	if objetivo == null or not is_instance_valid(objetivo) or not objetivo.is_in_group("jugadores"):
		return
	var nombre_objetivo: String = Utils.nombre_visible(objetivo)
	if _lineas_registro >= _MAX_LINEAS_REGISTRO:
		_registro_actividad.remove_paragraph(0)
	else:
		_lineas_registro += 1
	_registro_actividad.append_text(
		"%s hizo %d daño a %s\n" % [nombre_fuente, int(cantidad), nombre_objetivo])


func _actualizar_todo() -> void:
	_actualizar_principales()
	_actualizar_ofensivas()
	_actualizar_defensivas()


func _actualizar_principales() -> void:
	# GestorExperiencia.nivel/xp_total son la única fuente real (ver
	# TablaNiveles) — DatosJugador.nivel/experiencia_max eran campos fijos
	# que nunca cambiaban en juego, ya no se usan para esto.
	_lbl_nivel.text = str(GestorExperiencia.nivel)
	var progreso := TablaNiveles.progreso_en_nivel(GestorExperiencia.xp_total, GestorExperiencia.nivel)
	_lbl_experiencia.text = "%d / %d" % [progreso.x, progreso.y] if progreso.y > 0 \
		else "MAX"
	if _datos_jugador:
		_lbl_nombre.text   = _datos_jugador.nombre
		_lbl_estamina.text = str(int(_datos_jugador.estamina))

	if _vida_comp:
		_lbl_vida.text = "%s / %s" % [int(_vida_comp.salud_actual), int(_vida_comp.salud_maxima)]

	if _energia_comp:
		_lbl_energia.text = "%s / %s" % [int(_energia_comp.obtener_energia()), int(_energia_comp.obtener_energia_maxima())]

	_actualizar_regeneracion()


## Solo el número final por tick — la cantidad ya resuelta la calculan los
## propios componentes (VidaComponente/EnergiaComponente._cantidad_regen,
## que leen el atributo con los bonos de equipo incluidos), así el panel
## nunca puede mostrar un número distinto del que de verdad se aplica.
func _actualizar_regeneracion() -> void:
	if _vida_comp:
		_lbl_regen_vida.text = str(int(_vida_comp._cantidad_regen()))
	if _energia_comp:
		_lbl_regen_energia.text = str(int(_energia_comp._cantidad_regen()))


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
