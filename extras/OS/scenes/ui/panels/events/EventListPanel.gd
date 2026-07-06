extends Panel
class_name EventListPanel

@export var event_button_scene: PackedScene

@onready var list_container := $MarginContainer/HBoxContainer/ScrollContainer/MarginContainer/VBoxContainer
@onready var group_button := ButtonGroup.new()

var event_buttons := {}

signal event_selected(event: EventData)

func build(events: Array[EventData]):
	clear()
	EventManager.event_expired.connect(_on_event_expired)

	for event in events:
		var button: ButtonListOptionEvent = event_button_scene.instantiate()
		button.button_group = group_button
		button.button_clicked.connect(_on_event_pressed)
		list_container.add_child(button)
		
		event_buttons[event.id] = button
		
		button.setup(event)

func clear():
	for c in list_container.get_children():
		c.queue_free()

func _on_event_pressed(event: EventData):
	EventManager.event_selected = event
	event_selected.emit(event)

func _on_event_expired(expired_event: EventData):
	EventManager.delete_event_by_id(expired_event.id)

	if event_buttons.has(expired_event.id):
		if EventManager.event_selected == expired_event:
			event_selected.emit(null)
		
		event_buttons[expired_event.id].queue_free()
		event_buttons.erase(expired_event.id)
