extends Node
class_name EventFactory

static func create_world_boss(
	boss_name: String,
	start_in_seconds: int,
	duration_seconds: int
) -> EventData:
	var now := Time.get_unix_time_from_system()

	var event := EventData.new()
	event.id = "world_boss_" + boss_name.to_lower()
	event.title = "Jefe de Mundo"
	event.subtitle = boss_name
	event.description = "Un poderoso jefe ha aparecido en el mundo."

	event.start_time = now + start_in_seconds
	event.end_time = event.start_time + duration_seconds
	event.status = Enums.Event.Status.UPCOMING

	event.priority = 10

	return event
