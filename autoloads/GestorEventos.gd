extends Node

signal event_updated(event: DatosEvento)
signal event_expired(event: DatosEvento)

var events: Array[DatosEvento] = []
var event_selected: DatosEvento

const EVENTS_MAX: int = 20

@onready var _timer := Timer.new()

func _ready():
	_timer.wait_time = 1.0
	_timer.autostart = true
	_timer.timeout.connect(_on_tick)
	add_child(_timer)

func _on_tick():
	var now := Time.get_unix_time_from_system()
	var expired: bool = false
	for event in events:

		if now < event.start_time:
			event.status = Enums.Event.Status.UPCOMING
		elif now < event.end_time:
			event.status = Enums.Event.Status.ACTIVE
		else:
			event.status = Enums.Event.Status.COMPLETED
			if event.is_persistent == false:
				expired = true
				event_expired.emit(event)
		if expired == false:
			event_updated.emit(event)

func add_event(event: DatosEvento):
	if events.size() >= EVENTS_MAX:
		events.pop_back()
	events.push_front(event)
	event_updated.emit(event)

func delete_event_by_id(id: String):
	for i in range(events.size()):
		if events[i].id == id:
			events.remove_at(i)
			return
