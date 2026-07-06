extends Control
class_name PanelCorreos

@export var lista_mails: Array[DatosCorreo]

@onready var group_button := ButtonGroup.new()
@onready var mail_scene: PackedScene = preload("res://escenas/ui/panel_os/comunes/opcion_lista_boton/OpcionListaBoton.tscn")
@onready var mail_list: VBoxContainer = $Margin/HBox/PanelListaCorreos/MarginContainer/HBoxContainer/ScrollContainer/MarginContainer/ListaCorreos

@onready var mail_view: VBoxContainer = $Margin/HBox/PanelDetallesCorreo/MarginContainer/VistaCorreo
@onready var mail_header: Label = $Margin/HBox/PanelDetallesCorreo/MarginContainer/VistaCorreo/CabeceraCorreo
@onready var from_label: Label = $Margin/HBox/PanelDetallesCorreo/MarginContainer/VistaCorreo/MarginContainer/ScrollMensajes/VBoxMensajes/HBoxContainer/EtiquetaDe
@onready var date_label: Label = $Margin/HBox/PanelDetallesCorreo/MarginContainer/VistaCorreo/MarginContainer/ScrollMensajes/VBoxMensajes/HBoxContainer2/EtiquetaFecha
@onready var message_text: RichTextLabel = $Margin/HBox/PanelDetallesCorreo/MarginContainer/VistaCorreo/MarginContainer/ScrollMensajes/VBoxMensajes/TextoMensaje

func _ready():
	for child in mail_list.get_children():
		child.queue_free()
		
	for data in lista_mails:
		var mail: OpcionListaBoton = mail_scene.instantiate()
		mail.button_group = group_button
		mail.resource = data
		mail.button_clicked.connect(_on_button_clicked)
		mail_list.add_child(mail)
		mail.title_label.text = data.title
		mail.subtitle_label.text = data.from
		mail.date_label.text = data.date

func _on_button_clicked(mail_data: DatosCorreo):
	if mail_data:
		mail_view.visible = true
		mail_header.text = mail_data.title
		from_label.text = mail_data.from
		date_label.text = mail_data.date
		message_text.text = mail_data.message
