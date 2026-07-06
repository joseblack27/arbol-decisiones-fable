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


# ── Selector ──────────────────────────────────────────────────────────────────

func _abrir_selector() -> void:
	if not _skill_actual or not _skill_actual.escena:
		return
	var slot_habs := get_tree().get_first_node_in_group("slot_habilidades") as SlotHabilidades
	_selector.setup(_skill_actual, slot_habs)
	_overlay.visible  = true
	_selector.visible = true


func _cerrar_selector() -> void:
	_overlay.visible  = false
	_selector.visible = false


func _on_slot_elegido(slot_index: int) -> void:
	var slot_habs := get_tree().get_first_node_in_group("slot_habilidades") as SlotHabilidades
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

	var dmg_calc := "%d - %d" % [skill.damage_calculated_min, skill.damage_calculated_max]
	description_label.text = skill.description.format({"damage1": dmg_calc})
	cost_label.text = str(skill.cost_energy)

	dmg_base_label.text = "%d - %d" % [skill.damage_base_min, skill.damage_base_max]
	dmg_calc_label.text = "%d - %d" % [skill.damage_calculated_min, skill.damage_calculated_max]

	type_launch_label.text  = Utils.snake_to_pascal(Enums.Skill.TypeLaunch.keys()[skill.type_launch])
	type_damage_label.text  = Utils.snake_to_pascal(Enums.Skill.TypeDamage.keys()[skill.type_damage])
	range_launch_label.text = "%d metros" % skill.range_meters
	cool_down_label.text    = "%.1f segundos" % skill.cooldown_seconds
