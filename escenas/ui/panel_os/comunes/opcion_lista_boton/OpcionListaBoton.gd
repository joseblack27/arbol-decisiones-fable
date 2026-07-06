extends ItemListaBoton
class_name OpcionListaBoton

@onready var title_label: Label = $MarginContainer/VBoxContainer/EtiquetaTitulo
@onready var date_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/EtiquetaFecha
@onready var subtitle_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/EtiquetaSubtitulo

func _ready():
	
	labels = [
		$MarginContainer/VBoxContainer/EtiquetaTitulo,
		$MarginContainer/VBoxContainer/HBoxContainer/EtiquetaSubtitulo,
		$MarginContainer/VBoxContainer/HBoxContainer/EtiquetaFecha
	]
	
	super._ready()
