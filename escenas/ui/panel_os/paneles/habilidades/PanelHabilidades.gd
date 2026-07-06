extends Control

@onready var skill_list_panel := $MarginContainer/HBoxContainer/PanelListaHabilidades/MarginContainer/HBoxContainer/ScrollContainer/MarginContainer/VBoxContainer
@onready var detail_panel := $MarginContainer/HBoxContainer/PanelDetalle
@onready var group_button := ButtonGroup.new()

@export var skill_item_scene: PackedScene = preload("res://escenas/ui/panel_os/paneles/habilidades/ItemHabilidad.tscn")

func _ready():
	visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed() -> void:
	if visible:
		populate()

func _get_slot_habilidades() -> SlotHabilidades:
	return get_tree().get_first_node_in_group("slot_habilidades") as SlotHabilidades

func populate():
	for child in skill_list_panel.get_children():
		child.queue_free()

	var slot_habs := _get_slot_habilidades()
	var skills: Array[DatosHabilidad] = slot_habs.catalogo if slot_habs else []

	for skill in skills:
		var item: ItemHabilidad = skill_item_scene.instantiate()
		item.button_group = group_button
		item.skill_data = skill
		item.skill_selected.connect(_on_skill_selected)
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		skill_list_panel.add_child(item)

	if skill_list_panel.get_child_count() > 0:
		_on_skill_selected(skill_list_panel.get_child(0).skill_data)

func _on_skill_selected(skill: DatosHabilidad):
	detail_panel.show_skill(skill)
