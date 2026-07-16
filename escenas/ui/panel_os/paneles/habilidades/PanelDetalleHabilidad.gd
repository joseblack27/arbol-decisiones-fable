extends Panel

@onready var icon              := $MarginContainer/VBoxContainer/HBoxContainer/TextureRect
@onready var name_label        := $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/EtiquetaNombre
@onready var level_label       := $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/EtiquetaNivel
@onready var description_label := $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/MargenDescripcion/VBoxDescripcion/EtiquetaDescripcion
@onready var cost_label        := $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/MargenCosto/HBoxCosto/EtiquetaCosto
@onready var dmg_base_label    := $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/MargenEstadisticas/VBoxEstadisticas/HBoxDanoBase/EtiquetaDanoBase
@onready var dmg_calc_label    := $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/MargenEstadisticas/VBoxEstadisticas/HBoxDanoCalculado/EtiquetaDanoCalculado
@onready var type_launch_label := $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/MargenEstadisticas/VBoxEstadisticas/HBoxTipoLanzamiento/EtiquetaTipoLanzamiento
@onready var type_damage_label := $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/MargenEstadisticas/VBoxEstadisticas/HBoxTipoDano/EtiquetaTipoDano
@onready var range_launch_label = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/MargenEstadisticas/VBoxEstadisticas/HBoxRangoLanzamiento/EtiquetaRangoLanzamiento
@onready var cool_down_label    = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/MargenEstadisticas/VBoxEstadisticas/HBoxEnfriamiento/EtiquetaEnfriamiento
@onready var _equip_btn:   Button        = $MarginContainer/VBoxContainer/HBoxOpciones/MarginContainer/HBoxContainer/BotonEquipar
@onready var _overlay:     ColorRect     = $SuperposicionSlot
@onready var _selector:    SelectorSlot  = $SelectorSlot

var _skill_actual: DatosHabilidad = null


func _ready() -> void:
	_equip_btn.pressed.connect(_abrir_selector)
	_selector.slot_elegido.connect(_on_slot_elegido)
	_selector.cancelado.connect(_cerrar_selector)
	# El daño mostrado depende de los atributos actuales del jugador (bonos
	# de equipo incluidos) — recalcular cada vez que el equipo cambia, para
	# que si el panel está abierto no se quede mostrando un número viejo.
	BusEventos.equipo_cambiado.connect(_on_equipo_cambiado)


func _on_equipo_cambiado(_equipados: Array) -> void:
	if _skill_actual:
		show_skill(_skill_actual)


## Atributos del jugador (bonos de equipo ya aplicados, ver
## AtributosComponente.recalcular_con_equipo) usados para mostrar el daño
## real que la habilidad va a infligir, no solo su rango base.
func _obtener_atributos_jugador() -> AtributosComponente:
	var jugador := Utils.jugador_local()
	if not jugador:
		return null
	return jugador.get_node_or_null("AtributosComponente") as AtributosComponente


# ── Selector ──────────────────────────────────────────────────────────────────

func _abrir_selector() -> void:
	if not _skill_actual or not _skill_actual.escena:
		return
	var slot_habs := Utils.slot_habilidades_local()
	_selector.setup(_skill_actual, slot_habs)
	_overlay.visible  = true
	_selector.visible = true


func _cerrar_selector() -> void:
	_overlay.visible  = false
	_selector.visible = false


func _on_slot_elegido(slot_index: int) -> void:
	var slot_habs := Utils.slot_habilidades_local()
	if slot_habs and _skill_actual:
		slot_habs.equipar(slot_index, _skill_actual)
	_cerrar_selector()


# ── Mostrar datos de la skill ─────────────────────────────────────────────────

func show_skill(skill: DatosHabilidad) -> void:
	if not skill:
		return
	_cerrar_selector()
	_skill_actual = skill

	icon.texture     = skill.icon
	name_label.text  = skill.name
	level_label.text = "Nivel %d" % skill.level

	# "Daño Calculado" = dano_base + los atributos ofensivos ACTUALES del
	# jugador (bonus plano + potencia; el crítico no entra porque es un roll
	# aleatorio, no tiene sentido en un número fijo mostrado en pantalla).
	# Sin AtributosComponente disponible, se muestra el rango base tal cual.
	var atributos := _obtener_atributos_jugador()
	var dmg_calc_min := skill.damage_base_min
	var dmg_calc_max := skill.damage_base_max
	if atributos:
		dmg_calc_min = int(atributos.calcular_dano_saliente_vista_previa(skill.damage_base_min))
		dmg_calc_max = int(atributos.calcular_dano_saliente_vista_previa(skill.damage_base_max))

	# Factor propio de la habilidad (p. ej. el lanzallamas solo aplica una
	# FRACCIÓN de esto por tick, ver HabilidadLanzallamas.multiplicador_
	# dano_tick — "decía 4-8 pero en realidad hace 1", reportado). Genérico
	# a propósito: se lee del script de la escena por nombre de propiedad,
	# así que cualquier habilidad futura con el mismo patrón se refleja acá
	# sola, sin tener que tocar este panel de nuevo. instantiate() sin
	# add_child no dispara _ready() — seguro leer y descartar.
	if skill.escena:
		var tmp := skill.escena.instantiate()
		if "multiplicador_dano_tick" in tmp:
			var factor: float = tmp.get("multiplicador_dano_tick")
			dmg_calc_min = int(dmg_calc_min * factor)
			dmg_calc_max = int(dmg_calc_max * factor)
		tmp.free()

	var dmg_calc := "%d - %d" % [dmg_calc_min, dmg_calc_max]

	description_label.text = skill.description.format({"damage1": dmg_calc})
	cost_label.text = str(skill.cost_energy)

	dmg_base_label.text = "%d - %d" % [skill.damage_base_min, skill.damage_base_max]
	dmg_calc_label.text = dmg_calc

	type_launch_label.text  = Utils.snake_to_pascal(Enums.Skill.TypeLaunch.keys()[skill.type_launch])
	type_damage_label.text  = Utils.snake_to_pascal(Enums.Skill.TypeDamage.keys()[skill.type_damage])
	range_launch_label.text = "%d metros" % skill.range_meters
	cool_down_label.text    = "%.1f segundos" % skill.cooldown_seconds
