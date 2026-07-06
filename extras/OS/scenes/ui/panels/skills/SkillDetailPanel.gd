extends Panel

@onready var icon := $MarginContainer/VBoxContainer/HBoxContainer/TextureRect
@onready var name_label := $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/NameLabel
@onready var level_label := $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/LevelLabel

@onready var description_label := $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/MarginDescription/VBoxDescription/DescriptionLabel
@onready var cost_label := $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/MarginCost/HBoxCost/CostLabel
@onready var dmg_base_label := $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/MarginStats/VBoxStats/HBoxDamageBase/DamageBaseLabel
@onready var dmg_calc_label := $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/MarginStats/VBoxStats/HBoxDamageCalculate/DamageCalculateLabel
@onready var type_launch_label := $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/MarginStats/VBoxStats/HBoxTypeLaunch/TypeLaunchLabel
@onready var range_launch_label = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/MarginStats/VBoxStats/HBoxRangeLaunch/RangeLaunchLabel
@onready var cool_down_label = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/MarginStats/VBoxStats/HBoxCoolDown/CoolDownLabel

func show_skill(skill: SkillData):
	if not skill:
		return

	icon.texture = skill.icon
	name_label.text = skill.name
	level_label.text = "Nivel %d" % skill.level

	var dmg_calc = "%d - %d" % [
		skill.damage_calculated_min,
		skill.damage_calculated_max
	]
	description_label.text = skill.description.format({"damage1": dmg_calc})
	cost_label.text = str(skill.cost_energy)

	dmg_base_label.text = "%d - %d" % [
		skill.damage_base_min,
		skill.damage_base_max
	]

	dmg_calc_label.text = "%d - %d" % [
		skill.damage_calculated_min,
		skill.damage_calculated_max
	]

	type_launch_label.text = Utils.snake_to_pascal(Enums.Skill.TypeLaunch.keys()[skill.type_launch])
	range_launch_label.text = "%d metros" % skill.range_meters
	cool_down_label.text = "%d segundos" % skill.cooldown_seconds
