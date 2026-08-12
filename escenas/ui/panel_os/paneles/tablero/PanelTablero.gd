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

# ── Buffs/debuffs activos (antes "Actividad Reciente", el log de daño se
# mudó a GestorLogRed/PanelLogRed — ver ese archivo) ─────────────────────────
const _P_BUFFS := "VBoxContainer/MarginContainer/HBoxContainer/PanelBuffsActivos/MarginContainer/VBoxContainer"
const ESCENA_FILA_BUFF := preload("res://escenas/ui/panel_os/paneles/tablero/FilaBuff.tscn")
@onready var _lista_buffs: VBoxContainer = get_node(_P_BUFFS + "/Scroll/ListaBuffs")
## Título + separadores: ocultos cuando no hay ningún buff/debuff activo
## (pedido del usuario: "quítame el título y ese mensaje de ahí cuando no
## haya nada") — antes se mostraba un cartel "Ninguno activo" en su lugar;
## ahora directamente no se muestra nada hasta que aparezca el primero.
#@onready var _encabezado_buffs: Control = get_node(_P_BUFFS + "/Encabezado")
var _buffs_comp: BuffsComponente = null
# Sin tipar como FilaBuff (clase recién creada): referenciarla por tipo
# estático desde otro script recién editado falla al cargar ("Could not
# find type FilaBuff") hasta que el proyecto pasa por el editor una vez —
# mismo artefacto ya visto con otras clases nuevas en este proyecto.
var _filas_buff: Dictionary = {}
var _acumulador_reintento_buffs := 0.0

# ── Referencias a componentes del jugador ─────────────────────────────────────
var _vida_comp    : VidaComponente    = null
var _energia_comp : EnergiaComponente = null
var _atributos    : AtributosBase     = null
var _atrib_comp   : AtributosComponente = null
var _datos_jugador: DatosJugador      = null


func _ready() -> void:
	#_encabezado_buffs.visible = false
	_conectar_jugador()
	visibility_changed.connect(_on_visibilidad_cambiada)
	# Refresco inmediato al equipar/quitar/reemplazar algo, aunque esta
	# pestaña ya esté abierta (si no, solo se enteraría al volver a abrirla).
	BusEventos.equipo_cambiado.connect(_on_equipo_cambiado)
	# Ídem para la XP: GestorExperiencia es quien de verdad la acumula (ver
	# Enemigo._on_muerte) — DatosJugador.experiencia es un campo aparte que
	# nadie más actualiza, por eso el panel nunca la mostraba subir.
	BusEventos.xp_agregada.connect(_on_xp_agregada)


func _process(delta: float) -> void:
	# BuffsComponente se crea recién al vuelo (ver BuffsComponente.gd) cuando
	# el jugador recibe su primer buff/debuff — puede no existir todavía
	# cuando este panel se conecta la primera vez, así que se reintenta cada
	# 0.5s hasta encontrarlo (mismo criterio que BarraBuffs.gd).
	if _buffs_comp == null or not is_instance_valid(_buffs_comp):
		_acumulador_reintento_buffs += delta
		if _acumulador_reintento_buffs >= 0.5:
			_acumulador_reintento_buffs = 0.0
			_conectar_buffs()
		return
	if not visible:
		return
	for id in _filas_buff:
		var buff := _buffs_comp.obtener(id)
		if buff:
			_filas_buff[id].actualizar_tiempo(buff.tiempo_restante)


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
		_atributos  = atrib_comp.base
		_atrib_comp = atrib_comp
		_atrib_comp.bono_dano_cambiado.connect(_on_bono_dano_cambiado)

	if "datos_jugador" in jugador:
		_datos_jugador = jugador.get("datos_jugador") as DatosJugador

	if _vida_comp:
		_vida_comp.cambio_valor_vida.connect(_on_vida_cambiada)
	if _energia_comp:
		_energia_comp.energia_cambiada.connect(_on_energia_cambiada)

	_actualizar_todo()
	_conectar_buffs()


