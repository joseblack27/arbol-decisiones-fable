extends Control

@onready var list_panel: EventListPanel = $MarginContainer/HBoxContainer/EventListPanel
@onready var detail_panel: EventDetailPanel = $MarginContainer/HBoxContainer/EventDetailPanel

func _ready():
	list_panel.event_selected.connect(_on_event_selected)

	_create_test_events()
	list_panel.build(EventManager.events)

func _on_event_selected(event: EventData):
	detail_panel.show_event(event)


func _create_test_events():
	var now := Time.get_unix_time_from_system()

	for i in range(30):
		var e := EventData.new()

		if i % 2 == 0:
			e.id = "world_boss - %d" % i
			e.title = "Jefe de Mundo - %d" % i
			e.subtitle = "Coloso Carmesí"
			e.description = "Una criatura ancestral ha despertado."
			e.start_time = now + 5 + (i * 2)
			e.end_time = now + 10 + (i * 2)
			e.is_persistent = true
		else:
			e.id = "dungeon - %d" % i
			e.title = "Mazmorra - %d" % i
			e.subtitle = "Cripta Oscura"
			e.description = "Una mazmorra peligrosa ha sido descubierta."
			e.start_time = now - 5 + (i * 2)
			e.end_time = now + 10 + (i * 2)
			e.is_persistent = false

		EventManager.add_event(e)
