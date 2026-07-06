extends Control
class_name MailsPanel

@export var list_mails: Array[MailData]

@onready var group_button := ButtonGroup.new()
@onready var mail_scene: PackedScene = preload("res://scenes/ui/commons/button_list_option/ButtonListOption.tscn")
@onready var mail_list: VBoxContainer = $Margin/HBox/MailListPanel/MarginContainer/HBoxContainer/ScrollContainer/MarginContainer/MailList

@onready var mail_view: VBoxContainer = $Margin/HBox/MailDetailsPanel/MarginContainer/MailView
@onready var mail_header: Label = $Margin/HBox/MailDetailsPanel/MarginContainer/MailView/MailHeader
@onready var from_label: Label = $Margin/HBox/MailDetailsPanel/MarginContainer/MailView/MarginContainer/MessagesScroll/MessagesVBox/HBoxContainer/FromLabel
@onready var date_label: Label = $Margin/HBox/MailDetailsPanel/MarginContainer/MailView/MarginContainer/MessagesScroll/MessagesVBox/HBoxContainer2/DateLabel
@onready var message_text: RichTextLabel = $Margin/HBox/MailDetailsPanel/MarginContainer/MailView/MarginContainer/MessagesScroll/MessagesVBox/MessageText

func _ready():
	for child in mail_list.get_children():
		child.queue_free()
		
	for data in list_mails:
		var mail: ButtonListOption = mail_scene.instantiate()
		mail.button_group = group_button
		mail.resource = data
		mail.button_clicked.connect(_on_button_clicked)
		mail_list.add_child(mail)
		mail.title_label.text = data.title
		mail.subtitle_label.text = data.from
		mail.date_label.text = data.date

func _on_button_clicked(mail_data: MailData):
	if mail_data:
		mail_view.visible = true
		mail_header.text = mail_data.title
		from_label.text = mail_data.from
		date_label.text = mail_data.date
		message_text.text = mail_data.message
