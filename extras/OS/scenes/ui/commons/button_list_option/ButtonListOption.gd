extends ButtonListItem
class_name ButtonListOption

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var date_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/DateLabel
@onready var subtitle_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/SubtitleLabel

func _ready():
	
	labels = [
		$MarginContainer/VBoxContainer/TitleLabel,
		$MarginContainer/VBoxContainer/HBoxContainer/SubtitleLabel,
		$MarginContainer/VBoxContainer/HBoxContainer/DateLabel
	]
	
	super._ready()
