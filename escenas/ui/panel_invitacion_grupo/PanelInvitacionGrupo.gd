extends Control
## Popup de invitación de grupo — Feature C del plan MMO. Oculto por
## defecto, aparece al recibir GestorGrupos.invitacion_recibida y se cierra
## solo (sin avisar nada especial) si nadie responde antes de que el
## servidor la deje vencer (GestorGrupos.TTL_INVITACION_SEGUNDOS).

@onready var _texto: Label = $Fondo/MarginContainer/VBox/Texto
@onready var _boton_aceptar: Button = $Fondo/MarginContainer/VBox/Botones/BotonAceptar
@onready var _boton_rechazar: Button = $Fondo/MarginContainer/VBox/Botones/BotonRechazar


func _ready() -> void:
	hide()
	GestorGrupos.invitacion_recibida.connect(_mostrar)
	_boton_aceptar.pressed.connect(_aceptar)
	_boton_rechazar.pressed.connect(_rechazar)


func _mostrar(nombre_invitante: String) -> void:
	_texto.text = "%s te invitó a su grupo." % nombre_invitante
	show()


func _aceptar() -> void:
	GestorGrupos.aceptar_invitacion()
	hide()


func _rechazar() -> void:
	GestorGrupos.rechazar_invitacion()
	hide()
