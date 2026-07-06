extends Control

@export var skills: Array[SkillData]

@onready var skill_list_panel := $MarginContainer/HBoxContainer/SkillListPanel/MarginContainer/HBoxContainer/ScrollContainer/MarginContainer/VBoxContainer
@onready var detail_panel := $MarginContainer/HBoxContainer/DetailPanel
@onready var group_button := ButtonGroup.new()

@export var skill_item_scene: PackedScene = preload("res://scenes/ui/panels/skills/SkillItem.tscn")

func _ready():
	populate()

func populate():
	for skill in skill_list_panel.get_children():
		skill.queue_free()

	for skill in skills:
		var item: SkillItem = skill_item_scene.instantiate()
		item.button_group = group_button
		item.skill_data = skill
		item.skill_selected.connect(_on_skill_selected)
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		skill_list_panel.add_child(item)
	
	if skill_list_panel.get_child_count() > 0:
		_on_skill_selected(skill_list_panel.get_child(0).skill_data)

func _on_skill_selected(skill: SkillData):
	detail_panel.show_skill(skill)