## Buscado aparte de _conectar_jugador() (no en esa misma función): a
## diferencia de VidaComponente/EnergiaComponente/AtributosComponente (ya
## están en Jugador.tscn de fábrica), BuffsComponente se crea RECIÉN cuando
## el jugador recibe su primer buff — puede no existir todavía la primera
## vez que este panel se conecta, así que _process() reintenta llamando
## esto de nuevo hasta encontrarlo.
func _conectar_buffs() -> void:
	if _buffs_comp != null and is_instance_valid(_buffs_comp):
		return
	var jugador := Utils.jugador_local()
	if jugador == null:
		return
	_buffs_comp = jugador.get_node_or_null("BuffsComponente") as BuffsComponente
	if _buffs_comp == null:
		return
	_buffs_comp.buff_agregado.connect(_on_buff_agregado)
	_buffs_comp.buff_quitado.connect(_on_buff_quitado)
	# Por si ya había buffs activos ANTES de que este panel se conectara
	# (p. ej. se abre la pestaña a mitad de partida, con un buff ya andando).
	for id in _buffs_comp.activos():
		_on_buff_agregado(id)


func _on_buff_agregado(id: String) -> void:
	if _filas_buff.has(id):
		return
	var buff := _buffs_comp.obtener(id)
	if buff == null:
		return
	var fila = ESCENA_FILA_BUFF.instantiate()
	_lista_buffs.add_child(fila)
	fila.configurar(buff.icono, buff.nombre, buff.descripcion, buff.es_debuff)
	fila.actualizar_tiempo(buff.tiempo_restante)
	_filas_buff[id] = fila
	#_encabezado_buffs.visible = true


func _on_buff_quitado(id: String) -> void:
	if not _filas_buff.has(id):
		return
	_filas_buff[id].queue_free()
	_filas_buff.erase(id)
	#_encabezado_buffs.visible = not _filas_buff.is_empty()


# =============================================================================
# Actualización de datos
# =============================================================================

func _on_visibilidad_cambiada() -> void:
	if visible:
		if _vida_comp == null:
			_conectar_jugador()
		_actualizar_todo()


## Único disparador de refresco de Daño fuera de equipo_cambiado: un bono
## temporal (Grito de Guerra) puede aparecer O vencer sin que el jugador
## haga nada, así que necesita su PROPIO evento (ver AtributosComponente.
## bono_dano_cambiado) en vez de esperar a equipo_cambiado/xp_agregada.
func _on_bono_dano_cambiado(_nuevo_total: float) -> void:
	_actualizar_ofensivas()

func _on_vida_cambiada(_valor: float) -> void:
	_actualizar_principales()

func _on_energia_cambiada(_nueva: float, _maxima: float) -> void:
	_actualizar_principales()


func _on_equipo_cambiado(_equipados: Array[DatosItem]) -> void:
	_actualizar_ofensivas()
	_actualizar_defensivas()


func _on_xp_agregada(_cantidad: int, _xp_total: int) -> void:
	_actualizar_principales()


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
	# Suma los bonos temporales (buffs como Grito de Guerra o Sacrificio) a
	# cada estadística de base — el jugador ve el número YA efectivo
	# mientras duren, sin tener que sumarlos a mano en pleno combate
	# (pedido del usuario, antes solo cubría Daño).
	var bono_danos: float                = _atrib_comp.obtener_bono_dano_temporal() if _atrib_comp else 0.0
	var bono_potencia: float             = _atrib_comp.obtener_bono_potencia_temporal() if _atrib_comp else 0.0
	var bono_prob_critico: float         = _atrib_comp.obtener_bono_probabilidad_critico_temporal() if _atrib_comp else 0.0
	var bono_dano_critico: float         = _atrib_comp.obtener_bono_dano_critico_temporal() if _atrib_comp else 0.0
	_lbl_danos.text        = str(_atributos.danos + bono_danos)
	_lbl_potencia.text     = "%.1f%%" % (_atributos.potencia + bono_potencia)
	_lbl_impacto.text      = str(_atributos.impacto)
	_lbl_afliccion.text    = str(_atributos.afliccion)
	_lbl_impulso.text      = str(_atributos.impulso)
	_lbl_prob_critico.text = "%.1f%%" % (_atributos.probabilidad_critico + bono_prob_critico)
	_lbl_dano_critico.text = "%.1f%%" % (_atributos.dano_critico + bono_dano_critico)


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
