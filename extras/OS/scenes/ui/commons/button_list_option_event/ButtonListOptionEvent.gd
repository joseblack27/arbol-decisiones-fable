extends ButtonListItem
class_name ButtonListOptionEvent

@onready var title_label: Label = $MarginContainer/VBoxContainer/HBoxContainer2/TitleLabel
@onready var date_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/DateLabel
@onready var subtitle_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/SubtitleLabel
@onready var texture_rect: TextureRect = $MarginContainer/VBoxContainer/HBoxContainer2/TextureRect

func _ready():
	
	labels = [
		$MarginContainer/VBoxContainer/HBoxContainer2/TitleLabel, 
		$MarginContainer/VBoxContainer/HBoxContainer/SubtitleLabel, 
		$MarginContainer/VBoxContainer/HBoxContainer/DateLabel
	]
	
	super._ready()

func setup(data: EventData):
	resource = data
	refresh()
	EventManager.event_updated.connect(_on_event_updated)

func _on_event_updated(updated_event: EventData):
	if updated_event != resource:
		return
	
	if updated_event == EventManager.event_selected:
		button_clicked.emit(resource)
	
	refresh()

func get_time_text() -> String:
	var now := Time.get_unix_time_from_system()
	
	match resource.status:
		Enums.Event.Status.UPCOMING:
			@warning_ignore("narrowing_conversion")
			return "Comienza en " + _format_time(resource.start_time - now)

		Enums.Event.Status.ACTIVE:
			@warning_ignore("narrowing_conversion")
			return "Termina en " + _format_time(resource.end_time - now)

		Enums.Event.Status.COMPLETED:
			return "Finalizado"

	return ""

func _format_time(seconds: int) -> String:
	seconds = max(seconds, 0)

	@warning_ignore("integer_division")
	var m := seconds / 60
	var s := seconds % 60

	if m > 0:
		return "%dm %ds" % [m, s]
	return "%ds" % s

func refresh():
	title_label.text = resource.title
	subtitle_label.text = resource.subtitle
	date_label.text = get_time_text()

	match resource.status:
		Enums.Event.Status.UPCOMING:
			modulate = Color.WHITE
		Enums.Event.Status.ACTIVE:
			modulate = Color(0.6, 1, 0.6)
		Enums.Event.Status.COMPLETED:
			modulate = Color(0.5, 0.5, 0.5)
