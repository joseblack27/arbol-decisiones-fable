extends Control
class_name DashboardPanel

@onready var title_label := $VBoxContainer/TitleLabel
@onready var status_panel := $VBoxContainer/MarginContainer/HBoxContainer/StatusPanel/MarginContainer
#@onready var stats_grid := $VBoxContainer/MarginContainer/HBoxContainer/Panel/MarginContainer/StatsGrid
@onready var recent_activity := $VBoxContainer/MarginContainer/HBoxContainer/RecentActivityPanel/MarginContainer

func _ready() -> void:
	setup_status_panel()
	setup_stats_grid()
	setup_recent_activity()


func setup_status_panel() -> void:
	pass
	#var status_label := Label.new()
	#status_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	#status_label.text = "Estado: Idle"
	#status_panel.add_child(status_label)


func setup_stats_grid() -> void:
	pass
	#stats_grid.columns = 2
	#for stat_name in ["Vida", "Energía", "Velocidad", "Conciencia"]:
		#var label = Label.new()
		#label.size_flags_horizontal = Control.SIZE_EXPAND
		#label.text = stat_name + ":"
		#stats_grid.add_child(label)
#
		#var value = Label.new()
		#value.size_flags_horizontal = Control.SIZE_EXPAND
		#value.text = "0"
		#stats_grid.add_child(value)


func setup_recent_activity() -> void:
	var label := Label.new()
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	label.text = "No hay eventos recientes."
	recent_activity.add_child(label)
