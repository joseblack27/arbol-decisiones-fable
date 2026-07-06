extends Control

@onready var list_panel: PanelListaEventos = $MarginContainer/HBoxContainer/PanelListaEventos
@onready var detail_panel: PanelDetalleEvento = $MarginContainer/HBoxContainer/PanelDetalleEvento

func _ready():
	list_panel.event_selected.connect(_on_event_selected)

	_create_test_events()
	list_panel.build(GestorEventos.events)

func _on_event_selected(event: DatosEvento):
	detail_panel.show_event(event)


func _create_test_events():
	var now := Time.get_unix_time_from_system()

	for i in range(30):
		var e := DatosEvento.new()

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

		GestorEventos.add_event(e)
