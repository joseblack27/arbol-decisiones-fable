extends Control
class_name MissionsPanel

@export var list_mission: Array[MissionData]

@onready var group_button := ButtonGroup.new()
@onready var mission_scene: PackedScene = preload("res://scenes/ui/commons/button_list_option/ButtonListOption.tscn")
@onready var reward_item_view_scene: PackedScene = preload("res://scenes/ui/panels/missions/RewardItemView.tscn")

@onready var btn_missions_active: Button = $MarginContainer/HBox/MissionsListPanel/MarginContainer/MissionsListVBox/FilterTabs/ActiveMissionsButton
@onready var btn_missions_completed: Button = $MarginContainer/HBox/MissionsListPanel/MarginContainer/MissionsListVBox/FilterTabs/CompletedMissionsButton
@onready var btn_missions_pending: Button = $MarginContainer/HBox/MissionsListPanel/MarginContainer/MissionsListVBox/FilterTabs/PendingMissionsButton
@onready var mission_detail_panel = $MarginContainer/HBox/MissionDetailPanel/MarginContainer

@onready var missions_list: VBoxContainer = $MarginContainer/HBox/MissionsListPanel/MarginContainer/MissionsListVBox/HBoxContainer/ScrollContainer/MarginContainer/MissionsList

#region Detalle
@onready var title_label: Label = $MarginContainer/HBox/MissionDetailPanel/MarginContainer/DetailVBox/MissionTitle

@onready var type_value: Label = $MarginContainer/HBox/MissionDetailPanel/MarginContainer/DetailVBox/ScrollContainer/VBoxContainer/GridContainer/TypeValue
@onready var level_value: Label = $MarginContainer/HBox/MissionDetailPanel/MarginContainer/DetailVBox/ScrollContainer/VBoxContainer/GridContainer/LevelValue
@onready var region_value: Label = $MarginContainer/HBox/MissionDetailPanel/MarginContainer/DetailVBox/ScrollContainer/VBoxContainer/GridContainer/RegionValue

@onready var description_label: RichTextLabel = $MarginContainer/HBox/MissionDetailPanel/MarginContainer/DetailVBox/ScrollContainer/VBoxContainer/DescriptionText

@onready var objectives_vbox: VBoxContainer = $MarginContainer/HBox/MissionDetailPanel/MarginContainer/DetailVBox/ScrollContainer/VBoxContainer/ObjectivesList
@onready var rewards_vbox: VBoxContainer = $MarginContainer/HBox/MissionDetailPanel/MarginContainer/DetailVBox/ScrollContainer/VBoxContainer/RewardsList
#endregion Detalle

func _ready():
	btn_missions_active.pressed.connect(set_missions_button.bind(btn_missions_active, Enums.Mission.Status.IN_PROGRESS))
	btn_missions_completed.pressed.connect(set_missions_button.bind(btn_missions_completed, Enums.Mission.Status.COMPLETED))
	btn_missions_pending.pressed.connect(set_missions_button.bind(btn_missions_pending, Enums.Mission.Status.AVAILABLE))
	
	for child in missions_list.get_children():
		child.queue_free()
	
	for data: MissionData in list_mission:
		var mission: ButtonListOption = mission_scene.instantiate()
		mission.button_group = group_button
		mission.resource = data
		mission.button_clicked.connect(_on_button_clicked)
		missions_list.add_child(mission)
		mission.title_label.text = data.title
		mission.subtitle_label.text = data.region
		mission.date_label.text = ""
	set_missions_button(btn_missions_active, Enums.Mission.Status.IN_PROGRESS)

func _on_button_clicked(mission_data: MissionData):
	if mission_data:
		show_mission(mission_data)

func set_missions_button(button: Button, status: Enums.Mission.Status):
	btn_missions_active.button_pressed = false
	btn_missions_active.disabled = false
	btn_missions_completed.button_pressed = false
	btn_missions_completed.disabled = false
	btn_missions_pending.button_pressed = false
	btn_missions_pending.disabled = false
	
	button.button_pressed = true
	button.disabled = true
	
	filter_items(status)


func show_mission(mission: MissionData) -> void:
	if mission == null:
		clear()
		return

	title_label.text = mission.title
	#type_value.text = Enums.Mission._get_type_text(mission.type)
	level_value.text = str(mission.level_required)
	region_value.text = mission.region
	description_label.text = mission.description

	_update_objectives(mission.objectives)
	_update_rewards(mission.rewards)
	
	mission_detail_panel.visible = true

func clear():
	title_label.text = "Selecciona una misión"
	type_value.text = "-"
	level_value.text = "-"
	region_value.text = "-"
	description_label.text = ""

	_clear_container(objectives_vbox)
	_clear_container(rewards_vbox)

func _update_objectives(objectives: Array[MissionObjectiveData]):
	_clear_container(objectives_vbox)

	for obj in objectives:
		var label := Label.new()
		label.text = ("✔ " if obj.is_completed else " • ") + obj.description
		label.modulate = Color(0.6, 1, 0.6) if obj.is_completed else Color.WHITE

		objectives_vbox.add_child(label)

func _update_rewards(rewards: MissionRewardData):
	_clear_container(rewards_vbox)

	if rewards.xp > 0:
		_add_reward_label("XP", rewards.xp)

	if rewards.gold > 0:
		_add_reward_label("Oro", rewards.gold)

	if rewards.items.size() > 0:
		var items_flow := FlowContainer.new()
		items_flow.add_theme_constant_override("h_separation", 8)
		items_flow.add_theme_constant_override("v_separation", 8)

		rewards_vbox.add_child(items_flow)

		for reward in rewards.items:
			if reward.item == null:
				continue

			var view := reward_item_view_scene.instantiate()
			items_flow.add_child(view)
			view.setup(reward.item, reward.amount)

func _add_reward_label(_name: String, _value: int):
	var label := Label.new()
	label.text = "%s: %d" % [_name, _value]
	rewards_vbox.add_child(label)

func _clear_container(container: Control):
	for child in container.get_children():
		child.queue_free()

func filter_items(filter_type: Enums.Mission.Status):
	for mission in missions_list.get_children():
		mission.visible = mission.resource.status == filter_type
