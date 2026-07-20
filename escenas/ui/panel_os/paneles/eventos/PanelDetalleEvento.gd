extends Panel
class_name PanelDetalleEvento

@onready var title_label := $MarginContainer/VBoxContainer/EtiquetaTitulo
@onready var subtitle_label := $MarginContainer/VBoxContainer/MarginContainer/VBoxContainer/EtiquetaSubtitulo
@onready var status_label := $MarginContainer/VBoxContainer/MarginContainer/VBoxContainer/HBoxContainer/EtiquetaEstado
@onready var description_label := $MarginContainer/VBoxContainer/MarginContainer/VBoxContainer/VBoxContainer/TextoDescripcionEnriquecido
@onready var detail_panel: MarginContainer = $MarginContainer

func show_event(event: DatosEvento):
	if event == null:
		detail_panel.visible = false
	else:
		detail_panel.visible = true

		title_label.text = event.title
		subtitle_label.text = event.subtitle
		description_label.text = event.description

		match event.status:
			Enums.Eventoo.Estado.PROXIMO:
				status_label.text = "Próximamente"
			Enums.Eventoo.Estado.ACTIVO:
				status_label.text = "Activo"
			Enums.Eventoo.Estado.COMPLETADO:
				status_label.text = "Finalizado"
