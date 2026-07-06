extends Panel
class_name EventDetailPanel

@onready var title_label := $MarginContainer/VBoxContainer/TitleLabel
@onready var subtitle_label := $MarginContainer/VBoxContainer/MarginContainer/VBoxContainer/SubtitleLabel
@onready var status_label := $MarginContainer/VBoxContainer/MarginContainer/VBoxContainer/HBoxContainer/StatusLabel
@onready var description_label := $MarginContainer/VBoxContainer/MarginContainer/VBoxContainer/VBoxContainer/DescriptionRich
@onready var detail_panel: MarginContainer = $MarginContainer

func show_event(event: EventData):
	if event == null:
		detail_panel.visible = false
	else:
		detail_panel.visible = true

		title_label.text = event.title
		subtitle_label.text = event.subtitle
		description_label.text = event.description

		match event.status:
			Enums.Event.Status.UPCOMING:
				status_label.text = "Próximamente"
			Enums.Event.Status.ACTIVE:
				status_label.text = "Activo"
			Enums.Event.Status.COMPLETED:
				status_label.text = "Finalizado"
